import 'package:dart_edge_core/dart_edge_core.dart';
import 'tables/notes.g.dart';
import 'tables/people.g.dart';
export 'tables/notes.g.dart';
export 'tables/people.g.dart';

final class PublicSchema {
  const PublicSchema._();

  static const instance = PublicSchema._();

  static const schemaName = 'public';

  static const notes = PublicNotesTable.table;

  static const people = PublicPeopleTable.table;

  static const List<JsonSchema> schemas = <JsonSchema>[
    PublicNotesRow.jsonSchema,
    PublicNotesInsert.jsonSchema,
    PublicNotesUpdate.jsonSchema,
    PublicPeopleRow.jsonSchema,
    PublicPeopleInsert.jsonSchema,
    PublicPeopleUpdate.jsonSchema,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}
