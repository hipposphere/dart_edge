import 'dart:convert';

import '../../core/postgres_type_mapping.dart';
import '../../core/sql_dialect.dart';
import '../../core/sql_statement.dart';
import '../../core/sql_value.dart';

SqlStatement compileSqlStatement(SqlDialect dialect, SqlStatement statement) {
  final namedParameters = statement.namedParameters;
  if (namedParameters == null) {
    if (statement.parameters == null) {
      return statement;
    }
    return SqlStatement.positional(statement.sql, [
      for (final value in statement.positionalParameters)
        _unwrapSqlParameterValue(value),
    ]);
  }

  final positionalParameters = <Object?>[];
  final buffer = StringBuffer();

  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;

  for (var index = 0; index < statement.sql.length; index += 1) {
    final char = statement.sql[index];
    final next = index + 1 < statement.sql.length
        ? statement.sql[index + 1]
        : '';

    if (inLineComment) {
      buffer.write(char);
      if (char == '\n') {
        inLineComment = false;
      }
      continue;
    }

    if (inBlockComment) {
      buffer.write(char);
      if (char == '*' && next == '/') {
        buffer.write(next);
        index += 1;
        inBlockComment = false;
      }
      continue;
    }

    if (!inDoubleQuote && char == "'" && next == "'") {
      buffer
        ..write(char)
        ..write(next);
      index += 1;
      continue;
    }

    if (!inSingleQuote && char == '"' && next == '"') {
      buffer
        ..write(char)
        ..write(next);
      index += 1;
      continue;
    }

    if (!inDoubleQuote && char == "'") {
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }

    if (!inSingleQuote && char == '"') {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }

    if (inSingleQuote || inDoubleQuote) {
      buffer.write(char);
      continue;
    }

    if (char == '-' && next == '-') {
      inLineComment = true;
      buffer
        ..write(char)
        ..write(next);
      index += 1;
      continue;
    }

    if (char == '/' && next == '*') {
      inBlockComment = true;
      buffer
        ..write(char)
        ..write(next);
      index += 1;
      continue;
    }

    final placeholder = _parseNamedParameter(
      source: statement.sql,
      index: index,
    );
    if (placeholder == null) {
      buffer.write(char);
      continue;
    }

    final value = _unwrapSqlParameterValue(namedParameters[placeholder.name]);
    if (!namedParameters.containsKey(placeholder.name)) {
      throw ArgumentError.value(
        placeholder.name,
        'statement.parameters',
        'Missing named SQL parameter.',
      );
    }

    positionalParameters.add(switch (dialect) {
      SqlDialect.postgres
          when _hasJsonCast(statement.sql, placeholder.endIndex + 1) =>
        _encodeJsonTextParameter(value),
      _ => value,
    });
    buffer.write(switch (dialect) {
      SqlDialect.postgres => '\$${positionalParameters.length}',
      SqlDialect.sqlite => '?',
    });
    index = placeholder.endIndex;
  }

  return SqlStatement.positional(buffer.toString(), positionalParameters);
}

({String name, int endIndex})? _parseNamedParameter({
  required String source,
  required int index,
}) {
  final marker = source[index];
  if (marker != ':' && marker != '@' && marker != r'$') {
    return null;
  }
  if (marker == ':' &&
      ((index + 1 < source.length && source[index + 1] == ':') ||
          (index > 0 && source[index - 1] == ':'))) {
    return null;
  }
  if (marker == r'$' &&
      index + 1 < source.length &&
      _isDigit(source[index + 1])) {
    return null;
  }

  final start = index + 1;
  if (start >= source.length || !_isIdentifierStart(source[start])) {
    return null;
  }

  var end = start;
  while (end + 1 < source.length && _isIdentifierPart(source[end + 1])) {
    end += 1;
  }

  return (name: source.substring(start, end + 1), endIndex: end);
}

bool _isIdentifierStart(String value) {
  return value == '_' || _isAlpha(value);
}

bool _isIdentifierPart(String value) {
  return _isIdentifierStart(value) || _isDigit(value);
}

bool _isAlpha(String value) {
  final codeUnit = value.codeUnitAt(0);
  return (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122);
}

bool _isDigit(String value) {
  final codeUnit = value.codeUnitAt(0);
  return codeUnit >= 48 && codeUnit <= 57;
}

Object? _encodeJsonTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    _ => jsonEncode(_normalizeJsonValue(value)),
  };
}

Object? _unwrapSqlParameterValue(Object? value) {
  return switch (value) {
    final SqlValue<dynamic> value when value.isPresent => value.value,
    final SqlValue<dynamic> value => throw ArgumentError.value(
      value,
      'value',
      'Absent SQL values cannot be used as query parameters.',
    ),
    _ => value,
  };
}

Object? _normalizeJsonValue(Object? value) {
  return switch (value) {
    null || String() || bool() || num() => value,
    final Map<Object?, Object?> value => <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _normalizeJsonValue(entry.value),
    },
    final Iterable<Object?> value => [
      for (final item in value) _normalizeJsonValue(item),
    ],
    final Object value => throw ArgumentError.value(
      value,
      'value',
      'Unsupported JSON parameter value.',
    ),
  };
}

bool _hasJsonCast(String sql, int index) {
  if (!_startsWith(sql, index, '::')) {
    return false;
  }
  var typeStart = index + 2;
  while (_peek(sql, typeStart) == ' ') {
    typeStart += 1;
  }
  final typeEnd = _readCastTypeEnd(sql, typeStart);
  if (typeEnd == typeStart) {
    return false;
  }
  final type = sql.substring(typeStart, typeEnd).replaceAll('"', '');
  return switch (PostgresTypeMapping.normalizeTypeName(type)) {
    'json' || 'jsonb' => true,
    _ => false,
  };
}

int _readCastTypeEnd(String sql, int start) {
  var index = start;
  while (index < sql.length) {
    final char = sql[index];
    if (_isIdentifierPart(char) || char == '.' || char == '"') {
      index += 1;
      continue;
    }
    break;
  }
  return index;
}

bool _startsWith(String value, int index, String pattern) {
  return index + pattern.length <= value.length &&
      value.substring(index, index + pattern.length) == pattern;
}

String? _peek(String value, int index) {
  if (index < 0 || index >= value.length) {
    return null;
  }
  return value[index];
}
