part of '../sql_query_builder.dart';

/// Dedicated query-builder entrypoint bound to one [SqlExecutor].
final class SqlBuilder {
  const SqlBuilder(this._executor);

  final SqlExecutor _executor;

  /// Starts building a `SELECT` query from [table].
  SelectQueryBuilder<TRow, TInsert, TUpdate> selectFrom<TRow, TInsert, TUpdate>(
    SqlTable<TRow, TInsert, TUpdate> table,
  ) {
    return SelectQueryBuilder._(executor: _executor, from: table);
  }

  /// Starts building an `INSERT` query into [table].
  InsertQueryBuilder<TRow, TInsert, TUpdate> insertInto<TRow, TInsert, TUpdate>(
    SqlTable<TRow, TInsert, TUpdate> table,
  ) {
    return InsertQueryBuilder._(executor: _executor, table: table);
  }

  /// Starts building a `DELETE` query for [table].
  DeleteQueryBuilder<TRow, TInsert, TUpdate> deleteFrom<TRow, TInsert, TUpdate>(
    SqlTable<TRow, TInsert, TUpdate> table,
  ) {
    return DeleteQueryBuilder._(executor: _executor, table: table);
  }

  /// Starts building an `UPDATE` query for [table].
  UpdateQueryBuilder<TRow, TInsert, TUpdate>
  updateTable<TRow, TInsert, TUpdate>(SqlTable<TRow, TInsert, TUpdate> table) {
    return UpdateQueryBuilder._(executor: _executor, table: table);
  }
}

/// Exposes a dedicated query-builder root on any [SqlExecutor].
extension SqlExecutorBuilderExtension on SqlExecutor {
  /// Query-builder entrypoint kept separate from raw `execute(...)` calls.
  SqlBuilder get builder => SqlBuilder(this);
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
