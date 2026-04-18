import 'json_schema_ref.dart';

/// Declares the default response encoding for a successful route result.
final class ResponseSpec {
  const ResponseSpec._({
    required this.status,
    required this.contentType,
    this.ref,
  });

  /// HTTP status code emitted for the response.
  final int status;

  /// Response content type.
  final String contentType;

  /// Optional schema reference used for documentation or validation.
  final JsonSchemaRef<Object?>? ref;

  /// Creates a JSON response specification.
  static ResponseSpec json<T>({int status = 200, JsonSchemaRef<T>? ref}) {
    return ResponseSpec._(
      status: status,
      contentType: 'application/json; charset=utf-8',
      ref: ref,
    );
  }

  /// Creates a plain-text response specification.
  static ResponseSpec text({int status = 200}) {
    return ResponseSpec._(
      status: status,
      contentType: 'text/plain; charset=utf-8',
    );
  }

  /// Creates an HTML response specification.
  static ResponseSpec html({int status = 200}) {
    return ResponseSpec._(
      status: status,
      contentType: 'text/html; charset=utf-8',
    );
  }
}
