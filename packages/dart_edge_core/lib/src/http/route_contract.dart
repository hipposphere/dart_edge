import 'error_response.dart';
import 'http_method.dart';
import 'json_schema_ref.dart';
import 'request_body.dart';
import 'response_set.dart';

/// Full HTTP contract for a [JsonRouteDefinition].
final class RouteContract {
  const RouteContract({
    required this.method,
    required this.path,
    required this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
    this.params,
    this.query,
    this.headers,
    this.body,
    required this.responses,
  });

  /// HTTP method accepted by the route.
  final HttpMethod method;

  /// Route path pattern, for example `/users/<id>`.
  final String path;

  /// Stable identifier used in generated output and manifests.
  final String operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;

  /// Schema reference for decoded path parameters.
  final JsonSchemaRef<Object?>? params;

  /// Schema reference for decoded query parameters.
  final JsonSchemaRef<Object?>? query;

  /// Schema reference for decoded request headers.
  final JsonSchemaRef<Object?>? headers;

  /// Request body contract, if the route accepts a body.
  final RequestBody? body;

  /// Documented success and error responses.
  final ResponseSet responses;

  @override
  String toString() {
    final parts = <String>[
      '${_httpMethodLabel(method)} $path',
      'operationId: $operationId',
      if (body case final body?)
        'body: ${_contentLabel(body.contentType, schemaId: body.ref?.id)}',
      'success: ${responses.success.status} ${_contentLabel(responses.success.contentType, schemaId: responses.success.ref?.id)}',
      if (responses.errors.isNotEmpty)
        'errors: [${responses.errors.map(_errorLabel).join(', ')}]',
      if (tags.isNotEmpty) 'tags: $tags',
      if (deprecated) 'deprecated: true',
    ];
    return 'RouteContract(${parts.join(', ')})';
  }
}

String _httpMethodLabel(HttpMethod method) => method.name.toUpperCase();

String _contentLabel(String contentType, {required String? schemaId}) {
  if (schemaId case final schemaId?) {
    return '$contentType<$schemaId>';
  }
  return contentType;
}

String _errorLabel(ErrorResponse error) {
  if (error.code case final code?) {
    return '${error.status} $code';
  }
  return '${error.status}';
}
