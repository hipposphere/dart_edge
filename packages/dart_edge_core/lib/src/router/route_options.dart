import '../http/error_response.dart';
import '../http/json_schema.dart';
import '../http/request_body.dart';
import '../http/response_set.dart';
import '../http/response_spec.dart';

/// Convenience options for inline `Router.get`/`post`/`put` style handlers.
final class RouteOptions {
  const RouteOptions({
    this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
    this.params,
    this.query,
    this.headers,
    this.body,
    this.success,
    this.errors = const <ErrorResponse>[],
  });

  /// Optional stable identifier used in generated output and manifests.
  final String? operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;

  /// Schema for decoded path parameters.
  final JsonSchema? params;

  /// Schema for decoded query parameters.
  final JsonSchema? query;

  /// Schema for decoded request headers.
  final JsonSchema? headers;

  /// Request body contract, if the route accepts a body.
  final RequestBody? body;

  /// Documented success response.
  final ResponseSpec? success;

  /// Documented non-success responses.
  final List<ErrorResponse> errors;

  /// Documented success and non-success responses.
  ResponseSet get responses => ResponseSet(success: success!, errors: errors);

  /// Returns a normalized options object suitable for runtime execution.
  RouteOptions normalized({String? defaultOperationId}) {
    final resolvedOperationId = operationId ?? defaultOperationId;
    if (resolvedOperationId == null) {
      throw ArgumentError.value(
        this,
        'options',
        'RouteOptions.operationId is required for HTTP routes.',
      );
    }

    return RouteOptions(
      operationId: resolvedOperationId,
      summary: summary,
      tags: List<String>.unmodifiable(tags),
      deprecated: deprecated,
      params: params,
      query: query,
      headers: headers,
      body: body,
      success: success ?? ResponseSpec.json(),
      errors: List<ErrorResponse>.unmodifiable(errors),
    );
  }

  @override
  String toString() {
    final normalizedOptions = normalized();
    final responses = normalizedOptions.responses;
    final body = normalizedOptions.body;
    final parts = <String>[
      'operationId: ${normalizedOptions.operationId!}',
      if (body case final body?)
        'body: ${_contentLabel(body.contentType, schema: body.schema)}',
      'success: ${responses.success.status} ${_contentLabel(responses.success.contentType, schema: responses.success.schema)}',
      if (responses.errors.isNotEmpty)
        'errors: [${responses.errors.map<String>(_errorLabel).join(', ')}]',
      if (normalizedOptions.tags.isNotEmpty) 'tags: ${normalizedOptions.tags}',
      if (normalizedOptions.deprecated) 'deprecated: true',
    ];
    return 'RouteOptions(${parts.join(', ')})';
  }
}

String _contentLabel(String contentType, {required JsonSchema? schema}) {
  if (_jsonSchemaRouteId(schema) case final schemaId?) {
    return '$contentType<$schemaId>';
  }
  return contentType;
}

String? _jsonSchemaRouteId(JsonSchema? schema) {
  return switch (schema) {
    null => null,
    JsonReferenceSchema(:final ref) => _schemaIdFromReference(ref),
    _ => schema.id,
  };
}

String? _schemaIdFromReference(String ref) {
  const componentPrefix = '#/components/schemas/';
  if (ref.startsWith(componentPrefix)) {
    return ref.substring(componentPrefix.length);
  }
  if (ref.startsWith('#/') || ref.contains('://')) {
    return null;
  }
  return ref;
}

String _errorLabel(ErrorResponse error) {
  if (error.code case final code?) {
    return '${error.status} $code';
  }
  return '${error.status}';
}
