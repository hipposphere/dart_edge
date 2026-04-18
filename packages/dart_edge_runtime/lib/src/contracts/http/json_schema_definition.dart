import 'json_schema_ref.dart';

/// Binds a [JsonSchemaRef] to its concrete JSON Schema object.
final class JsonSchemaDefinition {
  const JsonSchemaDefinition({required this.ref, required this.schema});

  /// Stable schema reference used by route contracts.
  final JsonSchemaRef<Object?> ref;

  /// Raw JSON Schema object.
  final Map<String, Object?> schema;

  /// Convenience alias for `ref.id`.
  String get id => ref.id;
}
