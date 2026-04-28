import 'json_schema.dart';

/// Collection of JSON Schemas installed on an app.
final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.schemas});

  /// All top-level schemas known to the registry.
  final List<JsonSchema> schemas;

  /// Looks up a schema by its identifier.
  JsonSchema? schemaFor(String id) {
    for (final schema in schemas) {
      if (schema.id == id) {
        return schema;
      }
    }
    return null;
  }

  /// Returns the schema registry as a map keyed by schema id.
  Map<String, Map<String, Object?>> asMap() =>
      Map<String, Map<String, Object?>>.fromEntries(
        <MapEntry<String, Map<String, Object?>>>[
          for (final schema in schemas)
            if (schema.id case final id?) MapEntry(id, schema.toJson()),
        ],
      );
}
