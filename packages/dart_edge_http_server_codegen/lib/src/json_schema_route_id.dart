import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

/// Returns the generated route schema target only for explicit `$ref`s.
///
/// A schema `$id` identifies an inline schema but does not mean generated
/// clients should treat it as a referenced serializer/codec target.
String? jsonSchemaRouteId(JsonSchema? schema) {
  return switch (schema) {
    null => null,
    JsonReferenceSchema(:final ref) => _schemaIdFromReference(ref),
    _ => null,
  };
}

String? _schemaIdFromReference(String ref) {
  const componentPrefix = '#/components/schemas/';
  if (ref.startsWith(componentPrefix)) {
    return ref.substring(componentPrefix.length);
  }
  if (ref.startsWith('#') || (Uri.tryParse(ref)?.hasScheme ?? false)) {
    return null;
  }
  return ref;
}
