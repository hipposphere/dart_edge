import 'package:dart_edge_sql/dart_edge_sql.dart';

import '../codegen/sql_codegen_config.dart';
import 'introspected_database.dart';
import 'sql_database_introspector.dart';

/// PostgreSQL schema introspector.
final class PostgresIntrospector implements SqlDatabaseIntrospector {
  PostgresIntrospector({
    required this.connectionString,
    this.schema = 'public',
    Set<String> includeTables = const <String>{},
    Set<String> excludeTables = const <String>{},
  }) : _database = null,
       includeTables = Set<String>.unmodifiable(includeTables),
       excludeTables = Set<String>.unmodifiable(excludeTables);

  /// Introspects an already-open `dart_edge_sql` PostgreSQL database.
  PostgresIntrospector.fromDatabase(
    PostgresPool database, {
    this.schema = 'public',
    Set<String> includeTables = const <String>{},
    Set<String> excludeTables = const <String>{},
  }) : connectionString = database.connectionString,
       _database = database,
       includeTables = Set<String>.unmodifiable(includeTables),
       excludeTables = Set<String>.unmodifiable(excludeTables);

  /// PostgreSQL connection string used to open the schema-inspection pool.
  final String connectionString;

  final PostgresPool? _database;

  /// Schema name to introspect.
  final String schema;

  /// Optional allow-list of tables to include.
  final Set<String> includeTables;

  /// Optional block-list of tables to exclude.
  final Set<String> excludeTables;

  @override
  Future<IntrospectedDatabase> introspect() async {
    final (database, ownsDatabase) = switch (_database) {
      final database? => (database, false),
      null => (PostgresPool.withUrl(connectionString), true),
    };

    try {
      final result = await database.execute(
        sql(_columnsQuery, parameters: {'schema': schema}),
      );

      final columnsByTable =
          <({String schema, String table}), List<IntrospectedColumn>>{};
      for (final row in result.rows) {
        final tableName = row.read<String>('table_name');
        if (!_shouldIncludeTable(tableName)) {
          continue;
        }

        final tableSchema = row.read<String>('table_schema');
        final key = (schema: tableSchema, table: tableName);
        final columns = columnsByTable.putIfAbsent(
          key,
          () => <IntrospectedColumn>[],
        );
        final databaseType = row.read<String>('database_type');
        columns.add(
          IntrospectedColumn(
            name: row.read<String>('column_name'),
            databaseType: databaseType,
            dartType: _mapPostgresType(databaseType),
            nullable: row.read<bool>('is_nullable'),
            hasDefault: row.read<bool>('has_default'),
            primaryKey: row.read<bool>('is_primary_key'),
          ),
        );
      }

      final tables =
          columnsByTable.entries
              .map(
                (entry) => IntrospectedTable(
                  name: entry.key.table,
                  schema: entry.key.schema,
                  columns: List<IntrospectedColumn>.unmodifiable(entry.value),
                ),
              )
              .toList(growable: false)
            ..sort((left, right) {
              final schemaCompare = (left.schema ?? '').compareTo(
                right.schema ?? '',
              );
              if (schemaCompare != 0) {
                return schemaCompare;
              }
              return left.name.compareTo(right.name);
            });

      return IntrospectedDatabase(
        dialect: SqlCodegenDialect.postgres,
        tables: tables,
      );
    } finally {
      if (ownsDatabase) {
        await database.close();
      }
    }
  }

  bool _shouldIncludeTable(String tableName) {
    if (excludeTables.contains(tableName)) {
      return false;
    }
    if (includeTables.isEmpty) {
      return true;
    }
    return includeTables.contains(tableName);
  }
}

const String _columnsQuery = '''
SELECT
  columns.table_schema AS table_schema,
  columns.table_name AS table_name,
  columns.column_name AS column_name,
  columns.udt_name AS database_type,
  columns.is_nullable = 'YES' AS is_nullable,
  columns.column_default IS NOT NULL AS has_default,
  COALESCE(constraints.constraint_type = 'PRIMARY KEY', FALSE) AS is_primary_key
FROM information_schema.columns AS columns
JOIN information_schema.tables AS tables
  ON tables.table_schema = columns.table_schema
 AND tables.table_name = columns.table_name
LEFT JOIN information_schema.key_column_usage AS key_usage
  ON key_usage.table_schema = columns.table_schema
 AND key_usage.table_name = columns.table_name
 AND key_usage.column_name = columns.column_name
LEFT JOIN information_schema.table_constraints AS constraints
  ON constraints.table_schema = key_usage.table_schema
 AND constraints.table_name = key_usage.table_name
 AND constraints.constraint_name = key_usage.constraint_name
 AND constraints.constraint_type = 'PRIMARY KEY'
WHERE tables.table_type = 'BASE TABLE'
  AND columns.table_schema = @schema
ORDER BY columns.table_name, columns.ordinal_position
''';

String _mapPostgresType(String databaseType) {
  final normalized = databaseType.toLowerCase();
  return switch (normalized) {
    'int2' || 'int4' || 'int8' || 'serial' || 'bigserial' => 'int',
    'float4' || 'float8' => 'double',
    'numeric' || 'decimal' || 'money' => 'num',
    'bool' => 'bool',
    'date' || 'timestamp' || 'timestamptz' => 'DateTime',
    'time' || 'timetz' => 'String',
    'text' || 'varchar' || 'bpchar' || 'citext' || 'uuid' => 'String',
    'json' || 'jsonb' => 'Object?',
    'bytea' => 'List<int>',
    _ when normalized.startsWith('_') => 'List<Object?>',
    _ => 'Object?',
  };
}
