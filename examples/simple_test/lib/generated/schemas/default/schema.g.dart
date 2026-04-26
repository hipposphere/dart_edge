import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'tables/dart_edge_schema_migrations.g.dart';
import 'tables/notes.g.dart';
import 'tables/people.g.dart';
export 'tables/dart_edge_schema_migrations.g.dart';
export 'tables/notes.g.dart';
export 'tables/people.g.dart';

final class DefaultSchema {
  const DefaultSchema._();

  static const instance = DefaultSchema._();

  static const schemaName = 'default';

  static const dartEdgeSchemaMigrations = DartEdgeSchemaMigrationsTable.table;

  static const notes = NotesTable.table;

  static const people = PeopleTable.table;

  static const List<JsonSchema> schemas = <JsonSchema>[
    DartEdgeSchemaMigrationsRow.jsonSchema,
    DartEdgeSchemaMigrationsInsert.jsonSchema,
    DartEdgeSchemaMigrationsUpdate.jsonSchema,
    NotesRow.jsonSchema,
    NotesInsert.jsonSchema,
    NotesUpdate.jsonSchema,
    PeopleRow.jsonSchema,
    PeopleInsert.jsonSchema,
    PeopleUpdate.jsonSchema,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}
