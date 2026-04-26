part of '../sql_query_builder.dart';

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

  /// Selects the full `from` table and maps it back into typed rows.
  SelectedSelectQueryBuilder<TRow> selectAll() {
    return SelectedSelectQueryBuilder._(
      query: this,
      selection: _TableSelection<TRow, TInsert, TUpdate>(_from),
    );
  }

  /// Selects every column from every joined table into raw [SqlRow] objects.
  SelectedSelectQueryBuilder<SqlRow> selectAllRaw() {
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

  /// Executes an existence check for the current query shape.
  Future<bool> executeExists() async {
    final statement = _compileExists(this);
    final result = await _executor.execute(statement);
    return result.rows.isNotEmpty;
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

  /// Executes an existence check for the underlying query.
  Future<bool> executeExists() => _query.executeExists();
}

/// Builder for an `INSERT` query.
