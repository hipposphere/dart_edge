import 'package:dart_edge_core/dart_edge_core.dart';

import 'compiled_route.dart';

final class CompiledNativeHttpRoute implements CompiledOpenApiRoute {
  const CompiledNativeHttpRoute({
    required this.routeId,
    required this.mount,
    required this.method,
    required this.options,
    required this.path,
    required this.openApiPath,
    required this.patternSegments,
  });

  final String routeId;
  final NativeHttpRouteMount mount;
  @override
  final HttpMethod method;
  @override
  final RouteOptions options;
  final String path;
  @override
  final String openApiPath;
  @override
  final List<RouteSegment> patternSegments;

  static CompiledNativeHttpRoute? tryParse<TServices>(
    RouteRegistration<TServices> registration,
    String routeId,
  ) {
    final mount = registration.route;
    if (mount is! NativeHttpRouteMount) {
      return null;
    }
    final routePath = registration.httpPath;
    final method = registration.httpMethod;
    if (method == null || routePath == null) {
      throw StateError(
        'Native HTTP route ${mount.options.operationId} is missing method/path '
        'registration metadata.',
      );
    }

    final path = joinRoutePath(registration.prefix, routePath);
    final patternSegments = parseRoutePattern(path);
    return CompiledNativeHttpRoute(
      routeId: routeId,
      mount: mount,
      method: method,
      options: effectiveRouteOptions(registration, mount.options.normalized()),
      path: path,
      openApiPath: openApiPathForSegments(patternSegments),
      patternSegments: patternSegments,
    );
  }

  Map<String, Object?> toNativeJson() => {
    'kind': 'nativeHttp',
    'routeId': routeId,
    'method': httpMethodName(method),
    'path': path,
    'operationId': options.operationId!,
    'pathSegments': patternSegments.map((segment) => segment.toJson()).toList(),
    'paramsSchemaId': options.params?.id,
    'querySchemaId': options.query?.id,
    'headersSchemaId': options.headers?.id,
    'requestBody': switch (options.body) {
      null => null,
      final body => {'contentType': body.contentType, 'schemaId': body.ref?.id},
    },
    'nativeHandle': mount.nativeHandle,
    'nativeHandlerAddress': mount.nativeHandlerAddress,
    'nativeFreeResponseAddress': mount.nativeFreeResponseAddress,
  };
}
