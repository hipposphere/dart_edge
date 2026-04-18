import 'sql_dialect.dart';
import 'sql_executor.dart';
import 'sql_result.dart';
import 'sql_row.dart';
import 'sql_schema.dart';
import 'sql_statement.dart';

/// Adds fluent query-builder entry points to any [SqlExecutor].
extension SqlQueryBuilderExecutorExtension on SqlExecutor {
  /// Starts building a `SELECT` query from [table].
  SelectQueryBuilder<TRow, TInsert, TUpdate> selectFrom<TRow, TInsert, TUpdate>(
    SqlTable<TRow, TInsert, TUpdate> table,
  ) {
    return SelectQueryBuilder._(executor: this, from: table);
  }

  /// Starts building an `INSERT` query into [table].
  InsertQueryBuilder<TRow, TInsert, TUpdate> insertInto<TRow, TInsert, TUpdate>(
    SqlTable<TRow, TInsert, TUpdate> table,
  ) {
    return InsertQueryBuilder._(executor: this, table: table);
  }

  /// Starts building an `UPDATE` query for [table].
  UpdateQueryBuilder<TRow, TInsert, TUpdate>
  updateTable<TRow, TInsert, TUpdate>(SqlTable<TRow, TInsert, TUpdate> table) {
    return UpdateQueryBuilder._(executor: this, table: table);
  }
}

/// Predicate used in `WHERE` and join conditions.
sealed class SqlPredicate {
  const SqlPredicate();

  /// Combines this predicate with [other] using `AND`.
  SqlPredicate and(SqlPredicate other) =>
      _SqlCompoundPredicate('AND', [this, other]);

  /// Combines this predicate with [other] using `OR`.
  SqlPredicate or(SqlPredicate other) =>
      _SqlCompoundPredicate('OR', [this, other]);
}

/// Adds comparison, ordering, and projection helpers to [SqlColumn] objects.
extension SqlColumnPredicateExtension<TValue> on SqlColumn<TValue> {
  /// Creates `column = value`.
  SqlPredicate equals(Object? value) =>
      _SqlComparisonPredicate.value(left: this, operator: '=', value: value);

  /// Creates `column != value`.
  SqlPredicate notEquals(Object? value) =>
      _SqlComparisonPredicate.value(left: this, operator: '!=', value: value);

  /// Creates `column > value`.
  SqlPredicate greaterThan(Object value) =>
      _SqlComparisonPredicate.value(left: this, operator: '>', value: value);

  /// Creates `column >= value`.
  SqlPredicate greaterThanOrEqualTo(Object value) =>
      _SqlComparisonPredicate.value(left: this, operator: '>=', value: value);

  /// Creates `column < value`.
  SqlPredicate lessThan(Object value) =>
      _SqlComparisonPredicate.value(left: this, operator: '<', value: value);

  /// Creates `column <= value`.
  SqlPredicate lessThanOrEqualTo(Object value) =>
      _SqlComparisonPredicate.value(left: this, operator: '<=', value: value);

  /// Creates `column = otherColumn`.
  SqlPredicate equalsColumn(SqlColumn<dynamic> other) =>
      _SqlComparisonPredicate.column(left: this, operator: '=', right: other);

  /// Creates `column != otherColumn`.
  SqlPredicate notEqualsColumn(SqlColumn<dynamic> other) =>
      _SqlComparisonPredicate.column(left: this, operator: '!=', right: other);

  /// Creates `column IN (...)`.
  SqlPredicate inList(Iterable<Object?> values) =>
      _SqlInPredicate(column: this, values: List<Object?>.unmodifiable(values));

  /// Creates `column IS NULL`.
  SqlPredicate isNull() => _SqlNullPredicate(column: this, isNull: true);

  /// Creates `column IS NOT NULL`.
  SqlPredicate isNotNull() => _SqlNullPredicate(column: this, isNull: false);

  /// Selects this column with an alias.
  SqlSelectedColumn<TValue> as(String alias) =>
      SqlSelectedColumn<TValue>(column: this, alias: alias);

  /// Orders by this column ascending.
  SqlOrderBy asc() => SqlOrderBy(column: this);

  /// Orders by this column descending.
  SqlOrderBy desc() => SqlOrderBy(column: this, descending: true);
}

