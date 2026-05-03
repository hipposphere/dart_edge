part of '../sql_query_builder.dart';

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
  Future<List<TRow>> executeReturningAll() async {
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
  Future<TRow?> executeReturningFirstOrNull() async {
    final rows = await executeReturningAll();
    return rows.isEmpty ? null : rows.first;
  }
}

/// Builder for a `DELETE` query.
final class DeleteQueryBuilder<TRow, TInsert, TUpdate> {
  DeleteQueryBuilder._({
    required SqlExecutor executor,
    required SqlTable<TRow, TInsert, TUpdate> table,
    SqlPredicate? where,
  }) : _executor = executor,
       _table = table,
       _where = where;

  final SqlExecutor _executor;
  final SqlTable<TRow, TInsert, TUpdate> _table;
  final SqlPredicate? _where;

  /// Adds [predicate] to the `WHERE` clause with `AND`.
  DeleteQueryBuilder<TRow, TInsert, TUpdate> where(SqlPredicate predicate) =>
      DeleteQueryBuilder._(
        executor: _executor,
        table: _table,
        where: _where == null ? predicate : _where.and(predicate),
      );

  /// Executes the delete.
  Future<SqlResult> execute() => _executor.execute(_compileDelete(this));

  /// Executes the delete and maps the returned rows back into table rows.
  Future<List<TRow>> executeReturningAll() async {
    final statement = _compileDelete(
      this,
      returning: _TableSelection<TRow, TInsert, TUpdate>(_table),
    );
    final result = await _executor.execute(statement);
    return result.rows
        .map((row) => _table.mapRow(row, prefix: _table.selectionPrefix))
        .toList(growable: false);
  }

