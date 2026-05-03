part of '../sql_query_builder.dart';

final class _SqlSelectCore {
  _SqlSelectCore({
    required this.executor,
    required this.from,
    List<_SqlJoin> joins = const <_SqlJoin>[],
    this.where,
    List<Object> groupBy = const <Object>[],
    this.having,
    List<SqlOrderBy> orderBy = const <SqlOrderBy>[],
    this.limit,
    this.offset,
    this.distinct = false,
  }) : joins = List<_SqlJoin>.unmodifiable(joins),
       groupBy = List<Object>.unmodifiable(groupBy),
       orderBy = List<SqlOrderBy>.unmodifiable(orderBy);

  final SqlExecutor executor;
  final SqlTable<dynamic, dynamic, dynamic> from;
  final List<_SqlJoin> joins;
  final SqlPredicate? where;
  final List<Object> groupBy;
  final SqlPredicate? having;
  final List<SqlOrderBy> orderBy;
  final int? limit;
  final int? offset;
  final bool distinct;

  _SqlSelectCore innerJoin(
    SqlTable<dynamic, dynamic, dynamic> table, {
    required SqlPredicate on,
  }) {
    return _copyWith(
      joins: [
        ...joins,
        _SqlJoin(type: _SqlJoinType.inner, table: table, on: on),
      ],
    );
  }

  _SqlSelectCore leftJoin(
    SqlTable<dynamic, dynamic, dynamic> table, {
    required SqlPredicate on,
  }) {
    return _copyWith(
      joins: [
        ...joins,
        _SqlJoin(type: _SqlJoinType.left, table: table, on: on),
      ],
    );
  }

  _SqlSelectCore addWhere(SqlPredicate predicate) => _copyWith(
    where: where == null ? predicate : where!.and(predicate),
    useWhere: true,
  );

  _SqlSelectCore addGroupBy(Object value) =>
      _copyWith(groupBy: [...groupBy, value]);

  _SqlSelectCore setHaving(SqlPredicate predicate) =>
      _copyWith(having: predicate, useHaving: true);

  _SqlSelectCore addOrderBy(SqlOrderBy value) =>
      _copyWith(orderBy: [...orderBy, value]);

  _SqlSelectCore setLimit(int value) => _copyWith(limit: value, useLimit: true);

  _SqlSelectCore setOffset(int value) =>
      _copyWith(offset: value, useOffset: true);

  _SqlSelectCore setDistinct() => _copyWith(distinct: true);

  _SqlSelectCore _copyWith({
    List<_SqlJoin>? joins,
    SqlPredicate? where,
    bool useWhere = false,
    List<Object>? groupBy,
    SqlPredicate? having,
    bool useHaving = false,
    List<SqlOrderBy>? orderBy,
    int? limit,
    bool useLimit = false,
    int? offset,
    bool useOffset = false,
    bool? distinct,
  }) {
    return _SqlSelectCore(
      executor: executor,
      from: from,
      joins: joins ?? this.joins,
      where: useWhere ? where : this.where,
      groupBy: groupBy ?? this.groupBy,
      having: useHaving ? having : this.having,
      orderBy: orderBy ?? this.orderBy,
      limit: useLimit ? limit : this.limit,
      offset: useOffset ? offset : this.offset,
      distinct: distinct ?? this.distinct,
    );
  }

  Iterable<SqlTable<dynamic, dynamic, dynamic>> get allTables sync* {
    yield from;
    for (final join in joins) {
      yield join.table;
    }
  }
}

/// Raw `SELECT` query builder.
final class SqlRawSelectQueryBuilder {
  SqlRawSelectQueryBuilder._({
    required SqlExecutor executor,
    required SqlTable<dynamic, dynamic, dynamic> from,
  }) : _core = _SqlSelectCore(executor: executor, from: from);

  const SqlRawSelectQueryBuilder._fromCore(this._core);

  final _SqlSelectCore _core;