/// Column projection used by [SelectQueryBuilder.select].
final class SqlSelectedColumn<TValue> {
  const SqlSelectedColumn({required this.column, this.alias});

  /// Selected column.
  final SqlColumn<TValue> column;

  /// Alias used in the returned row.
  final String? alias;
}

/// One `ORDER BY` expression.
final class SqlOrderBy {
  const SqlOrderBy({required this.column, this.descending = false});

  /// Column to order by.
  final SqlColumn<dynamic> column;

  /// Whether to order descending instead of ascending.
  final bool descending;
}

/// Pair of typed rows returned from [SelectQueryBuilder.selectTables2].
final class SqlJoined2<TLeft, TRight> {
  const SqlJoined2({required this.left, required this.right});

  /// Left selected row.
  final TLeft left;

  /// Right selected row.
  final TRight right;
}

/// Builder for a typed `SELECT` query.
final class SelectQueryBuilder<TRow, TInsert, TUpdate> {
  SelectQueryBuilder._({
    required SqlExecutor executor,
    required SqlTable<TRow, TInsert, TUpdate> from,
    List<_SqlJoin> joins = const <_SqlJoin>[],
    SqlPredicate? where,
    List<SqlOrderBy> orderBy = const <SqlOrderBy>[],
    int? limit,
    int? offset,
    bool distinct = false,
  }) : _executor = executor,
       _from = from,
       _joins = List<_SqlJoin>.unmodifiable(joins),
       _where = where,
       _orderBy = List<SqlOrderBy>.unmodifiable(orderBy),
       _limit = limit,
       _offset = offset,
       _distinct = distinct;

  final SqlExecutor _executor;
  final SqlTable<TRow, TInsert, TUpdate> _from;
  final List<_SqlJoin> _joins;
  final SqlPredicate? _where;
  final List<SqlOrderBy> _orderBy;
  final int? _limit;
  final int? _offset;
  final bool _distinct;

  /// Adds an inner join.
  SelectQueryBuilder<TRow, TInsert, TUpdate>
  innerJoin<TJoinedRow, TJoinedInsert, TJoinedUpdate>(
    SqlTable<TJoinedRow, TJoinedInsert, TJoinedUpdate> table, {
    required SqlPredicate on,
  }) {
    return _copyWith(
      joins: [
        ..._joins,
        _SqlJoin(type: _SqlJoinType.inner, table: table, on: on),
      ],
    );
  }

  /// Adds a left join.
  SelectQueryBuilder<TRow, TInsert, TUpdate>
  leftJoin<TJoinedRow, TJoinedInsert, TJoinedUpdate>(
    SqlTable<TJoinedRow, TJoinedInsert, TJoinedUpdate> table, {
    required SqlPredicate on,
  }) {
    return _copyWith(
      joins: [
        ..._joins,
        _SqlJoin(type: _SqlJoinType.left, table: table, on: on),
      ],
    );
  }

  /// Replaces the current `WHERE` clause with [predicate].
  SelectQueryBuilder<TRow, TInsert, TUpdate> where(SqlPredicate predicate) =>
      _copyWith(where: predicate, useWhere: true);

  /// Adds [predicate] to the current `WHERE` clause with `AND`.
  SelectQueryBuilder<TRow, TInsert, TUpdate> andWhere(SqlPredicate predicate) =>
      _copyWith(
        where: _where == null ? predicate : _where.and(predicate),
        useWhere: true,
      );

  /// Adds [predicate] to the current `WHERE` clause with `OR`.
  SelectQueryBuilder<TRow, TInsert, TUpdate> orWhere(SqlPredicate predicate) =>
      _copyWith(
        where: _where == null ? predicate : _where.or(predicate),
        useWhere: true,
      );

  /// Appends an `ORDER BY` clause.
  SelectQueryBuilder<TRow, TInsert, TUpdate> orderBy(
    SqlColumn<dynamic> column, {
    bool descending = false,
  }) => _copyWith(
    orderBy: [
      ..._orderBy,
      SqlOrderBy(column: column, descending: descending),
    ],
  );

  /// Appends a `LIMIT` clause.
  SelectQueryBuilder<TRow, TInsert, TUpdate> limit(int value) =>
      _copyWith(limit: value, useLimit: true);

