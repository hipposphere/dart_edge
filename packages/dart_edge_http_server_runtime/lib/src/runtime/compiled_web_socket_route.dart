import 'package:dart_edge_core/dart_edge_core.dart';

import 'compiled_route.dart';

final class CompiledWebSocketRoute<TServices> {
  const CompiledWebSocketRoute({
    required this.routeId,
    required this.route,
    required this.guards,
    required this.contract,
    required this.path,
    required this.patternSegments,
  });

  final String routeId;
  final WebSocketRouteDefinition<TServices> route;
  final List<Guard<TServices>> guards;
  final WebSocketContract contract;
  final String path;
  final List<RouteSegment> patternSegments;

  static CompiledWebSocketRoute<TServices>? tryParse<TServices>(
    RouteRegistration<TServices> registration,
    String routeId,
  ) {
    final route = registration.route;
    if (route is! WebSocketRouteDefinition<TServices>) {
      return null;
    }

    final contract = route.contract;
    final path = joinRoutePath(registration.prefix, contract.path);
    return CompiledWebSocketRoute<TServices>(
      routeId: routeId,
      route: route,
      guards: registration.guards,
      contract: _effectiveContract(registration, contract, path),
      path: path,
      patternSegments: _parsePattern(path),
    );
  }

  Map<String, Object?> toNativeJson() => {
    'kind': 'webSocket',
    'routeId': routeId,
    'method': 'GET',
    'path': path,
    'operationId': contract.operationId,
    'pathSegments': patternSegments.map((segment) => segment.toJson()).toList(),
    'paramsSchemaId': null,
    'querySchemaId': null,
    'headersSchemaId': null,
    'requestBody': null,
  };
}

WebSocketContract _effectiveContract<TServices>(
  RouteRegistration<TServices> registration,
  WebSocketContract contract,
  String path,
) {
  return WebSocketContract(
    path: path,
    operationId: contract.operationId,
    summary: contract.summary,
    tags: _mergeTags(registration.tags, contract.tags),
    deprecated: contract.deprecated,
  );
}

List<RouteSegment> _parsePattern(String path) {
  if (path == '/') {
    return const <RouteSegment>[];
  }

  return path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map((segment) {
        final parameterName = _parameterName(segment);
        if (parameterName != null) {
          return RouteSegment.parameter(parameterName);
        }
        return RouteSegment.literal(segment);
      })
      .toList(growable: false);
}

String? _parameterName(String segment) {
  if (segment.startsWith('<') && segment.endsWith('>')) {
    return segment.substring(1, segment.length - 1);
  }
  if (segment.startsWith(':') && segment.length > 1) {
    return segment.substring(1);
  }
  return null;
}

List<String> _mergeTags(Iterable<String> first, Iterable<String> second) {
  final merged = <String>[];
  final seen = <String>{};
  for (final tag in [...first, ...second]) {
    if (seen.add(tag)) {
      merged.add(tag);
    }
  }
  return List<String>.unmodifiable(merged);
}
