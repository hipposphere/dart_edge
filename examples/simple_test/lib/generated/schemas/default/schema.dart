import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'tables/dart_edge_schema_migrations.dart';
import 'tables/notes.dart';
import 'tables/people.dart';

final class DefaultSchema {
  const DefaultSchema._();

  static const instance = DefaultSchema._();
  static const schemaName = 'default';

  static const dartEdgeSchemaMigrations = DartEdgeSchemaMigrationsTable.table;
  static const notes = NotesTable.table;
  static const people = PeopleTable.table;

  static const schemas = <JsonSchema>[
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

  static const jsonSchemas = JsonSchemaRegistry(schemas: schemas);
}
