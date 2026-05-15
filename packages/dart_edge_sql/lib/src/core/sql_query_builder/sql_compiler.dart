part of '../sql_query_builder.dart';

final class _SqlCompiler {
  _SqlCompiler(this.dialect);

  final SqlDialect dialect;
  final StringBuffer _buffer = StringBuffer();
  final Map<String, Object?> _parameters = <String, Object?>{};
  var _parameterIndex = 0;

  void write(String value) => _buffer.write(value);

  void writeIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    _buffer.write('"$escaped"');
  }

  void writeTable(SqlTable<dynamic, dynamic, dynamic> table) {
    if (table case final SqlRawTable rawTable) {
      write(rawTable.tableExpression);
      if (rawTable.alias case final alias?) {
        write(' AS ');
        writeIdentifier(alias);
      }
      return;
    }
    if (table.schema case final String schemaName) {
      writeIdentifier(schemaName);
      write('.');
    }
    writeIdentifier(table.name);
  }

  void writeColumn(SqlColumn<dynamic> column) {
    if (column.table case final SqlRawTable rawTable) {
      writeIdentifier(rawTable.alias ?? rawTable.tableExpression);
    } else {
      writeTable(column.table);
    }
    write('.');
    writeIdentifier(column.name);
  }

  void writeValue(Object? value, {SqlColumn<dynamic>? column}) {
    final parameterName = 'p${++_parameterIndex}';
    _parameters[parameterName] = switch (dialect) {
      SqlDialect.postgres => _encodePostgresParameterValue(value, column),
      SqlDialect.sqlite => value,
    };
    final placeholderPrefix = switch (dialect) {
      SqlDialect.sqlite => ':',
      SqlDialect.postgres => '@',
    };
    _buffer.write('$placeholderPrefix$parameterName');
    if (dialect == SqlDialect.postgres) {
      if (PostgresTypeMapping.parameterCastFor(column?.databaseType)
          case final cast?) {
        _buffer.write('::$cast');
      }
    }
  }

  void writePredicate(SqlPredicate predicate) {
    switch (predicate) {
      case _SqlRawPredicate():
        writeRaw(predicate.sql, predicate.parameters);
      case _SqlComparisonPredicate():
        writeColumn(predicate.left.asObjectColumn);
        write(' ${predicate.operator} ');
        switch (predicate.right) {
          case final SqlColumn<dynamic> column:
            writeColumn(column);
          default:
            writeValue(predicate.right, column: predicate.left.asObjectColumn);
        }
      case _SqlNullPredicate():
        writeColumn(predicate.column.asObjectColumn);
        write(predicate.isNull ? ' IS NULL' : ' IS NOT NULL');
      case _SqlInPredicate():
        if (predicate.values.isEmpty) {
          write('1 = 0');
          return;
        }
        writeColumn(predicate.column.asObjectColumn);
        write(' IN (');
        writeJoined(
          predicate.values,
          separator: ', ',
          writeElement: (value) {
            writeValue(value, column: predicate.column.asObjectColumn);
          },
        );
        write(')');
      case _SqlCompoundPredicate():
        write('(');
        writeJoined(
          predicate.predicates,
          separator: ' ${predicate.operator} ',
          writeElement: writePredicate,
        );
        write(')');
    }
  }

  void writeProjection(_SelectedProjection projection) {
    if (projection.column case final column?) {
      writeColumn(column);
    } else if (projection.expression case final expression?) {
      writeRaw(expression.sql, expression.parameters);
    } else if (projection.rawSql case final rawSql?) {
      write(rawSql);
    }
    if (projection.alias case final alias?) {
      write(' AS ');
      writeIdentifier(alias);
    }
  }

  void writeSelectable(Object value) {
    switch (value) {
      case final SqlColumn<dynamic> column:
        writeColumn(column);
      case final SqlRawExpression<dynamic> expression:
        writeRaw(expression.sql, expression.parameters);
      case final String rawSql:
        write(rawSql);
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Expected String, SqlColumn, or SqlRawExpression.',
        );
    }
  }

  void writeRaw(String sql, Map<String, Object?> parameters) {
    if (parameters.isEmpty) {
      write(sql);
      return;
    }
    var index = 0;
    while (index < sql.length) {
      final char = sql[index];
      if (char == "'") {
        index = _writeQuoted(sql, index, "'");
      } else if (char == '"') {
        index = _writeQuoted(sql, index, '"');
      } else if (_startsWith(sql, index, '--')) {
        index = _writeLineComment(sql, index);
      } else if (_startsWith(sql, index, '/*')) {
        index = _writeBlockComment(sql, index);
      } else if (char == '@' && _isIdentifierStart(_peek(sql, index + 1))) {
        index = _writeRawPlaceholder(sql, index, parameters);
      } else {
        write(char);
        index += 1;
      }
    }
  }

  int _writeQuoted(String sql, int start, String quote) {
    write(quote);
    var index = start + 1;
    while (index < sql.length) {
      final char = sql[index];
      write(char);
      index += 1;
      if (char == quote) {
        if (_peek(sql, index) == quote) {
          write(quote);
          index += 1;
          continue;
        }
        break;
      }
    }
    return index;
  }

  int _writeLineComment(String sql, int start) {
    var index = start;
    while (index < sql.length) {
      final char = sql[index];
      write(char);
      index += 1;
      if (char == '\n') {
        break;
      }
    }
    return index;
  }

  int _writeBlockComment(String sql, int start) {
    var index = start;
    while (index < sql.length) {
      final char = sql[index];
      write(char);
      index += 1;
      if (char == '*' && _peek(sql, index) == '/') {
        write('/');
        index += 1;
        break;
      }
    }
    return index;
  }

  int _writeRawPlaceholder(
    String sql,
    int start,
    Map<String, Object?> parameters,
  ) {
    var end = start + 2;
    while (_isIdentifierPart(_peek(sql, end))) {
      end += 1;
    }
    final name = sql.substring(start + 1, end);
    if (!parameters.containsKey(name)) {
      write(sql.substring(start, end));
      return end;
    }
    final parameterName = 'p${++_parameterIndex}';
    final value = parameters[name];
    _parameters[parameterName] = switch (dialect) {
      SqlDialect.postgres when _hasJsonCast(sql, end) =>
        _encodeJsonTextParameter(value),
      _ => value,
    };
    write(switch (dialect) {
      SqlDialect.sqlite => ':$parameterName',
      SqlDialect.postgres => '@$parameterName',
    });
    return end;
  }

  void writeJoined<T>(
    Iterable<T> values, {
    required String separator,
    required void Function(T value) writeElement,
  }) {
    var first = true;
    for (final value in values) {
      if (!first) {
        write(separator);
      }
      first = false;
      writeElement(value);
    }
  }

  SqlStatement toStatement() {
    if (_parameters.isEmpty) {
      return SqlStatement(_buffer.toString());
    }
    return SqlStatement.named(
      _buffer.toString(),
      Map<String, Object?>.unmodifiable(_parameters),
    );
  }
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