  /// Appends an `OFFSET` clause.
  SelectQueryBuilder<TRow, TInsert, TUpdate> offset(int value) =>
      _copyWith(offset: value, useOffset: true);

  /// Adds `DISTINCT` to the selection.
  SelectQueryBuilder<TRow, TInsert, TUpdate> distinct() =>
      _copyWith(distinct: true);

  /// Selects every column from every joined table into raw [SqlRow] objects.
  SelectedSelectQueryBuilder<SqlRow> selectAll() {
    final columns = _allTables
        .expand(
          (table) => table.columns.map(
            (column) =>
                _SelectedProjection(column: column, alias: _aliasFor(column)),
          ),
        )
        .toList(growable: false);
    return SelectedSelectQueryBuilder._(
      query: this,
      selection: _RawRowSelection(columns),
    );
  }

  /// Selects raw columns into [SqlRow] objects.
  ///
  /// Each item may be a [SqlColumn] or [SqlSelectedColumn].
  SelectedSelectQueryBuilder<SqlRow> select(Iterable<Object> columns) {
    final projections = columns
        .map(_normalizeSelectedColumn)
        .map(
          (selected) => _SelectedProjection(
            column: selected.column.asObjectColumn,
            alias: selected.alias ?? _aliasFor(selected.column),
          ),
        )
        .toList(growable: false);
    return SelectedSelectQueryBuilder._(
      query: this,
      selection: _RawRowSelection(projections),
    );
  }

  /// Selects one whole table and maps it with [SqlTable.mapRow].
  SelectedSelectQueryBuilder<TSelectedRow> selectTable<
    TSelectedRow,
    TSelectedInsert,
    TSelectedUpdate
  >(SqlTable<TSelectedRow, TSelectedInsert, TSelectedUpdate> table) {
    return SelectedSelectQueryBuilder._(
      query: this,
      selection:
          _TableSelection<TSelectedRow, TSelectedInsert, TSelectedUpdate>(
            table,
          ),
    );
  }

  /// Selects two whole tables and returns them as [SqlJoined2].
  SelectedSelectQueryBuilder<SqlJoined2<TRow, TJoinedRow>>
  selectTables2<TJoinedRow, TJoinedInsert, TJoinedUpdate>(
    SqlTable<TRow, TInsert, TUpdate> left,
    SqlTable<TJoinedRow, TJoinedInsert, TJoinedUpdate> right,
  ) {
    return SelectedSelectQueryBuilder._(
      query: this,
      selection:
          _TableSelection2<
            TRow,
            TInsert,
            TUpdate,
            TJoinedRow,
            TJoinedInsert,
            TJoinedUpdate
          >(left, right),
    );
  }

  SelectQueryBuilder<TRow, TInsert, TUpdate> _copyWith({
    List<_SqlJoin>? joins,
    SqlPredicate? where,
    bool useWhere = false,
    List<SqlOrderBy>? orderBy,
    int? limit,
    bool useLimit = false,
    int? offset,
    bool useOffset = false,
    bool? distinct,
  }) {
    return SelectQueryBuilder._(
      executor: _executor,
      from: _from,
      joins: joins ?? _joins,
      where: useWhere ? where : _where,
      orderBy: orderBy ?? _orderBy,
      limit: useLimit ? limit : _limit,
      offset: useOffset ? offset : _offset,
      distinct: distinct ?? _distinct,
    );
  }

  Iterable<SqlTable<dynamic, dynamic, dynamic>> get _allTables sync* {
    yield _from;
    for (final join in _joins) {
      yield join.table;
    }
  }
}

/// Builder for a completed selection shape that can be executed.
final class SelectedSelectQueryBuilder<TSelection> {
  SelectedSelectQueryBuilder._({
    required SelectQueryBuilder<dynamic, dynamic, dynamic> query,
    required _SqlSelection<TSelection> selection,
  }) : _query = query,
       _selection = selection;

  final SelectQueryBuilder<dynamic, dynamic, dynamic> _query;
  final _SqlSelection<TSelection> _selection;

  /// Replaces the current `WHERE` clause with [predicate].
  SelectedSelectQueryBuilder<TSelection> where(SqlPredicate predicate) =>
      SelectedSelectQueryBuilder<TSelection>._(
        query: _query.where(predicate),
        selection: _selection,
      );

