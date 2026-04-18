import '../contracts/http/error_response.dart';
import '../contracts/http/http_method.dart';
import '../contracts/http/json_schema_ref.dart';
import '../contracts/http/request_body.dart';
import '../contracts/http/response_set.dart';
import '../contracts/http/response_spec.dart';
import '../contracts/http/route_contract.dart';

/// Convenience options for inline `Router.get`/`post`/`put` style handlers.
///
/// This keeps the app-facing helper API compact while still compiling down to a
/// normal [RouteContract] for the runtime.
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

  /// Schema reference for decoded path parameters.
  final JsonSchemaRef<Object?>? params;

  /// Schema reference for decoded query parameters.
  final JsonSchemaRef<Object?>? query;

  /// Schema reference for decoded request headers.
  final JsonSchemaRef<Object?>? headers;

  /// Request body contract, if the route accepts a body.
  final RequestBody? body;

  /// Documented success response.
  final ResponseSpec? success;

  /// Documented non-success responses.
  final List<ErrorResponse> errors;

  RouteContract toRouteContract({
    required HttpMethod method,
    required String path,
    required String defaultOperationId,
  }) {
    return RouteContract(
      method: method,
      path: path,
      operationId: operationId ?? defaultOperationId,
      summary: summary,
      tags: List.unmodifiable(tags),
      deprecated: deprecated,
      params: params,
      query: query,
      headers: headers,
      body: body,
      responses: ResponseSet(
        success: success ?? ResponseSpec.json<Object?>(),
        errors: List.unmodifiable(errors),
      ),
    );
  }
}
