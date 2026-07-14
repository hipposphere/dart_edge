import 'json_schema.dart';

/// Collection of top-level JSON Schemas installed on an app.
///
/// Generated route and SQL registries use this to expose the schema graph that
/// OpenAPI generation, typed clients, and route metadata can share.
final class JsonSchemaRegistry {
  /// Creates a registry containing [schemas].
  const JsonSchemaRegistry({required this.schemas});

  /// All top-level schemas known to the registry.
  final List<JsonSchema> schemas;

  /// Looks up a schema by its JSON Schema `$id`.
  JsonSchema? schemaFor(String id) {
    for (final schema in schemas) {
      if (schema.id == id) {
        return schema;
      }
    }
    return null;
  }

  /// Returns serialized schemas keyed by schema id.
  ///
  /// Schemas without an [JsonSchema.id] are skipped because they cannot be
  /// addressed from the map.
  Map<String, Map<String, Object?>> asMap() =>
      Map<String, Map<String, Object?>>.fromEntries(
        <MapEntry<String, Map<String, Object?>>>[
          for (final schema in schemas)
            if (schema.id case final id?) MapEntry(id, schema.toJson()),
        ],
      );
}