  /// Adds [predicate] to the current `WHERE` clause with `AND`.
  SelectedSelectQueryBuilder<TSelection> andWhere(SqlPredicate predicate) =>
      SelectedSelectQueryBuilder<TSelection>._(
        query: _query.andWhere(predicate),
        selection: _selection,
      );

  /// Adds [predicate] to the current `WHERE` clause with `OR`.
  SelectedSelectQueryBuilder<TSelection> orWhere(SqlPredicate predicate) =>
      SelectedSelectQueryBuilder<TSelection>._(
        query: _query.orWhere(predicate),
        selection: _selection,
      );

  /// Appends an `ORDER BY` clause.
  SelectedSelectQueryBuilder<TSelection> orderBy(
    SqlColumn<dynamic> column, {
    bool descending = false,
  }) => SelectedSelectQueryBuilder<TSelection>._(
    query: _query.orderBy(column, descending: descending),
    selection: _selection,
  );

  /// Appends a `LIMIT` clause.
  SelectedSelectQueryBuilder<TSelection> limit(int value) =>
      SelectedSelectQueryBuilder<TSelection>._(
        query: _query.limit(value),
        selection: _selection,
      );

  /// Appends an `OFFSET` clause.
  SelectedSelectQueryBuilder<TSelection> offset(int value) =>
      SelectedSelectQueryBuilder<TSelection>._(
        query: _query.offset(value),
        selection: _selection,
      );

  /// Executes the query and returns all selected rows.
  Future<List<TSelection>> execute() async {
    final statement = _compileSelect(_query, _selection.projections);
    final result = await _query._executor.execute(statement);
    return result.rows.map(_selection.map).toList(growable: false);
  }

  /// Executes the query with `LIMIT 1` and returns the first row, if any.
  Future<TSelection?> executeTakeFirst() async {
    final results = await SelectedSelectQueryBuilder<TSelection>._(
      query: _query.limit(1),
      selection: _selection,
    ).execute();
    return results.isEmpty ? null : results.first;
  }

  /// Executes the query and expects exactly one row.
  Future<TSelection> executeTakeSingle() async {
    final results = await execute();
    return results.single;
  }
}

/// Builder for an `INSERT` query.
final class InsertQueryBuilder<TRow, TInsert, TUpdate> {
  InsertQueryBuilder._({
    required SqlExecutor executor,
    required SqlTable<TRow, TInsert, TUpdate> table,
    List<TInsert> values = const [],
  }) : _executor = executor,
       _table = table,
       _values = List<TInsert>.unmodifiable(values);

  final SqlExecutor _executor;
  final SqlTable<TRow, TInsert, TUpdate> _table;
  final List<TInsert> _values;

  /// Replaces the current insert payload with [value].
  InsertQueryBuilder<TRow, TInsert, TUpdate> values(TInsert value) =>
      InsertQueryBuilder._(executor: _executor, table: _table, values: [value]);

  /// Replaces the current insert payload with [values].
  InsertQueryBuilder<TRow, TInsert, TUpdate> valuesAll(
    Iterable<TInsert> values,
  ) => InsertQueryBuilder._(
    executor: _executor,
    table: _table,
    values: List<TInsert>.unmodifiable(values),
  );

  /// Executes the insert.
  Future<SqlResult> execute() => _executor.execute(_compileInsert(this));

  /// Executes the insert and maps the returned rows back into table rows.
  Future<List<TRow>> executeReturningTable() async {
    final statement = _compileInsert(
      this,
      returning: _TableSelection<TRow, TInsert, TUpdate>(_table),
    );
    final result = await _executor.execute(statement);
    return result.rows
        .map((row) => _table.mapRow(row, prefix: _table.selectionPrefix))
        .toList(growable: false);
  }

  /// Executes the insert and returns the first inserted row, if any.
  Future<TRow?> executeReturningFirstTable() async {
    final rows = await executeReturningTable();
    return rows.isEmpty ? null : rows.first;
  }
}

