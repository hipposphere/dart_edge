part of '../sql_query_builder.dart';

/// Typed query root bound to one [SqlExecutor].
final class SqlTypedQueryRoot {
  const SqlTypedQueryRoot(this._executor);

  final SqlExecutor _executor;

  /// Starts building a `SELECT` query from [table].
  SelectQueryBuilder<TRow, TInsert, TUpdate> from<TRow, TInsert, TUpdate>(
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

/// Raw query root bound to one [SqlExecutor].
final class SqlRawQueryRoot {
  const SqlRawQueryRoot(this._executor);

  final SqlExecutor _executor;

  /// Creates a raw SQL expression.
  SqlRawExpression<TValue> expr<TValue>(
    String sql, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    return SqlRawExpression<TValue>(sql, parameters: parameters);
  }

  /// Creates a raw SQL condition.
  SqlPredicate condition(
    String sql, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    return SqlPredicate.raw(sql, parameters: parameters);
  }

  /// Creates `left = value`, or `left IS NULL` for a null [value].
  SqlPredicate eq(String left, Object? value) {
    return value == null
        ? condition('$left IS NULL')
        : _compare(left, '=', value);
  }

  /// Creates `left != value`, or `left IS NOT NULL` for a null [value].
  SqlPredicate notEq(String left, Object? value) {
    return value == null
        ? condition('$left IS NOT NULL')
        : _compare(left, '!=', value);
  }

  /// Creates `left > value`.
  SqlPredicate gt(String left, Object? value) => _compare(left, '>', value);

  /// Creates `left >= value`.
  SqlPredicate gte(String left, Object? value) => _compare(left, '>=', value);

  /// Creates `left < value`.
  SqlPredicate lt(String left, Object? value) => _compare(left, '<', value);

  /// Creates `left <= value`.
  SqlPredicate lte(String left, Object? value) => _compare(left, '<=', value);

  /// Creates `left = right` for two SQL expressions.
  SqlPredicate eqRef(String left, String right) => condition('$left = $right');

  /// Creates `left != right` for two SQL expressions.
  SqlPredicate notEqRef(String left, String right) =>
      condition('$left != $right');

  /// Creates `left > right` for two SQL expressions.
  SqlPredicate gtRef(String left, String right) => condition('$left > $right');

  /// Creates `left >= right` for two SQL expressions.
  SqlPredicate gteRef(String left, String right) =>
      condition('$left >= $right');

  /// Creates `left < right` for two SQL expressions.
  SqlPredicate ltRef(String left, String right) => condition('$left < $right');

  /// Creates `left <= right` for two SQL expressions.
  SqlPredicate lteRef(String left, String right) =>
      condition('$left <= $right');

  /// Creates `expression IS TRUE`.
  SqlPredicate isTrue(String expression) => condition('$expression IS TRUE');

  /// Creates `expression IS FALSE`.
  SqlPredicate isFalse(String expression) => condition('$expression IS FALSE');

  SqlPredicate _compare(String left, String operator, Object? value) {
    return condition('$left $operator @value', parameters: {'value': value});
  }

  /// Combines [predicates] with `AND`.
  SqlPredicate and(Iterable<SqlPredicate> predicates) {
    return .and(predicates);
  }

  /// Combines [predicates] with `OR`.
  SqlPredicate or(Iterable<SqlPredicate> predicates) {
    return .or(predicates);
  }

  /// Starts building a raw `SELECT` query from [tableExpression].
  SqlRawSelectQueryBuilder from(String tableExpression, {String? alias}) {
    return SqlRawSelectQueryBuilder._(
      executor: _executor,
      from: SqlRawTable(tableExpression, alias: alias),
    );
  }
}

/// Exposes dedicated query roots on any [SqlExecutor].
extension SqlExecutorBuilderExtension on SqlExecutor {
  /// Typed query root for generated [SqlTable] descriptors.
  SqlTypedQueryRoot get typed => SqlTypedQueryRoot(this);

  /// Raw query root for catalog and ad hoc SQL queries.
  SqlRawQueryRoot get raw => SqlRawQueryRoot(this);
}

/// Predicate used in `WHERE` and join conditions.
sealed class SqlPredicate {
  const SqlPredicate();

  /// Creates a raw SQL predicate fragment.
  factory SqlPredicate.raw(String sql, {Map<String, Object?>? parameters}) =
      _SqlRawPredicate;

  /// Combines [predicates] with `AND`.
  factory SqlPredicate.and(Iterable<SqlPredicate> predicates) {
    return _compound('AND', predicates, 'and');
  }

  /// Combines [predicates] with `OR`.
  factory SqlPredicate.or(Iterable<SqlPredicate> predicates) {
    return _compound('OR', predicates, 'or');
  }

  /// Combines this predicate with [other] using `AND`.
  SqlPredicate and(SqlPredicate other) => .and([this, other]);

  /// Combines this predicate with [other] using `OR`.
  SqlPredicate or(SqlPredicate other) => .or([this, other]);

  static SqlPredicate _compound(
    String operator,
    Iterable<SqlPredicate> predicates,
    String name,
  ) {
    final list = predicates.toList(growable: false);
    if (list.isEmpty) {
      throw ArgumentError.value(
        predicates,
        'predicates',
        '$name() requires at least one predicate.',
      );
    }
    if (list.length == 1) {
      return list.single;
    }
    return _SqlCompoundPredicate(operator, list);
  }
}

/// Raw SQL expression for advanced projections and ordering.
final class SqlRawExpression<TValue> {
  const SqlRawExpression(
    this.sql, {
    this.parameters = const <String, Object?>{},
  });

  /// SQL fragment for this expression.
  final String sql;

  /// Named parameters referenced by [sql].
  final Map<String, Object?> parameters;

  /// Selects this expression with [alias].
  SqlSelectedExpression<TValue> as(String alias) {
    return SqlSelectedExpression<TValue>(expression: this, alias: alias);
  }

  /// Orders by this expression ascending.
  SqlOrderBy asc() => SqlOrderBy(expression: this);

  /// Orders by this expression descending.
  SqlOrderBy desc() => SqlOrderBy(expression: this, descending: true);
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

/// Column projection used by select builders.
final class SqlSelectedColumn<TValue> {
  const SqlSelectedColumn({required this.column, this.alias});

  /// Selected column.
  final SqlColumn<TValue> column;

  /// Alias used in the returned row.
  final String? alias;
}

/// Raw expression projection used by select builders.
final class SqlSelectedExpression<TValue> {
  const SqlSelectedExpression({required this.expression, required this.alias});

  /// Selected expression.
  final SqlRawExpression<TValue> expression;

  /// Alias used in the returned row.
  final String alias;
}

/// One `ORDER BY` expression.
final class SqlOrderBy {
  const SqlOrderBy({this.column, this.expression, this.descending = false})
    : assert(column != null || expression != null);

  /// Column to order by.
  final SqlColumn<dynamic>? column;

  /// Raw expression to order by.
  final SqlRawExpression<dynamic>? expression;

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