  /// Adds an inner join.
  SqlRawSelectQueryBuilder innerJoin(
    String tableExpression, {
    String? alias,
    required Object on,
    Map<String, Object?> onParameters = const <String, Object?>{},
  }) => _innerJoinTable(
    SqlRawTable(tableExpression, alias: alias),
    on: _normalizePredicate(on, parameters: onParameters),
  );

  /// Adds a left join.
  SqlRawSelectQueryBuilder leftJoin(
    String tableExpression, {
    String? alias,
    required Object on,
    Map<String, Object?> onParameters = const <String, Object?>{},
  }) => _leftJoinTable(
    SqlRawTable(tableExpression, alias: alias),
    on: _normalizePredicate(on, parameters: onParameters),
  );

  SqlRawSelectQueryBuilder _innerJoinTable(
    SqlTable<dynamic, dynamic, dynamic> table, {
    required SqlPredicate on,
  }) => SqlRawSelectQueryBuilder._fromCore(_core.innerJoin(table, on: on));

  SqlRawSelectQueryBuilder _leftJoinTable(
    SqlTable<dynamic, dynamic, dynamic> table, {
    required SqlPredicate on,
  }) => SqlRawSelectQueryBuilder._fromCore(_core.leftJoin(table, on: on));

  /// Adds [predicate] to the `WHERE` clause with `AND`.
  SqlRawSelectQueryBuilder where(SqlPredicate predicate) =>
      SqlRawSelectQueryBuilder._fromCore(_core.addWhere(predicate));

  /// Appends a `GROUP BY` SQL expression.
  SqlRawSelectQueryBuilder groupBy(String sql) =>
      _groupByValue(SqlRawExpression<dynamic>(sql));

  /// Appends a `GROUP BY` raw expression.
  SqlRawSelectQueryBuilder groupByExpression(
    SqlRawExpression<dynamic> expression,
  ) => _groupByValue(expression);

  SqlRawSelectQueryBuilder _groupByValue(Object value) =>
      SqlRawSelectQueryBuilder._fromCore(_core.addGroupBy(value));

  /// Replaces the current `HAVING` clause with [predicate].
  SqlRawSelectQueryBuilder having(
    Object predicate, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) => SqlRawSelectQueryBuilder._fromCore(
    _core.setHaving(_normalizePredicate(predicate, parameters: parameters)),
  );

  /// Appends an `ORDER BY` SQL expression.
  SqlRawSelectQueryBuilder orderBy(String sql, {bool descending = false}) =>
      orderByExpression(SqlRawExpression<dynamic>(sql), descending: descending);

  /// Appends an `ORDER BY` clause for a raw expression.
  SqlRawSelectQueryBuilder orderByExpression(
    SqlRawExpression<dynamic> expression, {
    bool descending = false,
  }) =>
      _orderByValue(SqlOrderBy(expression: expression, descending: descending));

  SqlRawSelectQueryBuilder _orderByValue(SqlOrderBy value) =>
      SqlRawSelectQueryBuilder._fromCore(_core.addOrderBy(value));

  /// Appends a `LIMIT` clause.
  SqlRawSelectQueryBuilder limit(int value) =>
      SqlRawSelectQueryBuilder._fromCore(_core.setLimit(value));

  /// Appends an `OFFSET` clause.
  SqlRawSelectQueryBuilder offset(int value) =>
      SqlRawSelectQueryBuilder._fromCore(_core.setOffset(value));

  /// Adds `DISTINCT` to the selection.
  SqlRawSelectQueryBuilder distinct() =>
      SqlRawSelectQueryBuilder._fromCore(_core.setDistinct());

  /// Selects every column into raw [SqlRow] objects.
  SelectedSelectQueryBuilder<SqlRow> selectAll() {
    return SelectedSelectQueryBuilder._(
      core: _core,
      selection: const _RawRowSelection([_SelectedProjection(rawSql: '*')]),
    );
  }