/// Builder for an `UPDATE` query.
final class UpdateQueryBuilder<TRow, TInsert, TUpdate> {
  UpdateQueryBuilder._({
    required SqlExecutor executor,
    required SqlTable<TRow, TInsert, TUpdate> table,
    Map<String, Object?>? values,
    SqlPredicate? where,
  }) : _executor = executor,
       _table = table,
       _values = values == null
           ? null
           : Map<String, Object?>.unmodifiable(values),
       _where = where;

  final SqlExecutor _executor;
  final SqlTable<TRow, TInsert, TUpdate> _table;
  final Map<String, Object?>? _values;
  final SqlPredicate? _where;

  /// Replaces the current update payload with [value].
  UpdateQueryBuilder<TRow, TInsert, TUpdate> set(TUpdate value) =>
      UpdateQueryBuilder._(
        executor: _executor,
        table: _table,
        values: _table.encodeUpdate(value),
        where: _where,
      );

  /// Replaces the current `WHERE` clause with [predicate].
  UpdateQueryBuilder<TRow, TInsert, TUpdate> where(SqlPredicate predicate) =>
      UpdateQueryBuilder._(
        executor: _executor,
        table: _table,
        values: _values,
        where: predicate,
      );

  /// Adds [predicate] to the current `WHERE` clause with `AND`.
  UpdateQueryBuilder<TRow, TInsert, TUpdate> andWhere(SqlPredicate predicate) =>
      UpdateQueryBuilder._(
        executor: _executor,
        table: _table,
        values: _values,
        where: _where == null ? predicate : _where.and(predicate),
      );

  /// Executes the update.
  Future<SqlResult> execute() => _executor.execute(_compileUpdate(this));

  /// Executes the update and maps the returned rows back into table rows.
  Future<List<TRow>> executeReturningTable() async {
    final statement = _compileUpdate(
      this,
      returning: _TableSelection<TRow, TInsert, TUpdate>(_table),
    );
    final result = await _executor.execute(statement);
    return result.rows
        .map((row) => _table.mapRow(row, prefix: _table.selectionPrefix))
        .toList(growable: false);
  }

  /// Executes the update and returns the first updated row, if any.
  Future<TRow?> executeReturningFirstTable() async {
    final rows = await executeReturningTable();
    return rows.isEmpty ? null : rows.first;
  }
}

SqlStatement _compileSelect(
  SelectQueryBuilder<dynamic, dynamic, dynamic> query,
  List<_SelectedProjection> projections,
) {
  final compiler = _SqlCompiler(query._executor.dialect);
  compiler.write('SELECT ');
  if (query._distinct) {
    compiler.write('DISTINCT ');
  }
  compiler.writeJoined(
    projections,
    separator: ', ',
    writeElement: (projection) {
      compiler.writeColumn(projection.column);
      compiler.write(' AS ');
      compiler.writeIdentifier(projection.alias);
    },
  );
  compiler.write(' FROM ');
  compiler.writeTable(query._from);
  for (final join in query._joins) {
    compiler.write(' ');
    compiler.write(join.type.keyword);
    compiler.write(' ');
    compiler.writeTable(join.table);
    compiler.write(' ON ');
    compiler.writePredicate(join.on);
  }
  final where = query._where;
  if (where != null) {
    compiler.write(' WHERE ');
    compiler.writePredicate(where);
  }
  if (query._orderBy.isNotEmpty) {
    compiler.write(' ORDER BY ');
    compiler.writeJoined(
      query._orderBy,
      separator: ', ',
      writeElement: (order) {
        compiler.writeColumn(order.column);
        compiler.write(order.descending ? ' DESC' : ' ASC');
      },
    );
  }
  if (query._limit case final int limit) {
    compiler.write(' LIMIT $limit');
  }
  if (query._offset case final int offset) {
    compiler.write(' OFFSET $offset');
  }
  return compiler.toStatement();
}

