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
  namespaces.nspname AS table_schema,
  table_classes.relname AS table_name,
  attributes.attname AS column_name,
  types.typname AS database_type,
  NOT attributes.attnotnull AS is_nullable,
  attributes.atthasdef AS has_default,
  primary_keys.oid IS NOT NULL AS is_primary_key
FROM pg_catalog.pg_class AS table_classes
JOIN pg_catalog.pg_namespace AS namespaces
  ON namespaces.oid = table_classes.relnamespace
JOIN pg_catalog.pg_attribute AS attributes
  ON attributes.attrelid = table_classes.oid
JOIN pg_catalog.pg_type AS types
  ON types.oid = attributes.atttypid
LEFT JOIN pg_catalog.pg_constraint AS primary_keys
  ON primary_keys.conrelid = table_classes.oid
 AND primary_keys.contype = 'p'
 AND attributes.attnum = ANY(primary_keys.conkey)
WHERE table_classes.relkind IN ('r', 'p')
  AND attributes.attnum > 0
  AND NOT attributes.attisdropped
  AND namespaces.nspname = @schema
ORDER BY table_classes.relname, attributes.attnum
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
