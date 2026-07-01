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
    final parameterValue = _unwrapSqlParameterValue(value);
    _parameters[parameterName] = switch (dialect) {
      SqlDialect.postgres => _encodePostgresParameterValue(
        parameterValue,
        column,
      ),
      SqlDialect.sqlite => parameterValue,
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
      SqlDialect.postgres when _hasArrayCast(sql, end) =>
        _encodePostgresArrayTextParameter(value),
      SqlDialect.postgres when _hasDecimalCast(sql, end) =>
        _encodePostgresDecimalTextParameter(value),
      SqlDialect.postgres when _hasVectorCast(sql, end) =>
        _encodePostgresVectorTextParameter(value),
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
  if (PostgresTypeMapping.usesArrayTextParameter(column?.databaseType)) {
    return _encodePostgresArrayTextParameter(value);
  }
  if (PostgresTypeMapping.usesDecimalTextParameter(column?.databaseType)) {
    return _encodePostgresDecimalTextParameter(value);
  }
  if (PostgresTypeMapping.usesVectorTextParameter(column?.databaseType)) {
    return _encodePostgresVectorTextParameter(value);
  }
  if (!PostgresTypeMapping.usesJsonTextParameter(column?.databaseType)) {
    return value;
  }
  return _encodeJsonTextParameter(value);
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
  final type = _castTypeAt(sql, index);
  if (type == null) {
    return false;
  }
  return switch (PostgresTypeMapping.normalizeTypeName(type)) {
    'json' || 'jsonb' => true,
    _ => false,
  };
}

bool _hasArrayCast(String sql, int index) {
  final type = _castTypeAt(sql, index);
  if (type == null) {
    return false;
  }
  return PostgresTypeMapping.usesArrayTextParameter(type);
}

bool _hasDecimalCast(String sql, int index) {
  final type = _castTypeAt(sql, index);
  if (type == null) {
    return false;
  }
  return PostgresTypeMapping.usesDecimalTextParameter(type);
}

bool _hasVectorCast(String sql, int index) {
  final type = _castTypeAt(sql, index);
  if (type == null) {
    return false;
  }
  return PostgresTypeMapping.usesVectorTextParameter(type);
}

String? _castTypeAt(String sql, int index) {
  if (!_startsWith(sql, index, '::')) {
    return null;
  }
  var typeStart = index + 2;
  while (_peek(sql, typeStart) == ' ') {
    typeStart += 1;
  }
  final typeEnd = _readCastTypeEnd(sql, typeStart);
  if (typeEnd == typeStart) {
    return null;
  }
  return sql.substring(typeStart, typeEnd).replaceAll('"', '');
}

int _readCastTypeEnd(String sql, int start) {
  var index = start;
  while (index < sql.length) {
    final char = sql[index];
    if (_isIdentifierPart(char) ||
        char == '.' ||
        char == '"' ||
        char == '[' ||
        char == ']') {
      index += 1;
      continue;
    }
    if (char == '(') {
      index += 1;
      while (index < sql.length) {
        final innerChar = sql[index];
        index += 1;
        if (innerChar == ')') {
          break;
        }
      }
      continue;
    }
    break;
  }
  return index;
}

Object? _encodePostgresArrayTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    final Iterable<Object?> value =>
      '{${value.map(_postgresArrayElement).join(',')}}',
    _ => throw ArgumentError.value(
      value,
      'value',
      'PostgreSQL array parameters must be an Iterable, String, or null.',
    ),
  };
}

String _postgresArrayElement(Object? value) {
  if (value == null) {
    return 'NULL';
  }
  final text = switch (value) {
    final DateTime value => value.toUtc().toIso8601String(),
    final String value => value,
    final bool value => value.toString(),
    final num value => value.toString(),
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported PostgreSQL array parameter element.',
    ),
  };
  return '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

Object? _encodePostgresVectorTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    final SqlVector value => value.toPostgresText(),
    final Iterable<num> value => SqlVector(value).toPostgresText(),
    _ => throw ArgumentError.value(
      value,
      'value',
      'PostgreSQL vector parameters must be a SqlVector, Iterable<num>, String, or null.',
    ),
  };
}