bool _isIdentifierStart(String? char) {
  if (char == null) {
    return false;
  }
  final code = char.codeUnitAt(0);
  return code == 95 ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
}

bool _isIdentifierPart(String? char) {
  if (char == null) {
    return false;
  }
  final code = char.codeUnitAt(0);
  return _isIdentifierStart(char) || (code >= 48 && code <= 57);
}

Object? _encodePostgresParameterValue(
  Object? value,
  SqlColumn<dynamic>? column,
) {
  if (!PostgresTypeMapping.usesJsonTextParameter(column?.databaseType)) {
    return value;
  }
  return _encodeJsonTextParameter(value);
}

Object? _encodeJsonTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    _ => jsonEncode(_normalizeJsonValue(value)),
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

_SelectedProjection _normalizeProjection(Object value) {
  return switch (value) {
    final SqlSelectedExpression<dynamic> selected => _SelectedProjection(
      expression: selected.expression,
      alias: selected.alias,
    ),
    final SqlRawExpression<dynamic> expression => _SelectedProjection(
      expression: expression,
    ),
    final String rawSql => _SelectedProjection(rawSql: rawSql),
    final SqlSelectedColumn<dynamic> selected => _SelectedProjection(
      column: selected.column.asObjectColumn,
      alias: selected.alias ?? _aliasFor(selected.column),
    ),
    final SqlColumn<dynamic> column => _SelectedProjection(
      column: column.asObjectColumn,
      alias: _aliasFor(column),
    ),
    final Object invalid => throw ArgumentError.value(
      invalid,
      'columns',
      'select() accepts String, SqlRawExpression, SqlSelectedExpression, '
          'SqlColumn, or SqlSelectedColumn values only.',
    ),
  };
}

SqlPredicate _normalizePredicate(
  Object value, {
  Map<String, Object?> parameters = const <String, Object?>{},
}) {
  return switch (value) {
    final SqlPredicate predicate when parameters.isEmpty => predicate,
    final SqlPredicate _ => throw ArgumentError.value(
      parameters,
      'parameters',
      'Parameters can only be passed with raw SQL string predicates.',
    ),
    final String rawSql => SqlPredicate.raw(rawSql, parameters: parameters),
    final Object invalid => throw ArgumentError.value(
      invalid,
      'value',
      'Expected String or SqlPredicate.',
    ),
  };
}

Object _normalizeSelectable(Object value) {
  return switch (value) {
    final String rawSql => rawSql,
    final SqlRawExpression<dynamic> expression => expression,
    final SqlColumn<dynamic> column => column.asObjectColumn,
    final Object invalid => throw ArgumentError.value(
      invalid,
      'value',
      'Expected String, SqlRawExpression, or SqlColumn.',
    ),
  };
}

