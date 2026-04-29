import 'json_schema.dart';

/// Decodes a parsed request body payload into an application type.
typedef RequestBodyDecoder = Object? Function(Object? value);

/// Declares the request body expected by a [RouteOptions].
final class RequestBody {
  const RequestBody._({required this.contentType, this.schema, this.decoder});

  /// Expected request content type.
  final String contentType;

  /// Optional schema used to validate or document the body.
  final JsonSchema? schema;

  /// Optional route-local decoder used after the transport parses the body.
  final RequestBodyDecoder? decoder;

  /// Declares a JSON request body backed by [schema].
  const RequestBody.json({JsonSchema? schema, RequestBodyDecoder? decoder})
    : this._(
        contentType: 'application/json; charset=utf-8',
        schema: schema,
        decoder: decoder,
      );

  /// Declares an untyped JSON request body.
  const RequestBody.jsonValue()
    : this._(
        contentType: 'application/json; charset=utf-8',
        schema: null,
        decoder: null,
      );

  /// Declares a plain-text request body.
  const RequestBody.text()
    : this._(
        contentType: 'text/plain; charset=utf-8',
        schema: null,
        decoder: null,
      );

  /// Declares a multipart form-data request body.
  const RequestBody.multipartFormData()
    : this._(contentType: 'multipart/form-data', schema: null, decoder: null);
}
