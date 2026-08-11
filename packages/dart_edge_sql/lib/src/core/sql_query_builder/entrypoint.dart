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

  /// Starts building a `SELECT` query from a CTE or derived relation.
  SelectQueryBuilder<SqlRow, Never, Never> fromRelation(
    SqlQueryRelation relation,
  ) => SelectQueryBuilder._(executor: _executor, from: relation._table);

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

/// Typed helpers for composing SQL expression fragments.
abstract final class Sql {
  /// Creates a raw SQL expression.
  static SqlRawExpression<TValue> raw<TValue>(
    String sql, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    return SqlRawExpression<TValue>(sql, parameters: parameters);
  }

  /// Creates a parameterized SQL value expression.
  static SqlRawExpression<TValue> value<TValue>(Object? value) {
    final fragment = _valueFragment(value, prefix: 'value');
    return SqlRawExpression<TValue>(
      fragment.sql,
      parameters: fragment.parameters,
    );
  }

  /// Creates `value::type`.
  static SqlRawExpression<TValue> cast<TValue>(
    Object value, {
    String? postgres,
  }) {
    if (postgres == null || postgres.trim().isEmpty) {
      throw ArgumentError.value(
        postgres,
        'postgres',
        'cast() requires a PostgreSQL type.',
      );
    }
    final fragment = _sqlFragment(value, prefix: 'cast_value');
    return SqlRawExpression<TValue>(
      '${fragment.sql}::${_sqlCastType(postgres)}',
      parameters: fragment.parameters,
    );
  }

  /// Creates a scalar subquery expression from a selected query.
  static SqlRawExpression<TValue> scalarSubquery<TValue>(
    SelectedSelectQueryBuilder<dynamic> query,
  ) {
    final statement = query.toStatement();
    final fragment = _sqlFragment(
      statement.sql,
      parameters: statement.namedParameters ?? const <String, Object?>{},
      prefix: 'subquery',
    );
    return SqlRawExpression<TValue>(
      '(${fragment.sql})',
      parameters: fragment.parameters,
    );
  }

  /// Creates `length(value)`.
  static SqlRawExpression<int> length(Object value) {
    return _sqlFunction<int>('length', [value]);
  }

  /// Creates `char_length(value)`.
  static SqlRawExpression<int> charLength(Object value) {
    return _sqlFunction<int>('char_length', [value]);
  }

  /// Creates `substr(value, start[, length])`.
  static SqlRawExpression<String> substring(
    Object value, {
    required Object start,
    Object? length,
  }) {
    return _sqlFunction<String>(
      'substr',
      length == null ? [value, start] : [value, start, length],
    );
  }

  /// Creates `left + right`.
  static SqlRawExpression<TValue> add<TValue>(Object left, Object right) {
    return _binaryExpression<TValue>(left, '+', right, prefix: 'add');
  }

  /// Creates `left - right`.
  static SqlRawExpression<TValue> subtract<TValue>(Object left, Object right) {
    return _binaryExpression<TValue>(left, '-', right, prefix: 'subtract');
  }

  /// Creates `left * right`.
  static SqlRawExpression<TValue> multiply<TValue>(Object left, Object right) {
    return _binaryExpression<TValue>(left, '*', right, prefix: 'multiply');
  }

  /// Creates `left / right`.
  static SqlRawExpression<TValue> divide<TValue>(Object left, Object right) {
    return _binaryExpression<TValue>(left, '/', right, prefix: 'divide');
  }

  /// Creates `value IS NULL`.
  static SqlRawExpression<bool> isNull(Object value) {
    final fragment = _sqlFragment(value, prefix: 'is_null');
    return SqlRawExpression<bool>(
      '${fragment.sql} IS NULL',
      parameters: fragment.parameters,
    );
  }

  /// Creates `value IS NOT NULL`.
  static SqlRawExpression<bool> isNotNull(Object value) {
    final fragment = _sqlFragment(value, prefix: 'is_not_null');
    return SqlRawExpression<bool>(
      '${fragment.sql} IS NOT NULL',
      parameters: fragment.parameters,
    );
  }

  /// Creates `left = right`.
  static SqlRawExpression<bool> eq(Object left, Object right) {
    return _binaryExpression<bool>(left, '=', right, prefix: 'eq');
  }

  /// Creates `left != right`.
  static SqlRawExpression<bool> notEq(Object left, Object right) {
    return _binaryExpression<bool>(left, '!=', right, prefix: 'not_eq');
  }

  /// Creates `left > right`.
  static SqlRawExpression<bool> gt(Object left, Object right) {
    return _binaryExpression<bool>(left, '>', right, prefix: 'gt');
  }

