import '../router/guard.dart';
import '../router/route_options.dart';
import 'error_response.dart';
import 'http_method.dart';
import 'json_schema_ref.dart';
import 'request_body.dart';
import 'response_set.dart';
import 'response_spec.dart';

/// Full HTTP contract for a [JsonRouteDefinition].
final class RouteContract {
  RouteContract({
    required HttpMethod method,
    required String path,
    required RouteOptions options,
    List<Guard<Object?>> guards = const <Guard<Object?>>[],
  }) : this._(
         method: method,
         path: path,
         options: _normalizeOptions(options),
         guards: List<Guard<Object?>>.unmodifiable(guards),
       );

  RouteContract._({
    required this.method,
    required this.path,
    required this.options,
    required this.guards,
  }) : responses = ResponseSet(
         success: options.success!,
         errors: options.errors,
       );

  /// HTTP method accepted by the route.
  final HttpMethod method;

  /// Route path pattern, for example `/users/<id>`.
  final String path;

  /// Shared route metadata.
  final RouteOptions options;

  /// Documented success and error responses.
  final ResponseSet responses;

  /// Route-local guards evaluated before the handler runs.
  final List<Guard<Object?>> guards;

  /// Stable identifier used in generated output and manifests.
  String get operationId => options.operationId!;

  /// Optional short summary for documentation.
  String? get summary => options.summary;

  /// Tags attached to the route in generated documentation.
  List<String> get tags => options.tags;

  /// Whether the route should be marked as deprecated.
  bool get deprecated => options.deprecated;

  /// Schema reference for decoded path parameters.
  JsonSchemaRef<Object?>? get params => options.params;

  /// Schema reference for decoded query parameters.
  JsonSchemaRef<Object?>? get query => options.query;

  /// Schema reference for decoded request headers.
  JsonSchemaRef<Object?>? get headers => options.headers;

  /// Request body contract, if the route accepts a body.
  RequestBody? get body => options.body;

  @override
  String toString() {
    final parts = <String>[
      '${_httpMethodLabel(method)} $path',
      'operationId: $operationId',
      if (body case final body?)
        'body: ${_contentLabel(body.contentType, schemaId: body.ref?.id)}',
      'success: ${responses.success.status} ${_contentLabel(responses.success.contentType, schemaId: responses.success.ref?.id)}',
      if (responses.errors.isNotEmpty)
        'errors: [${responses.errors.map<String>(_errorLabel).join(', ')}]',
      if (guards.isNotEmpty) 'guards: $guards',
      if (tags.isNotEmpty) 'tags: $tags',
      if (this.deprecated) 'deprecated: true',
    ];
    return 'RouteContract(${parts.join(', ')})';
  }
}

RouteOptions _normalizeOptions(RouteOptions options) {
  final operationId = options.operationId;
  if (operationId == null) {
    throw ArgumentError.value(
      options,
      'options',
      'RouteOptions.operationId is required for RouteContract.',
    );
  }

  return RouteOptions(
    operationId: operationId,
    summary: options.summary,
    tags: List<String>.unmodifiable(options.tags),
    deprecated: options.deprecated,
    params: options.params,
    query: options.query,
    headers: options.headers,
    body: options.body,
    success: options.success ?? ResponseSpec.json<Object?>(),
    errors: List<ErrorResponse>.unmodifiable(options.errors),
  );
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
