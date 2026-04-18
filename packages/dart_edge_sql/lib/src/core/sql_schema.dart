import 'sql_row.dart';

/// Base class for a typed table descriptor.
///
/// Implementations describe the available columns and how rows, inserts, and
/// updates map between SQL and Dart.
abstract base class SqlTable<TRow, TInsert, TUpdate> {
  const SqlTable();

  /// Table name without schema qualification.
  String get name;

  /// Optional schema name.
  String? get schema;

  /// All columns that belong to the table.
  List<SqlColumn<Object?>> get columns;

  /// Maps one raw [SqlRow] into the typed row model.
  TRow mapRow(SqlRow row, {String prefix = ''});

  /// Encodes an insert payload into SQL column values.
  Map<String, Object?> encodeInsert(TInsert value);

  /// Encodes an update payload into SQL column values.
  Map<String, Object?> encodeUpdate(TUpdate value);

  /// Fully qualified table name, including schema when present.
  String get qualifiedName => switch (schema) {
    final String schemaName => '$schemaName.$name',
    null => name,
  };

  /// Prefix used when aliasing this table in a joined selection.
  String get selectionPrefix => switch (schema) {
    final String schemaName => '${schemaName}_${name}__',
    null => '${name}__',
  };
}

/// Descriptor for one column on a [SqlTable].
final class SqlColumn<TValue> {
  const SqlColumn({
    required this.table,
    required this.name,
    this.nullable = false,
  });

  /// Table that owns the column.
  final SqlTable<dynamic, dynamic, dynamic> table;

  /// Column name without qualification.
  final String name;

  /// Whether the column may contain `NULL`.
  final bool nullable;

  /// Fully qualified column name.
  String get qualifiedName => '${table.qualifiedName}.$name';

  /// Reinterprets this column as `SqlColumn<Object?>`.
  SqlColumn<Object?> get asObjectColumn => this as SqlColumn<Object?>;
}
