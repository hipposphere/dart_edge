/// Marks a handler parameter as a path parameter.
///
/// When [name] is omitted, generators can fall back to the Dart parameter name.
final class PathParam {
  const PathParam([this.name]);

  /// Overrides the parameter name used in the route contract.
  final String? name;
}

/// Marks a handler parameter as a query parameter.
///
/// When [name] is omitted, generators can fall back to the Dart parameter name.
final class QueryParam {
  const QueryParam([this.name]);

  /// Overrides the parameter name used in the route contract.
  final String? name;
}

/// Marks a handler parameter as a request header.
final class HeaderParam {
  const HeaderParam(this.name);

  /// The HTTP header name to read from the incoming request.
  final String name;
}

/// Marks a handler parameter as the decoded request body.
final class RouteBody {
  const RouteBody({this.contentType = 'application/json'});

  /// The expected request content type for the body.
  final String contentType;
}

/// Declares the success response metadata for a generated route.
final class SuccessResponse {
  const SuccessResponse({
    this.status = 200,
    this.contentType = 'application/json',
  });

  /// The HTTP status code emitted on success.
  final int status;

  /// The response content type emitted on success.
  final String contentType;
}

/// Declares one non-success response that a generated route may return.
final class RouteErrorResponse {
  const RouteErrorResponse(
    this.status, {
    this.code,
    this.contentType = 'application/json',
  });

  /// The HTTP status code emitted for this error.
  final int status;

  /// Optional stable application-level error code.
  final String? code;

  /// The response content type emitted for this error.
  final String contentType;
}