SqlStatement _compileInsert(
  InsertQueryBuilder<dynamic, dynamic, dynamic> query, {
  _SqlSelection<dynamic>? returning,
}) {
  if (query._values.isEmpty) {
    throw StateError('insertInto() requires at least one values() call.');
  }

  final encodedRows = query._values
      .map(query._table.encodeInsert)
      .toList(growable: false);
  final columnNames = query._table.columns
      .map((column) => column.name)
      .where((name) => encodedRows.any((row) => row.containsKey(name)))
      .toList(growable: false);

  if (columnNames.isEmpty) {
    throw StateError('No insertable columns were provided.');
  }

  final compiler = _SqlCompiler(query._executor.dialect);
  compiler.write('INSERT INTO ');
  compiler.writeTable(query._table);
  compiler.write(' (');
  compiler.writeJoined(
    columnNames,
    separator: ', ',
    writeElement: compiler.writeIdentifier,
  );
  compiler.write(') VALUES ');
  compiler.writeJoined(
    encodedRows,
    separator: ', ',
    writeElement: (row) {
      compiler.write('(');
      compiler.writeJoined(
        columnNames,
        separator: ', ',
        writeElement: (columnName) {
          if (!row.containsKey(columnName)) {
            compiler.write('DEFAULT');
            return;
          }
          compiler.writeValue(row[columnName]);
        },
      );
      compiler.write(')');
    },
  );
  if (returning != null) {
    compiler.write(' RETURNING ');
    compiler.writeJoined(
      returning.projections,
      separator: ', ',
      writeElement: (projection) {
        compiler.writeColumn(projection.column);
        compiler.write(' AS ');
        compiler.writeIdentifier(projection.alias);
      },
    );
  }
  return compiler.toStatement();
}

SqlStatement _compileUpdate(
  UpdateQueryBuilder<dynamic, dynamic, dynamic> query, {
  _SqlSelection<dynamic>? returning,
}) {
  final values = query._values;
  if (values == null || values.isEmpty) {
    throw StateError('updateTable() requires a non-empty set() payload.');
  }

  final compiler = _SqlCompiler(query._executor.dialect);
  compiler.write('UPDATE ');
  compiler.writeTable(query._table);
  compiler.write(' SET ');
  final assignments = query._table.columns
      .where((column) => values.containsKey(column.name))
      .map((column) => (column: column, value: values[column.name]))
      .toList(growable: false);
  compiler.writeJoined(
    assignments,
    separator: ', ',
    writeElement: (assignment) {
      compiler.writeIdentifier(assignment.column.name);
      compiler.write(' = ');
      compiler.writeValue(assignment.value);
    },
  );
  if (query._where case final SqlPredicate where) {
    compiler.write(' WHERE ');
    compiler.writePredicate(where);
  }
  if (returning != null) {
    compiler.write(' RETURNING ');
    compiler.writeJoined(
      returning.projections,
      separator: ', ',
      writeElement: (projection) {
        compiler.writeColumn(projection.column);
        compiler.write(' AS ');
        compiler.writeIdentifier(projection.alias);
      },
    );
  }
  return compiler.toStatement();
}

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
    if (table.schema case final String schemaName) {
      writeIdentifier(schemaName);
      write('.');
    }
    writeIdentifier(table.name);
  }

  void writeColumn(SqlColumn<dynamic> column) {
    writeTable(column.table);
    write('.');
    writeIdentifier(column.name);
  }

  void writeValue(Object? value) {
    final parameterName = 'p${++_parameterIndex}';
    _parameters[parameterName] = value;
    final placeholderPrefix = switch (dialect) {
      SqlDialect.sqlite => ':',
      SqlDialect.postgres => '@',
    };
    _buffer.write('$placeholderPrefix$parameterName');
  }

  void writePredicate(SqlPredicate predicate) {
    switch (predicate) {
      case _SqlComparisonPredicate():
        writeColumn(predicate.left.asObjectColumn);
        write(' ${predicate.operator} ');
        switch (predicate.right) {
          case final SqlColumn<dynamic> column:
            writeColumn(column);
          default:
            writeValue(predicate.right);
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
          writeElement: writeValue,
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

SqlSelectedColumn<dynamic> _normalizeSelectedColumn(Object value) {
  return switch (value) {
    final SqlSelectedColumn<dynamic> selected => selected,
    final SqlColumn<dynamic> column => SqlSelectedColumn<dynamic>(
      column: column,
    ),
    final Object invalid => throw ArgumentError.value(
      invalid,
      'columns',
      'select() accepts SqlColumn or SqlSelectedColumn values only.',
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
  const _SelectedProjection({required this.column, required this.alias});

  final SqlColumn<dynamic> column;
  final String alias;
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
