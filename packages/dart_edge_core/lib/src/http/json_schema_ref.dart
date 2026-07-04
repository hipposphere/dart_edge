/// Typed Dart-side reference to a JSON Schema definition.
///
/// This is a lightweight handle used where a Dart API wants to carry both a
/// schema identifier and the Dart type associated with that schema. Use
/// `JsonSchema.ref` or `JsonSchema.componentRef` when constructing a serialized
/// JSON Schema `$ref`.
final class JsonSchemaRef<T> {
  /// Creates a reference to the schema identified by [id].
  const JsonSchemaRef(this.id);

  /// Referenced schema identifier.
  final String id;

  /// Creates a schema ref using `T.toString()` as the identifier.
  static JsonSchemaRef<T> of<T>() => JsonSchemaRef<T>(T.toString());
}
