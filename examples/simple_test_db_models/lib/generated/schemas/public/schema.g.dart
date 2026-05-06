import 'package:dart_edge_core/dart_edge_core.dart';
import 'tables/notes.g.dart';
import 'tables/people.g.dart';
export 'tables/notes.g.dart';
export 'tables/people.g.dart';

final class PublicSchema {
  const PublicSchema._();

  static const instance = PublicSchema._();

  static const schemaName = 'public';

  static const notes = NotesTable.table;

  static const people = PeopleTable.table;

  static const List<JsonSchema> schemas = <JsonSchema>[
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