  /// Creates `left >= right`.
  static SqlRawExpression<bool> gte(Object left, Object right) {
    return _binaryExpression<bool>(left, '>=', right, prefix: 'gte');
  }

  /// Creates `left < right`.
  static SqlRawExpression<bool> lt(Object left, Object right) {
    return _binaryExpression<bool>(left, '<', right, prefix: 'lt');
  }

  /// Creates `left <= right`.
  static SqlRawExpression<bool> lte(Object left, Object right) {
    return _binaryExpression<bool>(left, '<=', right, prefix: 'lte');
  }

  /// Creates `(value AND value ...)`.
  static SqlRawExpression<bool> and(Iterable<Object> values) {
    return _compoundExpression('AND', values, name: 'and');
  }

  /// Creates `(value OR value ...)`.
  static SqlRawExpression<bool> or(Iterable<Object> values) {
    return _compoundExpression('OR', values, name: 'or');
  }

  /// Creates `NOT (value)`.
  static SqlRawExpression<bool> not(Object value) {
    final fragment = _sqlFragment(value, prefix: 'not');
    return SqlRawExpression<bool>(
      'NOT (${fragment.sql})',
      parameters: fragment.parameters,
    );
  }

  /// Creates `count(*)` or `count(value)`.
  static SqlRawExpression<int> count([Object? value]) {
    if (value == null) {
      return const SqlRawExpression<int>('count(*)');
    }
    return _sqlFunction<int>('count', [value]);
  }

  /// Creates `count(DISTINCT value)`.
  static SqlRawExpression<int> countDistinct(Object value) {
    final fragment = _sqlFragment(value, prefix: 'count_distinct');
    return SqlRawExpression<int>(
      'count(DISTINCT ${fragment.sql})',
      parameters: fragment.parameters,
    );
  }

  /// Creates `sum(value)`.
  static SqlRawExpression<TValue> sum<TValue>(Object value) {
    return _sqlFunction<TValue>('sum', [value]);
  }

  /// Creates `min(value)`.
  static SqlRawExpression<TValue> min<TValue>(Object value) {
    return _sqlFunction<TValue>('min', [value]);
  }

  /// Creates `max(value)`.
  static SqlRawExpression<TValue> max<TValue>(Object value) {
    return _sqlFunction<TValue>('max', [value]);
  }

  /// Creates `avg(value)`.
  static SqlRawExpression<TValue> avg<TValue>(Object value) {
    return _sqlFunction<TValue>('avg', [value]);
  }

  /// Creates `lower(value)`.
  static SqlRawExpression<String> lower(Object value) {
    return _sqlFunction<String>('lower', [value]);
  }

  /// Creates `upper(value)`.
  static SqlRawExpression<String> upper(Object value) {
    return _sqlFunction<String>('upper', [value]);
  }

  /// Creates `trim(value)`.
  static SqlRawExpression<String> trim(Object value) {
    return _sqlFunction<String>('trim', [value]);
  }

