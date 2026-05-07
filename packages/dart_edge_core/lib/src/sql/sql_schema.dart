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
    this.databaseType,
  });

  /// Table that owns the column.
  final SqlTable<dynamic, dynamic, dynamic> table;

  /// Column name without qualification.
  final String name;

  /// Whether the column may contain `NULL`.
  final bool nullable;

  /// Database-native column type name, when known.
  final String? databaseType;

  /// Fully qualified column name.
  String get qualifiedName => '${table.qualifiedName}.$name';

  /// Reinterprets this column as `SqlColumn<Object?>`.
  SqlColumn<Object?> get asObjectColumn => this as SqlColumn<Object?>;
}

/// Lightweight table descriptor for system catalogs and ad hoc query inputs.
final class SqlRawTable
    extends SqlTable<SqlRow, Map<String, Object?>, Map<String, Object?>> {
  const SqlRawTable(this.tableExpression, {this.alias});

  /// Raw SQL table expression, such as `pg_catalog.pg_class`.
  final String tableExpression;

  /// Optional table alias.
  final String? alias;

  @override
  String get name => alias ?? tableExpression;

  @override
  String? get schema => null;

  @override
  List<SqlColumn<Object?>> get columns => const <SqlColumn<Object?>>[];

  /// Creates a column descriptor attached to this raw table expression.
  SqlColumn<TValue> column<TValue>(
    String name, {
    bool nullable = false,
    String? databaseType,
  }) {
    return SqlColumn<TValue>(
      table: this,
      name: name,
      nullable: nullable,
      databaseType: databaseType,
    );
  }

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;

  @override
  Map<String, Object?> encodeInsert(Map<String, Object?> value) => value;

  @override
  Map<String, Object?> encodeUpdate(Map<String, Object?> value) => value;
}