SqlOrderBy _normalizeOrderBy(Object value, {required bool descending}) {
  return switch (value) {
    final String rawSql => SqlOrderBy(
      expression: SqlRawExpression<dynamic>(rawSql),
      descending: descending,
    ),
    final SqlRawExpression<dynamic> expression => SqlOrderBy(
      expression: expression,
      descending: descending,
    ),
    final SqlColumn<dynamic> column => SqlOrderBy(
      column: column.asObjectColumn,
      descending: descending,
    ),
    final Object invalid => throw ArgumentError.value(
      invalid,
      'value',
      'Expected String, SqlRawExpression, or SqlColumn.',
    ),
  };
}

String _aliasFor(SqlColumn<dynamic> column) =>
    '${column.table.selectionPrefix}${column.name}';

sealed class _SqlSelection<TSelection> {
  const _SqlSelection();

  List<_SelectedProjection> get projections;

  TSelection map(SqlRow row);
}

final class _RawRowSelection extends _SqlSelection<SqlRow> {
  const _RawRowSelection(this.projections);

  @override
  final List<_SelectedProjection> projections;
  @override
  SqlRow map(SqlRow row) => row;
}

final class _TableSelection<TRow, TInsert, TUpdate>
    extends _SqlSelection<TRow> {
  _TableSelection(this.table);

  final SqlTable<TRow, TInsert, TUpdate> table;

  @override
  late final List<_SelectedProjection> projections = table.columns
      .map(
        (column) =>
            _SelectedProjection(column: column, alias: _aliasFor(column)),
      )
      .toList(growable: false);
  @override
  TRow map(SqlRow row) => table.mapRow(row, prefix: table.selectionPrefix);
}

final class _TableSelection2<
  TLeft,
  TLeftInsert,
  TLeftUpdate,
  TRight,
  TRightInsert,
  TRightUpdate
>
    extends _SqlSelection<SqlJoined2<TLeft, TRight>> {
  _TableSelection2(this.left, this.right);

  final SqlTable<TLeft, TLeftInsert, TLeftUpdate> left;
  final SqlTable<TRight, TRightInsert, TRightUpdate> right;

  @override
  late final List<_SelectedProjection> projections = [
    ...left.columns.map(
      (column) => _SelectedProjection(column: column, alias: _aliasFor(column)),
    ),
    ...right.columns.map(
      (column) => _SelectedProjection(column: column, alias: _aliasFor(column)),
    ),
  ];
  @override
  SqlJoined2<TLeft, TRight> map(SqlRow row) => SqlJoined2<TLeft, TRight>(
    left: left.mapRow(row, prefix: left.selectionPrefix),
    right: right.mapRow(row, prefix: right.selectionPrefix),
  );
}

final class _SelectedProjection {
  const _SelectedProjection({
    this.column,
    this.expression,
    this.rawSql,
    this.alias,
  }) : assert(column != null || expression != null || rawSql != null);

  final SqlColumn<dynamic>? column;
  final SqlRawExpression<dynamic>? expression;
  final String? rawSql;
  final String? alias;
}

enum _SqlJoinType {
  inner('INNER JOIN'),
  left('LEFT JOIN');

  const _SqlJoinType(this.keyword);

  final String keyword;
}

final class _SqlJoin {
  const _SqlJoin({required this.type, required this.table, required this.on});

  final _SqlJoinType type;
  final SqlTable<dynamic, dynamic, dynamic> table;
  final SqlPredicate on;
}

final class _SqlRawPredicate extends SqlPredicate {
  _SqlRawPredicate(this.sql, {Map<String, Object?>? parameters})
    : parameters = parameters ?? const <String, Object?>{};

  final String sql;
  final Map<String, Object?> parameters;
}

final class _SqlComparisonPredicate extends SqlPredicate {
  const _SqlComparisonPredicate._({
    required this.left,
    required this.operator,
    required this.right,
  });

  const _SqlComparisonPredicate.value({
    required SqlColumn<dynamic> left,
    required String operator,
    required Object? value,
  }) : this._(left: left, operator: operator, right: value);

  const _SqlComparisonPredicate.column({
    required SqlColumn<dynamic> left,
    required String operator,
    required SqlColumn<dynamic> right,
  }) : this._(left: left, operator: operator, right: right);

  final SqlColumn<dynamic> left;
  final String operator;
  final Object? right;
}

final class _SqlNullPredicate extends SqlPredicate {
  const _SqlNullPredicate({required this.column, required this.isNull});

  final SqlColumn<dynamic> column;
  final bool isNull;
}

final class _SqlInPredicate extends SqlPredicate {
  const _SqlInPredicate({required this.column, required this.values});

  final SqlColumn<dynamic> column;
  final List<Object?> values;
}

final class _SqlCompoundPredicate extends SqlPredicate {
  const _SqlCompoundPredicate(this.operator, this.predicates);

  final String operator;
  final List<SqlPredicate> predicates;
}