  /// Creates `concat(value, ...)`.
  static SqlRawExpression<String> concat(Iterable<Object> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) {
      throw ArgumentError.value(
        values,
        'values',
        'concat() requires at least one expression.',
      );
    }
    return _sqlFunction<String>('concat', list);
  }

  /// Creates `to_jsonb(value)`.
  static SqlRawExpression<Object?> toJsonb(Object value) {
    final fragment = _sqlFragment(value);
    return SqlRawExpression<Object?>(
      'to_jsonb(${fragment.sql})',
      parameters: fragment.parameters,
    );
  }

  /// Creates `jsonb_agg(value [ORDER BY ...])`.
  static SqlRawExpression<List<Object?>> jsonbAgg(
    Object value, {
    Iterable<SqlOrderBy> orderBy = const <SqlOrderBy>[],
  }) {
    final valueFragment = _sqlFragment(value, prefix: 'agg_value');
    final orderFragments = [
      for (final (index, order) in orderBy.indexed)
        _sqlOrderByFragment(order, prefix: 'agg_order_$index'),
    ];
    final sql = StringBuffer('jsonb_agg(${valueFragment.sql}');
    if (orderFragments.isNotEmpty) {
      sql.write(' ORDER BY ');
      sql.write(orderFragments.map((fragment) => fragment.sql).join(', '));
    }
    sql.write(')');
    return SqlRawExpression<List<Object?>>(
      sql.toString(),
      parameters: _mergeSqlFragmentParameters([
        valueFragment,
        ...orderFragments,
      ]),
    );
  }

  /// Creates `jsonb_build_object('key', value, ...)`.
  static SqlRawExpression<Map<String, Object?>> jsonbBuildObject(
    Map<String, Object> fields,
  ) {
    final fragments = <_SqlFragment>[];
    final sql = StringBuffer('jsonb_build_object(');
    var first = true;
    for (final (index, entry) in fields.entries.indexed) {
      final valueFragment = _sqlFragment(entry.value, prefix: 'object_$index');
      fragments.add(valueFragment);
      if (!first) {
        sql.write(', ');
      }
      first = false;
      sql.write(_sqlStringLiteral(entry.key));
      sql.write(', ');
      sql.write(valueFragment.sql);
    }
    sql.write(')');
    return SqlRawExpression<Map<String, Object?>>(
      sql.toString(),
      parameters: _mergeSqlFragmentParameters(fragments),
    );
  }

  /// Creates `COALESCE(value, fallback, ...)`.
  static SqlRawExpression<TValue> coalesce<TValue>(Iterable<Object> values) {
    final fragments = [
      for (final (index, value) in values.indexed)
        _sqlFragment(value, prefix: 'coalesce_$index'),
    ];
    if (fragments.isEmpty) {
      throw ArgumentError.value(
        values,
        'values',
        'coalesce() requires at least one expression.',
      );
    }
    return SqlRawExpression<TValue>(
      'COALESCE(${fragments.map((fragment) => fragment.sql).join(', ')})',
      parameters: _mergeSqlFragmentParameters(fragments),
    );
  }

  /// Creates the PostgreSQL `jsonb` empty array literal.
  static SqlRawExpression<List<Object?>> jsonbEmptyArray() {
    return const SqlRawExpression<List<Object?>>("'[]'::jsonb");
  }

  /// Creates `value -> key`.
  static SqlRawExpression<Object?> jsonbExtract(Object value, Object key) {
    return _binaryExpression<Object?>(
      value,
      '->',
      key,
      prefix: 'jsonb_extract',
    );
  }

  /// Creates `value ->> key`.
  static SqlRawExpression<String?> jsonbExtractText(Object value, Object key) {
    return _binaryExpression<String?>(
      value,
      '->>',
      key,
      prefix: 'jsonb_extract_text',
    );
  }

  /// Creates `left @> right`.
  static SqlRawExpression<bool> jsonbContains(Object left, Object right) {
    return _binaryExpression<bool>(left, '@>', right, prefix: 'jsonb_contains');
  }

  /// Creates `jsonb_set(target, path, value[, create_missing])`.
  static SqlRawExpression<Object?> jsonbSet(
    Object target, {
    required Object path,
    required Object value,
    Object? createMissing,
  }) {
    return _sqlFunction<Object?>(
      'jsonb_set',
      createMissing == null
          ? [target, path, value]
          : [target, path, value, createMissing],
    );
  }

  /// Creates `jsonb_array_length(value)`.
  static SqlRawExpression<int> jsonbArrayLength(Object value) {
    return _sqlFunction<int>('jsonb_array_length', [value]);
  }

  /// Creates `now()`.
  static SqlRawExpression<DateTime> now() {
    return const SqlRawExpression<DateTime>('now()');
  }

  /// Creates `date_trunc(precision, value)`.
  static SqlRawExpression<DateTime> dateTrunc(Object precision, Object value) {
    return _sqlFunction<DateTime>('date_trunc', [precision, value]);
  }

  /// Creates `extract(field FROM value)`.
  static SqlRawExpression<num> extract(String field, Object value) {
    if (!_isSqlIdentifier(field)) {
      throw ArgumentError.value(
        field,
        'field',
        'extract() field must be a SQL identifier.',
      );
    }
    final fragment = _sqlFragment(value, prefix: 'extract_value');
    return SqlRawExpression<num>(
      'extract($field FROM ${fragment.sql})',
      parameters: fragment.parameters,
    );
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

/// PostgreSQL row-locking strength for `SELECT ... FOR ...` clauses.
enum SqlRowLockStrength {
  /// `FOR UPDATE`.
  update,

  /// `FOR NO KEY UPDATE`.
  noKeyUpdate,

  /// `FOR SHARE`.
  share,

  /// `FOR KEY SHARE`.
  keyShare,
}

/// Wait behavior for PostgreSQL row-locking clauses.
enum SqlLockWaitPolicy {
  /// Wait for locked rows normally.
  wait,

  /// Fail immediately when a selected row is already locked.
  noWait,

  /// Skip rows that are already locked.
  skipLocked,
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