  /// Selects SQL fragments into [SqlRow] objects.
  ///
  /// Each item may be a raw SQL [String], [SqlRawExpression],
  /// [SqlSelectedExpression], [SqlColumn], or [SqlSelectedColumn].
  SelectedSelectQueryBuilder<SqlRow> select(Iterable<Object> columns) {
    final projections = columns
        .map(_normalizeProjection)
        .toList(growable: false);
    return SelectedSelectQueryBuilder._(
      core: _core,
      selection: _RawRowSelection(projections),
    );
  }

  /// Executes an existence check for the current query shape.
  Future<bool> executeExists() async {
    final statement = _compileExists(_core);
    final result = await _core.executor.execute(statement);
    return result.rows.isNotEmpty;
  }

  /// Executes `COUNT(*)` for the current query shape.
  Future<int> executeCount() async {
    final statement = _compileCount(_core);
    final result = await _core.executor.execute(statement);
    return result.single.read<int>('count');
  }

  /// Compiles the current existence query without executing it.
  SqlStatement toExistsStatement() => _compileExists(_core);

  /// Compiles the current count query without executing it.
  SqlStatement toCountStatement() => _compileCount(_core);
}

/// Builder for a typed `SELECT` query.
final class SelectQueryBuilder<TRow, TInsert, TUpdate> {
  SelectQueryBuilder._({
    required SqlExecutor executor,
    required SqlTable<TRow, TInsert, TUpdate> from,
  }) : _from = from,
       _raw = SqlRawSelectQueryBuilder._(executor: executor, from: from);

  const SelectQueryBuilder._fromRaw({
    required SqlTable<TRow, TInsert, TUpdate> from,
    required SqlRawSelectQueryBuilder raw,
  }) : _from = from,
       _raw = raw;

  final SqlTable<TRow, TInsert, TUpdate> _from;
  final SqlRawSelectQueryBuilder _raw;

  /// Adds an inner join.
  SelectQueryBuilder<TRow, TInsert, TUpdate>
  innerJoin<TJoinedRow, TJoinedInsert, TJoinedUpdate>(
    SqlTable<TJoinedRow, TJoinedInsert, TJoinedUpdate> table, {
    required SqlPredicate on,
  }) {
    return _copyWith(raw: _raw._innerJoinTable(table, on: on));
  }

  /// Adds a left join.
  SelectQueryBuilder<TRow, TInsert, TUpdate>
  leftJoin<TJoinedRow, TJoinedInsert, TJoinedUpdate>(
    SqlTable<TJoinedRow, TJoinedInsert, TJoinedUpdate> table, {
    required SqlPredicate on,
  }) {
    return _copyWith(raw: _raw._leftJoinTable(table, on: on));
  }

  /// Adds [predicate] to the `WHERE` clause with `AND`.
  SelectQueryBuilder<TRow, TInsert, TUpdate> where(SqlPredicate predicate) =>
      _copyWith(raw: _raw.where(predicate));

  /// Appends a `GROUP BY` column.
  SelectQueryBuilder<TRow, TInsert, TUpdate> groupBy(
    SqlColumn<dynamic> column,
  ) => _copyWith(raw: _raw._groupByValue(column));

  /// Appends a `GROUP BY` raw expression.
  SelectQueryBuilder<TRow, TInsert, TUpdate> groupByExpression(
    SqlRawExpression<dynamic> expression,
  ) => _copyWith(raw: _raw.groupByExpression(expression));

  /// Replaces the current `HAVING` clause with [predicate].
  SelectQueryBuilder<TRow, TInsert, TUpdate> having(SqlPredicate predicate) =>
      _copyWith(raw: _raw.having(predicate));

  /// Appends an `ORDER BY` clause.
  SelectQueryBuilder<TRow, TInsert, TUpdate> orderBy(
    SqlColumn<dynamic> column, {
    bool descending = false,
  }) => _copyWith(
    raw: _raw._orderByValue(SqlOrderBy(column: column, descending: descending)),
  );

