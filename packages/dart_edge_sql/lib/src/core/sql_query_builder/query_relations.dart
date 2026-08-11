part of '../sql_query_builder.dart';

/// Describes one typed output column of a CTE or derived table.
final class SqlQueryColumn<TValue> {
  const SqlQueryColumn(this.name, {this.nullable = false, this.databaseType});

  /// Creates an output column with metadata copied from [column].
  factory SqlQueryColumn.from(SqlColumn<TValue> column, {String? name}) =>
      SqlQueryColumn<TValue>(
        name ?? column.name,
        nullable: column.nullable,
        databaseType: column.databaseType,
      );

  final String name;
  final bool nullable;
  final String? databaseType;
}

/// PostgreSQL CTE materialization preference.
enum SqlCteMaterialization { defaultBehavior, materialized, notMaterialized }

/// A typed CTE or derived-table relation produced by a selected query.
final class SqlQueryRelation {
  SqlQueryRelation._(this._table, this._columns);

  final _SqlQueryTable _table;
  final Map<String, SqlQueryColumn<dynamic>> _columns;

  /// The relation name or alias.
  String get name => _table.name;

  /// Returns a typed column bound to this relation.
  SqlColumn<TValue> column<TValue>(SqlQueryColumn<TValue> column) {
    if (!identical(_columns[column.name], column)) {
      throw ArgumentError.value(
        column,
        'column',
        'The column is not declared by relation $name.',
      );
    }
    return _table.column<TValue>(
      column.name,
      nullable: column.nullable,
      databaseType: column.databaseType,
    );
  }

  /// Looks up a relation column by name.
  SqlColumn<TValue> columnNamed<TValue>(String name) {
    final definition = _columns[name];
    if (definition == null) {
      throw ArgumentError.value(name, 'name', 'Unknown relation column.');
    }
    return _table.column<TValue>(
      name,
      nullable: definition.nullable,
      databaseType: definition.databaseType,
    );
  }
}

enum _SqlQueryRelationKind { cte, derived }

final class _SqlQueryTable extends SqlTable<SqlRow, Never, Never> {
  _SqlQueryTable({
    required this.name,
    required this.source,
    required this.definitions,
    required this.kind,
    this.materialization = SqlCteMaterialization.defaultBehavior,
  }) {
    columns = definitions
        .map(
          (definition) => SqlColumn<Object?>(
            table: this,
            name: definition.name,
            nullable: definition.nullable,
            databaseType: definition.databaseType,
          ),
        )
        .toList(growable: false);
  }

  @override
  final String name;
  final SelectedSelectQueryBuilder<dynamic> source;
  final List<SqlQueryColumn<dynamic>> definitions;
  final _SqlQueryRelationKind kind;
  final SqlCteMaterialization materialization;

  @override
  String? get schema => null;

  @override
  late final List<SqlColumnBase> columns;

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;

  @override
  Map<String, Object?> encodeInsert(Never value) =>
      throw UnsupportedError('Query relations cannot be insert targets.');

  @override
  Map<String, Object?> encodeUpdate(Never value) =>
      throw UnsupportedError('Query relations cannot be update targets.');
}