Object? _encodePostgresDecimalTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    final SqlDecimal value => value.toPostgresText(),
    final num value => SqlDecimal.fromNum(value).toPostgresText(),
    _ => throw ArgumentError.value(
      value,
      'value',
      'PostgreSQL decimal parameters must be a SqlDecimal, num, String, or null.',
    ),
  };
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

final class _SqlLockingClause {
  _SqlLockingClause({
    required this.strength,
    required Iterable<Object> of,
    required this.wait,
  }) : of = List<Object>.unmodifiable(of);

  final SqlRowLockStrength strength;
  final List<Object> of;
  final SqlLockWaitPolicy wait;
}

List<Object> _normalizeLockTargets(Iterable<Object> targets) {
  return targets
      .map(
        (target) => switch (target) {
          String() || SqlTable<dynamic, dynamic, dynamic>() => target,
          final Object invalid => throw ArgumentError.value(
            invalid,
            'of',
            'Lock targets must be table names or SqlTable descriptors.',
          ),
        },
      )
      .toList(growable: false);
}

void _writeLockingClause(_SqlCompiler compiler, _SqlSelectCore query) {
  final locking = query.locking;
  if (locking == null) {
    return;
  }
  if (query.executor.dialect != SqlDialect.postgres) {
    throw StateError(
      'Row-locking SELECT clauses are only supported by PostgreSQL.',
    );
  }

  compiler.write(' FOR ');
  compiler.write(switch (locking.strength) {
    SqlRowLockStrength.update => 'UPDATE',
    SqlRowLockStrength.noKeyUpdate => 'NO KEY UPDATE',
    SqlRowLockStrength.share => 'SHARE',
    SqlRowLockStrength.keyShare => 'KEY SHARE',
  });
  if (locking.of.isNotEmpty) {
    compiler.write(' OF ');
    compiler.writeJoined(
      locking.of,
      separator: ', ',
      writeElement: (target) {
        compiler.writeIdentifier(_lockTargetName(target));
      },
    );
  }
  switch (locking.wait) {
    case SqlLockWaitPolicy.wait:
      break;
    case SqlLockWaitPolicy.noWait:
      compiler.write(' NOWAIT');
    case SqlLockWaitPolicy.skipLocked:
      compiler.write(' SKIP LOCKED');
  }
}

String _lockTargetName(Object target) {
  return switch (target) {
    final SqlRawTable table => table.alias ?? table.tableExpression,
    final SqlTable<dynamic, dynamic, dynamic> table => table.name,
    final String name => name,
    final Object invalid => throw ArgumentError.value(
      invalid,
      'target',
      'Lock targets must be table names or SqlTable descriptors.',
    ),
  };
}

_SqlFragment _sqlOrderByFragment(SqlOrderBy order, {String prefix = 'order'}) {
  final fragment = switch ((order.column, order.expression)) {
    (final SqlColumn<dynamic> column?, _) => _sqlFragment(column),
    (_, final SqlRawExpression<dynamic> expression?) => _sqlFragment(
      expression,
      prefix: prefix,
    ),
    _ => throw StateError('SqlOrderBy requires a column or expression.'),
  };
  return _SqlFragment(
    '${fragment.sql}${order.descending ? ' DESC' : ' ASC'}',
    fragment.parameters,
  );
}

_SqlFragment _sqlFragment(
  Object value, {
  Map<String, Object?>? parameters,
  String prefix = 'expr',
}) {
  if (parameters != null) {
    return _rewriteSqlFragmentParameters(
      value as String,
      parameters: parameters,
      prefix: prefix,
    );
  }
  return switch (value) {
    final SqlRawExpression<dynamic> expression => _rewriteSqlFragmentParameters(
      expression.sql,
      parameters: expression.parameters,
      prefix: prefix,
    ),
    final SqlColumn<dynamic> column => _compileSqlFragment((compiler) {
      compiler.writeColumn(column.asObjectColumn);
    }),
    final SqlTable<dynamic, dynamic, dynamic> table => _compileSqlFragment((
      compiler,
    ) {
      compiler.writeIdentifier(switch (table) {
        final SqlRawTable rawTable =>
          rawTable.alias ?? rawTable.tableExpression,
        _ => table.name,
      });
    }),
    final String rawSql => _SqlFragment(rawSql),
    final Object invalid => throw ArgumentError.value(
      invalid,
      'value',
      'Expected String, SqlRawExpression, SqlColumn, or SqlTable.',
    ),
  };
}

