import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';
import 'schemas/public/schema.g.dart';
export 'schemas/public/schema.g.dart';

final class AppSchema {
  const AppSchema._();

  static const publicSchema = PublicSchema.instance;

  static const List<SqlKeyManifestEntry> sqlKeyManifest = <SqlKeyManifestEntry>[
    PublicNoteId.manifest,
    PublicPeopleId.manifest,
  ];

  static const List<JsonSchema> schemas = <JsonSchema>[...PublicSchema.schemas];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}
