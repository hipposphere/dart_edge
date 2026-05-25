import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';

const _sharedAdapterPath = 'rust/src/shared_sql_adapter.rs';

Future<void> main() async {
  final packageRoot = File.fromUri(Platform.script).parent.parent;
  final schema = File(
    '${packageRoot.path}/$_sharedAdapterPath',
  ).readAsStringSync();
  final database = await _introspectBetterAuthPostgresSchema(
    _extractPostgresSchema(schema),
  );

  final emission = emitDartSchema(
    database,
    databaseClassName: 'DartEdgeAuthTables',
    naming: DartSchemaNaming(modelNameBuilder: _authModelName),
    primaryKeyExtensionTypes: false,
  );
  emission.writeToDirectory('${packageRoot.path}/lib/src/generated');
}

Future<IntrospectedDatabase> _introspectBetterAuthPostgresSchema(
  String schema,
) async {
  final database = PgliteDatabase.temporary().asPostgresPool();
  try {
    for (final statement in _splitSqlStatements(schema)) {
      await database.execute(sql(statement));
    }
    final introspected = await PostgresIntrospector.fromDatabase(
      database,
      includeTables: const {'user', 'session'},
    ).introspect();
    return _withoutDefaultSchema(introspected);
  } finally {
    await database.close();
  }
}

Iterable<String> _splitSqlStatements(String schema) sync* {
  for (final statement in schema.split(';')) {
    final trimmed = statement.trim();
    if (trimmed.isNotEmpty) {
      yield '$trimmed;';
    }
  }
}

IntrospectedDatabase _withoutDefaultSchema(IntrospectedDatabase database) {
  return IntrospectedDatabase(
    dialect: database.dialect,
    tables: [
      for (final table in database.tables)
        IntrospectedTable(
          name: table.name,
          columns: table.columns,
          constraints: table.constraints,
        ),
    ],
    enums: database.enums,
    routines: database.routines,
  );
}

String _extractPostgresSchema(String source) {
  const marker = 'const POSTGRES_SCHEMA_SQL: &str = r#"';
  final start = source.indexOf(marker);
  if (start < 0) {
    throw StateError(
      'Could not find POSTGRES_SCHEMA_SQL in $_sharedAdapterPath.',
    );
  }
  final bodyStart = start + marker.length;
  final end = source.indexOf('"#;', bodyStart);
  if (end < 0) {
    throw StateError(
      'Could not parse POSTGRES_SCHEMA_SQL in $_sharedAdapterPath.',
    );
  }
  return source.substring(bodyStart, end);
}

String _authModelName(DartSchemaModelNameContext context) {
  final tablePrefix = switch (context.tableName) {
    'user' => 'DartEdgeAuthUser',
    'session' => 'DartEdgeAuthSession',
    final table => throw StateError('Unsupported Better Auth table "$table".'),
  };
  return switch (context.kind) {
    DartSchemaModelKind.row => '${tablePrefix}Row',
    DartSchemaModelKind.insert => '${tablePrefix}Insert',
    DartSchemaModelKind.update => '${tablePrefix}Update',
    DartSchemaModelKind.table => '${tablePrefix}sTable',
  };
}
