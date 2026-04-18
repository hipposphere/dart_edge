/// Stable reference to a JSON Schema definition.
///
/// Route contracts use schema refs instead of embedding full schema objects so
/// generated code can share and reuse schema definitions.
final class JsonSchemaRef<T> {
  const JsonSchemaRef(this.id);

  /// Stable schema identifier.
  final String id;

  /// Creates a schema ref using `T.toString()` as its identifier.
  static JsonSchemaRef<T> of<T>() => JsonSchemaRef<T>(T.toString());
}
