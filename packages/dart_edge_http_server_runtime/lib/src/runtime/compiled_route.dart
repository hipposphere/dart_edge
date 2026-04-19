import 'package:dart_edge_core/dart_edge_core.dart';

final class CompiledRoute<TServices> {
  const CompiledRoute({
    required this.routeId,
    required this.route,
    required this.guards,
    required this.contract,
    required this.path,
    required this.openApiPath,
    required this.patternSegments,
  });

  final String routeId;
  final JsonRouteDefinition<TServices, dynamic> route;
  final List<Guard<TServices>> guards;
  final RouteContract contract;
  final String path;
  final String openApiPath;
  final List<RouteSegment> patternSegments;

  static CompiledRoute<TServices>? tryParse<TServices>(
    RouteRegistration<TServices> registration,
    String routeId,
  ) {
    final route = registration.route;
    if (route is! JsonRouteDefinition<TServices, dynamic>) {
      return null;
    }

    final contract = route.contract;
    if (contract is! RouteContract) {
      return null;
    }

    final path = joinRoutePath(registration.prefix, contract.path);
    final patternSegments = _parsePattern(path);
    return CompiledRoute<TServices>(
      routeId: routeId,
      route: route,
      guards: registration.guards,
      contract: _effectiveContract(registration, contract, path),
      path: path,
      openApiPath: _openApiPath(patternSegments),
      patternSegments: patternSegments,
    );
  }

  Map<String, Object?> toNativeJson() => {
    'kind': 'http',
    'routeId': routeId,
    'method': _httpMethodName(contract.method),
    'path': path,
    'operationId': contract.options.operationId!,
    'pathSegments': patternSegments.map((segment) => segment.toJson()).toList(),
    'paramsSchemaId': contract.options.params?.id,
    'querySchemaId': contract.options.query?.id,
    'headersSchemaId': contract.options.headers?.id,
    'requestBody': switch (contract.options.body) {
      null => null,
      final body => {'contentType': body.contentType, 'schemaId': body.ref?.id},
    },
  };
}

RouteContract _effectiveContract<TServices>(
  RouteRegistration<TServices> registration,
  RouteContract contract,
  String path,
) {
  return RouteContract(
    method: contract.method,
    path: path,
    options: RouteOptions(
      operationId: contract.options.operationId!,
      summary: contract.options.summary,
      tags: _mergeTags(registration.tags, contract.options.tags),
      deprecated: contract.options.deprecated,
      params: contract.options.params,
      query: contract.options.query,
      headers: contract.options.headers,
      body: contract.options.body,
      success: contract.responses.success,
      errors: contract.responses.errors,
    ),
  );
}

final class RouteSegment {
  const RouteSegment._({required this.value, required this.isParameter});

  final String value;
  final bool isParameter;

  factory RouteSegment.literal(String value) {
    return RouteSegment._(value: value, isParameter: false);
  }

  factory RouteSegment.parameter(String value) {
    return RouteSegment._(value: value, isParameter: true);
  }

  Map<String, Object?> toJson() => {'value': value, 'isParameter': isParameter};
}

String _httpMethodName(HttpMethod method) => switch (method) {
  HttpMethod.get => 'GET',
  HttpMethod.post => 'POST',
  HttpMethod.put => 'PUT',
  HttpMethod.patch => 'PATCH',
  HttpMethod.delete => 'DELETE',
  HttpMethod.head => 'HEAD',
  HttpMethod.options => 'OPTIONS',
};

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

String _openApiPath(List<RouteSegment> segments) {
  if (segments.isEmpty) {
    return '/';
  }

  return '/${segments.map((segment) {
    if (segment.isParameter) {
      return '{${segment.value}}';
    }
    return segment.value;
  }).join('/')}';
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