_SqlFragment _compileSqlFragment(void Function(_SqlCompiler compiler) write) {
  final compiler = _SqlCompiler(SqlDialect.postgres);
  write(compiler);
  return _SqlFragment(compiler.toStatement().sql);
}

_SqlFragment _rewriteSqlFragmentParameters(
  String sql, {
  required Map<String, Object?> parameters,
  required String prefix,
}) {
  if (parameters.isEmpty) {
    return _SqlFragment(sql);
  }
  final rewritten = StringBuffer();
  final rewrittenParameters = <String, Object?>{};
  var index = 0;
  while (index < sql.length) {
    final char = sql[index];
    if (char == "'") {
      index = _copyQuotedSql(sql, index, "'", rewritten);
    } else if (char == '"') {
      index = _copyQuotedSql(sql, index, '"', rewritten);
    } else if (_startsWith(sql, index, '--')) {
      index = _copyLineCommentSql(sql, index, rewritten);
    } else if (_startsWith(sql, index, '/*')) {
      index = _copyBlockCommentSql(sql, index, rewritten);
    } else if (char == '@' && _isIdentifierStart(_peek(sql, index + 1))) {
      final start = index;
      var end = index + 2;
      while (_isIdentifierPart(_peek(sql, end))) {
        end += 1;
      }
      final name = sql.substring(index + 1, end);
      if (parameters.containsKey(name)) {
        final rewrittenName = '${prefix}_$name';
        rewritten.write('@$rewrittenName');
        rewrittenParameters[rewrittenName] = parameters[name];
      } else {
        rewritten.write(sql.substring(start, end));
      }
      index = end;
    } else {
      rewritten.write(char);
      index += 1;
    }
  }
  return _SqlFragment(rewritten.toString(), rewrittenParameters);
}

int _copyQuotedSql(String sql, int start, String quote, StringBuffer target) {
  target.write(quote);
  var index = start + 1;
  while (index < sql.length) {
    final char = sql[index];
    target.write(char);
    index += 1;
    if (char == quote) {
      if (_peek(sql, index) == quote) {
        target.write(quote);
        index += 1;
        continue;
      }
      break;
    }
  }
  return index;
}

int _copyLineCommentSql(String sql, int start, StringBuffer target) {
  var index = start;
  while (index < sql.length) {
    final char = sql[index];
    target.write(char);
    index += 1;
    if (char == '\n') {
      break;
    }
  }
  return index;
}

int _copyBlockCommentSql(String sql, int start, StringBuffer target) {
  var index = start;
  while (index < sql.length) {
    final char = sql[index];
    target.write(char);
    index += 1;
    if (char == '*' && _peek(sql, index) == '/') {
      target.write('/');
      index += 1;
      break;
    }
  }
  return index;
}

Map<String, Object?> _mergeSqlFragmentParameters(
  Iterable<_SqlFragment> values,
) {
  final parameters = <String, Object?>{};
  for (final fragment in values) {
    parameters.addAll(fragment.parameters);
  }
  return parameters;
}

String _sqlStringLiteral(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

final class _SqlFragment {
  const _SqlFragment(this.sql, [this.parameters = const <String, Object?>{}]);

  final String sql;
  final Map<String, Object?> parameters;
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

final class _ColumnSelection<TValue> extends _SqlSelection<TValue> {
  _ColumnSelection(this.column);

  final SqlColumn<TValue> column;

  @override
  late final List<_SelectedProjection> projections = [
    _SelectedProjection(
      column: column.asObjectColumn,
      alias: _aliasFor(column),
    ),
  ];

  @override
  TValue map(SqlRow row) => row.read<TValue>(_aliasFor(column));
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
