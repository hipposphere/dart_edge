import '../../core/sql_dialect.dart';
import '../../core/sql_statement.dart';

SqlStatement compileSqlStatement(SqlDialect dialect, SqlStatement statement) {
  final namedParameters = statement.namedParameters;
  if (namedParameters == null) {
    return statement;
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

    final value = namedParameters[placeholder.name];
    if (!namedParameters.containsKey(placeholder.name)) {
      throw ArgumentError.value(
        placeholder.name,
        'statement.parameters',
        'Missing named SQL parameter.',
      );
    }

    positionalParameters.add(value);
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
  if (marker == ':' && index + 1 < source.length && source[index + 1] == ':') {
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
