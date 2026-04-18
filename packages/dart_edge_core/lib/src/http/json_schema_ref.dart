/// Stable reference to a JSON Schema definition.
final class JsonSchemaRef<T> {
  const JsonSchemaRef(this.id);

  /// Stable schema identifier.
  final String id;

  /// Creates a schema ref using `T.toString()` as its identifier.
  static JsonSchemaRef<T> of<T>() => JsonSchemaRef<T>(T.toString());
}
