import 'json_schema_ref.dart';

/// Declares the request body expected by a [RouteOptions].
final class RequestBody {
  const RequestBody._({required this.contentType, this.ref});

  /// Expected request content type.
  final String contentType;

  /// Optional schema reference used to validate or document the body.
  final JsonSchemaRef<Object?>? ref;

  /// Declares a JSON request body backed by [ref].
  static RequestBody json<T>({required JsonSchemaRef<T> ref}) {
    return RequestBody._(
      contentType: 'application/json; charset=utf-8',
      ref: ref,
    );
  }

  /// Declares an untyped JSON request body.
  static RequestBody jsonValue() {
    return const RequestBody._(contentType: 'application/json; charset=utf-8');
  }

  /// Declares a plain-text request body.
  static RequestBody text() {
    return const RequestBody._(contentType: 'text/plain; charset=utf-8');
  }

  /// Declares a multipart form-data request body.
  static RequestBody multipartFormData() {
    return const RequestBody._(contentType: 'multipart/form-data');
  }
}