  /// Appends an `ORDER BY` clause for a raw expression.
  SelectQueryBuilder<TRow, TInsert, TUpdate> orderByExpression(
    SqlRawExpression<dynamic> expression, {
    bool descending = false,
  }) => _copyWith(
    raw: _raw.orderByExpression(expression, descending: descending),
  );

  /// Appends a `LIMIT` clause.
  SelectQueryBuilder<TRow, TInsert, TUpdate> limit(int value) =>
      _copyWith(raw: _raw.limit(value));

  /// Appends an `OFFSET` clause.
  SelectQueryBuilder<TRow, TInsert, TUpdate> offset(int value) =>
      _copyWith(raw: _raw.offset(value));

  /// Adds `DISTINCT` to the selection.
  SelectQueryBuilder<TRow, TInsert, TUpdate> distinct() =>
      _copyWith(raw: _raw.distinct());

  /// Selects the full `from` table and maps it back into typed rows.
  SelectedSelectQueryBuilder<TRow> selectAll() {
    return SelectedSelectQueryBuilder._(
      core: _raw._core,
      selection: _TableSelection<TRow, TInsert, TUpdate>(_from),
    );
  }

  /// Selects every column from every joined table into raw [SqlRow] objects.
  SelectedSelectQueryBuilder<SqlRow> selectAllRaw() {
    final columns = _raw._core.allTables
        .expand(
          (table) => table.columns.map(
            (column) =>
                _SelectedProjection(column: column, alias: _aliasFor(column)),
          ),
        )
        .toList(growable: false);
    return SelectedSelectQueryBuilder._(
      core: _raw._core,
      selection: _RawRowSelection(columns),
    );
  }

  /// Selects raw columns into [SqlRow] objects.
  ///
  /// Each item may be a [SqlColumn], [SqlSelectedColumn], or
  /// [SqlSelectedExpression].
  SelectedSelectQueryBuilder<SqlRow> select(Iterable<Object> columns) =>
      _raw.select(columns);

