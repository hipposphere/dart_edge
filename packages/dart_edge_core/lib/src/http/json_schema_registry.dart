import 'json_schema_definition.dart';

/// Collection of JSON Schema definitions installed on an app.
final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.definitions});

  /// All schema definitions known to the registry.
  final List<JsonSchemaDefinition> definitions;

  /// Looks up a schema definition by its identifier.
  JsonSchemaDefinition? definitionFor(String id) {
    for (final definition in definitions) {
      if (definition.id == id) {
        return definition;
      }
    }
    return null;
  }

  /// Returns the schema registry as a map keyed by schema id.
  Map<String, Map<String, Object?>> asMap() =>
      Map<String, Map<String, Object?>>.fromEntries(
        definitions.map(
          (definition) => MapEntry(definition.id, definition.schema),
        ),
      );
}
