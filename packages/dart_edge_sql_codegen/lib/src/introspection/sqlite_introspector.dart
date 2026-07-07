import 'package:dart_edge_sql/dart_edge_sql.dart';

import '../codegen/sql_codegen_config.dart';
import 'introspected_database.dart';
import 'sql_database_introspector.dart';

/// SQLite schema introspector.
final class SqliteIntrospector implements SqlDatabaseIntrospector {
  SqliteIntrospector({
    required this.path,
    Set<String> includeTables = const <String>{},
    Set<String> excludeTables = const <String>{},
  }) : _database = null,
       includeTables = Set<String>.unmodifiable(includeTables),
       excludeTables = Set<String>.unmodifiable(excludeTables);

  /// Introspects an already-open `dart_edge_sql` SQLite database.
  SqliteIntrospector.fromDatabase(
    SqliteDatabase database, {
    Set<String> includeTables = const <String>{},
    Set<String> excludeTables = const <String>{},
  }) : path = database.path,
       _database = database,
       includeTables = Set<String>.unmodifiable(includeTables),
       excludeTables = Set<String>.unmodifiable(excludeTables);

  /// SQLite database file path.
  final String path;

  final SqliteDatabase? _database;

  /// Optional allow-list of tables to include.
  final Set<String> includeTables;

  /// Optional block-list of tables to exclude.
  final Set<String> excludeTables;

  @override
  Future<IntrospectedDatabase> introspect() async {
    final (database, ownsDatabase) = switch (_database) {
      final database? => (database, false),
      null => (SqliteDatabase.open(path), true),
    };

    try {
      final raw = database.raw;
      final tableRows = await _tablesQuery(raw).execute();

      final tables = <IntrospectedTable>[];
      for (final row in tableRows) {
        final tableName = row.read<String>('table_name');
        if (!_shouldIncludeTable(tableName)) {
          continue;
        }

        final pragmaRows = await _columnsQuery(raw, tableName).execute();
        final columns = pragmaRows
            .map(
              (pragmaRow) => IntrospectedColumn(
                name: pragmaRow.read<String>('column_name'),
                databaseType:
                    pragmaRow.readNullable<String>('database_type') ?? '',
                dartType: _mapSqliteType(
                  pragmaRow.readNullable<String>('database_type') ?? '',
                ),
                nullable: pragmaRow.read<int>('is_not_null') == 0,
                hasDefault: pragmaRow.read<int>('has_default') != 0,
                primaryKey: pragmaRow.read<int>('is_primary_key') > 0,
              ),
            )
            .toList(growable: false);

        tables.add(IntrospectedTable(name: tableName, columns: columns));
      }

      return IntrospectedDatabase(
        dialect: SqlCodegenDialect.sqlite,
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

SelectedSelectQueryBuilder<SqlRow> _tablesQuery(SqlRawQueryRoot raw) {
  return raw
      .from('sqlite_master')
      .select(const ['CAST(name AS TEXT) AS table_name'])
      .where(raw.eq('type', 'table'))
      .where(.raw("name NOT LIKE 'sqlite_%'"))
      .orderByExpression(const SqlRawExpression<dynamic>('name'));
}

SelectedSelectQueryBuilder<SqlRow> _columnsQuery(
  SqlRawQueryRoot raw,
  String tableName,
) {
  return raw
      .from('pragma_table_info(${_quoteString(tableName)})')
      .select(const [
        'CAST("name" AS TEXT) AS column_name',
        'CAST("type" AS TEXT) AS database_type',
        'CAST("notnull" AS INTEGER) AS is_not_null',
        'CAST(dflt_value IS NOT NULL AS INTEGER) AS has_default',
        'CAST("pk" AS INTEGER) AS is_primary_key',
      ])
      .orderByExpression(const SqlRawExpression<dynamic>('cid'));
}

String _quoteString(String value) {
  final escaped = value.replaceAll("'", "''");
  return "'$escaped'";
}

String _mapSqliteType(String databaseType) {
  final normalized = databaseType.toUpperCase();
  if (normalized.isEmpty) {
    return 'Object?';
  }
  if (normalized.contains('BOOL')) {
    return 'bool';
  }
  if (normalized.contains('INT')) {
    return 'int';
  }
  if (normalized.contains('CHAR') ||
      normalized.contains('CLOB') ||
      normalized.contains('TEXT')) {
    return 'String';
  }
  if (normalized.contains('REAL') ||
      normalized.contains('FLOA') ||
      normalized.contains('DOUB')) {
    return 'double';
  }
  if (normalized.contains('NUMERIC') || normalized.contains('DECIMAL')) {
    return 'SqlDecimal';
  }
  if (normalized.contains('DATE') || normalized.contains('TIME')) {
    return 'DateTime';
  }
  if (normalized.contains('BLOB')) {
    return 'List<int>';
  }
  return 'Object?';
}