  /// Selects one whole table and maps it with [SqlTable.mapRow].
  SelectedSelectQueryBuilder<TSelectedRow> selectTable<
    TSelectedRow,
    TSelectedInsert,
    TSelectedUpdate
  >(SqlTable<TSelectedRow, TSelectedInsert, TSelectedUpdate> table) {
    return SelectedSelectQueryBuilder._(
      core: _raw._core,
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
      core: _raw._core,
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

  /// Executes an existence check for the current query shape.
  Future<bool> executeExists() => _raw.executeExists();

  /// Executes `COUNT(*)` for the current query shape.
  Future<int> executeCount() => _raw.executeCount();

  /// Compiles the current existence query without executing it.
  SqlStatement toExistsStatement() => _raw.toExistsStatement();

  /// Compiles the current count query without executing it.
  SqlStatement toCountStatement() => _raw.toCountStatement();

  SelectQueryBuilder<TRow, TInsert, TUpdate> _copyWith({
    required SqlRawSelectQueryBuilder raw,
  }) {
    return SelectQueryBuilder._fromRaw(from: _from, raw: raw);
  }
}

/// Builder for a completed selection shape that can be executed.
final class SelectedSelectQueryBuilder<TSelection> {
  const SelectedSelectQueryBuilder._({
    required _SqlSelectCore core,
    required _SqlSelection<TSelection> selection,
  }) : _core = core,
       _selection = selection;

  final _SqlSelectCore _core;
  final _SqlSelection<TSelection> _selection;

  /// Adds [predicate] to the `WHERE` clause with `AND`.
  SelectedSelectQueryBuilder<TSelection> where(SqlPredicate predicate) =>
      SelectedSelectQueryBuilder<TSelection>._(
        core: _core.addWhere(predicate),
        selection: _selection,
      );

  /// Appends a `GROUP BY` expression.
  SelectedSelectQueryBuilder<TSelection> groupBy(Object value) =>
      SelectedSelectQueryBuilder<TSelection>._(
        core: _core.addGroupBy(_normalizeSelectable(value)),
        selection: _selection,
      );

  /// Appends a `GROUP BY` raw expression.
  SelectedSelectQueryBuilder<TSelection> groupByExpression(
    SqlRawExpression<dynamic> expression,
  ) => SelectedSelectQueryBuilder<TSelection>._(
    core: _core.addGroupBy(expression),
    selection: _selection,
  );

  /// Replaces the current `HAVING` clause with [predicate].
  SelectedSelectQueryBuilder<TSelection> having(
    Object predicate, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) => SelectedSelectQueryBuilder<TSelection>._(
    core: _core.setHaving(
      _normalizePredicate(predicate, parameters: parameters),
    ),
    selection: _selection,
  );

  /// Appends an `ORDER BY` clause.
  SelectedSelectQueryBuilder<TSelection> orderBy(
    Object value, {
    bool descending = false,
  }) => SelectedSelectQueryBuilder<TSelection>._(
    core: _core.addOrderBy(_normalizeOrderBy(value, descending: descending)),
    selection: _selection,
  );

  /// Appends an `ORDER BY` clause for a raw expression.
  SelectedSelectQueryBuilder<TSelection> orderByExpression(
    SqlRawExpression<dynamic> expression, {
    bool descending = false,
  }) => SelectedSelectQueryBuilder<TSelection>._(
    core: _core.addOrderBy(
      SqlOrderBy(expression: expression, descending: descending),
    ),
    selection: _selection,
  );

  /// Appends a `LIMIT` clause.
  SelectedSelectQueryBuilder<TSelection> limit(int value) =>
      SelectedSelectQueryBuilder<TSelection>._(
        core: _core.setLimit(value),
        selection: _selection,
      );

  /// Appends an `OFFSET` clause.
  SelectedSelectQueryBuilder<TSelection> offset(int value) =>
      SelectedSelectQueryBuilder<TSelection>._(
        core: _core.setOffset(value),
        selection: _selection,
      );

  /// Adds `DISTINCT` to the selection.
  SelectedSelectQueryBuilder<TSelection> distinct() =>
      SelectedSelectQueryBuilder<TSelection>._(
        core: _core.setDistinct(),
        selection: _selection,
      );

  /// Executes the query and returns all selected rows.
  Future<List<TSelection>> execute() async {
    final statement = toStatement();
    final result = await _core.executor.execute(statement);
    return result.rows.map(_selection.map).toList(growable: false);
  }

  /// Compiles this query without executing it.
  SqlStatement toStatement() => _compileSelect(_core, _selection.projections);

  /// Executes the query with `LIMIT 1` and returns the first row, if any.
  Future<TSelection?> executeFirstOrNull() async {
    final results = await SelectedSelectQueryBuilder<TSelection>._(
      core: _core.setLimit(1),
      selection: _selection,
    ).execute();
    return results.isEmpty ? null : results.first;
  }

  /// Executes the query and expects exactly one row.
  Future<TSelection> executeSingle() async {
    final results = await execute();
    return results.single;
  }

  /// Executes an existence check for the underlying query.
  Future<bool> executeExists() async {
    final statement = _compileExists(_core);
    final result = await _core.executor.execute(statement);
    return result.rows.isNotEmpty;
  }

  /// Executes `COUNT(*)` for the underlying query shape.
  Future<int> executeCount() async {
    final statement = _compileCount(_core);
    final result = await _core.executor.execute(statement);
    return result.single.read<int>('count');
  }

  /// Compiles the current existence query without executing it.
  SqlStatement toExistsStatement() => _compileExists(_core);

  /// Compiles the current count query without executing it.
  SqlStatement toCountStatement() => _compileCount(_core);
}