  /// Executes the delete and returns the first deleted row, if any.
  Future<TRow?> executeReturningFirstOrNull() async {
    final rows = await executeReturningAll();
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

  /// Adds [predicate] to the `WHERE` clause with `AND`.
  UpdateQueryBuilder<TRow, TInsert, TUpdate> where(SqlPredicate predicate) =>
      UpdateQueryBuilder._(
        executor: _executor,
        table: _table,
        values: _values,
        where: _where == null ? predicate : _where.and(predicate),
      );

  /// Executes the update.
  Future<SqlResult> execute() => _executor.execute(_compileUpdate(this));

  /// Executes the update and maps the returned rows back into table rows.
  Future<List<TRow>> executeReturningAll() async {
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
  Future<TRow?> executeReturningFirstOrNull() async {
    final rows = await executeReturningAll();
    return rows.isEmpty ? null : rows.first;
  }
}

SqlStatement _compileSelect(
  _SqlSelectCore query,
  List<_SelectedProjection> projections,
) {
  final compiler = _SqlCompiler(query.executor.dialect);
  compiler.write('SELECT ');
  if (query.distinct) {
    compiler.write('DISTINCT ');
  }
  compiler.writeJoined(
    projections,
    separator: ', ',
    writeElement: compiler.writeProjection,
  );
  compiler.write(' FROM ');
  compiler.writeTable(query.from);
  for (final join in query.joins) {
    compiler.write(' ');
    compiler.write(join.type.keyword);
    compiler.write(' ');
    compiler.writeTable(join.table);
    compiler.write(' ON ');
    compiler.writePredicate(join.on);
  }
  final where = query.where;
  if (where != null) {
    compiler.write(' WHERE ');
    compiler.writePredicate(where);
  }
  if (query.groupBy.isNotEmpty) {
    compiler.write(' GROUP BY ');
    compiler.writeJoined(
      query.groupBy,
      separator: ', ',
      writeElement: compiler.writeSelectable,
    );
  }
  final having = query.having;
  if (having != null) {
    compiler.write(' HAVING ');
    compiler.writePredicate(having);
  }
  if (query.orderBy.isNotEmpty) {
    compiler.write(' ORDER BY ');
    compiler.writeJoined(
      query.orderBy,
      separator: ', ',
      writeElement: (order) {
        if (order.column case final column?) {
          compiler.writeColumn(column);
        } else if (order.expression case final expression?) {
          compiler.writeRaw(expression.sql, expression.parameters);
        }
        compiler.write(order.descending ? ' DESC' : ' ASC');
      },
    );
  }
  if (query.limit case final int limit) {
    compiler.write(' LIMIT $limit');
  }
  if (query.offset case final int offset) {
    compiler.write(' OFFSET $offset');
  }
  return compiler.toStatement();
}

SqlStatement _compileExists(_SqlSelectCore query) {
  final compiler = _SqlCompiler(query.executor.dialect);
  compiler.write('SELECT 1 FROM ');
  compiler.writeTable(query.from);
  for (final join in query.joins) {
    compiler.write(' ');
    compiler.write(join.type.keyword);
    compiler.write(' ');
    compiler.writeTable(join.table);
    compiler.write(' ON ');
    compiler.writePredicate(join.on);
  }
  final where = query.where;
  if (where != null) {
    compiler.write(' WHERE ');
    compiler.writePredicate(where);
  }
  if (query.groupBy.isNotEmpty) {
    compiler.write(' GROUP BY ');
    compiler.writeJoined(
      query.groupBy,
      separator: ', ',
      writeElement: compiler.writeSelectable,
    );
  }
  final having = query.having;
  if (having != null) {
    compiler.write(' HAVING ');
    compiler.writePredicate(having);
  }
  if (query.orderBy.isNotEmpty) {
    compiler.write(' ORDER BY ');
    compiler.writeJoined(
      query.orderBy,
      separator: ', ',
      writeElement: (order) {
        if (order.column case final column?) {
          compiler.writeColumn(column);
        } else if (order.expression case final expression?) {
          compiler.writeRaw(expression.sql, expression.parameters);
        }
        compiler.write(order.descending ? ' DESC' : ' ASC');
      },
    );
  }
  if (query.limit case final int limit) {
    compiler.write(' LIMIT $limit');
  } else {
    compiler.write(' LIMIT 1');
  }
  if (query.offset case final int offset) {
    compiler.write(' OFFSET $offset');
  }
  return compiler.toStatement();
}

SqlStatement _compileCount(_SqlSelectCore query) {
  final compiler = _SqlCompiler(query.executor.dialect);
  compiler.write('SELECT COUNT(*) AS ');
  compiler.writeIdentifier('count');
  compiler.write(' FROM ');
  compiler.writeTable(query.from);
  for (final join in query.joins) {
    compiler.write(' ');
    compiler.write(join.type.keyword);
    compiler.write(' ');
    compiler.writeTable(join.table);
    compiler.write(' ON ');
    compiler.writePredicate(join.on);
  }
  final where = query.where;
  if (where != null) {
    compiler.write(' WHERE ');
    compiler.writePredicate(where);
  }
  if (query.groupBy.isNotEmpty || query.having != null) {
    final inner = _compileSelect(query, [
      const _SelectedProjection(
        expression: SqlRawExpression<int>('1'),
        alias: 'value',
      ),
    ]);
    return SqlStatement.named(
      'SELECT COUNT(*) AS "count" FROM (${inner.sql}) AS "count_source"',
      inner.namedParameters ?? const <String, Object?>{},
    );
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
      writeElement: compiler.writeProjection,
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
      writeElement: compiler.writeProjection,
    );
  }
  return compiler.toStatement();
}

SqlStatement _compileDelete(
  DeleteQueryBuilder<dynamic, dynamic, dynamic> query, {
  _SqlSelection<dynamic>? returning,
}) {
  final compiler = _SqlCompiler(query._executor.dialect);
  compiler.write('DELETE FROM ');
  compiler.writeTable(query._table);
  if (query._where case final SqlPredicate where) {
    compiler.write(' WHERE ');
    compiler.writePredicate(where);
  }
  if (returning != null) {
    compiler.write(' RETURNING ');
    compiler.writeJoined(
      returning.projections,
      separator: ', ',
      writeElement: compiler.writeProjection,
    );
  }
  return compiler.toStatement();
}
