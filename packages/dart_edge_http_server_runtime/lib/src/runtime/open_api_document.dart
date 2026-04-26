import 'package:dart_edge_core/dart_edge_core.dart';

import 'compiled_route.dart';

/// Application-level OpenAPI metadata and document generation.
final class OpenApiDocument {
  OpenApiDocument({
    this.title = 'Dart Edge API',
    this.version = '1.0.0',
    this.description,
    List<OpenApiServer> servers = const <OpenApiServer>[],
  }) : servers = List<OpenApiServer>.unmodifiable(servers);

  /// API title shown in generated docs.
  final String title;

  /// API version shown in generated docs.
  final String version;

  /// Optional human-readable description for the API.
  final String? description;

  /// Explicit server list included in the generated document.
  final List<OpenApiServer> servers;

  /// Builds an OpenAPI 3.1 document from compiled routes and schemas.
  Map<String, Object?> toJson({
    required Iterable<CompiledRoute<dynamic>> routes,
    JsonSchemaRegistry? schemaRegistry,
  }) {
    final paths = <String, Map<String, Object?>>{};

    for (final route in routes) {
      final pathItem = paths.putIfAbsent(
        route.openApiPath,
        () => <String, Object?>{},
      );
      pathItem[route.method.name] = _buildOperation(route, schemaRegistry);
    }

    return {
      'openapi': '3.1.0',
      'info': {
        'title': title,
        'version': version,
        if (description case final description?) 'description': description,
      },
      if (servers.isNotEmpty)
        'servers': servers
            .map((server) => server.toJson())
            .toList(growable: false),
      'paths': paths,
      if (schemaRegistry case final registry? when registry.schemas.isNotEmpty)
        'components': {
          'schemas': {
            for (final schema in registry.schemas)
              if (schema.id case final id?)
                id: _openApiSchemaObject(schema.toJson()),
          },
        },
    };
  }
}

/// One OpenAPI server entry.
final class OpenApiServer {
  const OpenApiServer({required this.url, this.description});

  final String url;
  final String? description;

  Map<String, Object?> toJson() => {
    'url': url,
    if (description case final description?) 'description': description,
  };
}

Map<String, Object?> _buildOperation(
  CompiledRoute<dynamic> route,
  JsonSchemaRegistry? schemaRegistry,
) {
  final options = route.options;
  final parameters = <Map<String, Object?>>[
    ..._buildPathParameters(route, schemaRegistry),
    ..._buildObjectParameters(
      options.query?.id,
      'query',
      schemaRegistry,
      requiredByDefault: false,
    ),
    ..._buildObjectParameters(
      options.headers?.id,
      'header',
      schemaRegistry,
      requiredByDefault: false,
    ),
  ];

  return {
    'operationId': options.operationId!,
    if (options.summary case final summary?) 'summary': summary,
    if (options.tags.isNotEmpty) 'tags': options.tags,
    if (options.deprecated) 'deprecated': true,
    if (parameters.isNotEmpty) 'parameters': parameters,
    if (options.body case final body?) 'requestBody': _buildRequestBody(body),
    'responses': _buildResponses(options.responses),
  };
}

List<Map<String, Object?>> _buildPathParameters(
  CompiledRoute<dynamic> route,
  JsonSchemaRegistry? schemaRegistry,
) {
  final pathParameters = [
    for (final segment in route.patternSegments)
      if (segment.isParameter) segment.value,
  ];
  if (pathParameters.isEmpty) {
    return const <Map<String, Object?>>[];
  }

  final properties = _objectSchema(
    route.options.params?.id,
    schemaRegistry,
  )?.properties;
  return [
    for (final name in pathParameters)
      {
        'name': name,
        'in': 'path',
        'required': true,
        'schema': _openApiSchemaObject(
          (properties?[name] ?? const JsonSchema.string()).toJson(),
        ),
      },
  ];
}

List<Map<String, Object?>> _buildObjectParameters(
  String? schemaId,
  String location,
  JsonSchemaRegistry? schemaRegistry, {
  required bool requiredByDefault,
}) {
  if (schemaId == null) {
    return const <Map<String, Object?>>[];
  }

  final schema = _objectSchema(schemaId, schemaRegistry);
  if (schema == null) {
    return const <Map<String, Object?>>[];
  }

  if (schema.properties.isEmpty) {
    return const <Map<String, Object?>>[];
  }

  final requiredFieldNames = schema.required.toSet();
  return [
    for (final entry in schema.properties.entries)
      {
        'name': entry.key,
        'in': location,
        'required': requiredByDefault || requiredFieldNames.contains(entry.key),
        'schema': _openApiSchemaObject(entry.value.toJson()),
      },
  ];
}

Map<String, Object?> _buildRequestBody(RequestBody body) {
  final schema = _contentSchema(body.contentType, refId: body.ref?.id);
  return {
    'required': true,
    'content': {
      _contentTypeEssence(body.contentType): {
        if (schema != null) 'schema': schema,
      },
    },
  };
}

Map<String, Object?> _buildResponses(ResponseSet responses) {
  final builtResponses = <String, Object?>{
    '${responses.success.status}': _buildResponse(
      responses.success,
      description: _statusDescription(responses.success.status),
    ),
  };

  for (final error in responses.errors) {
    builtResponses['${error.status}'] = _buildErrorResponse(error);
  }

  return builtResponses;
}

Map<String, Object?> _buildResponse(
  ResponseSpec spec, {
  required String description,
}) {
  final schema = _contentSchema(spec.contentType, refId: spec.ref?.id);
  return {
    'description': description,
    if (schema != null)
      'content': {
        _contentTypeEssence(spec.contentType): {'schema': schema},
      },
  };
}

Map<String, Object?> _buildErrorResponse(ErrorResponse response) {
  return {
    'description': switch (response.code) {
      final code? => '${_statusDescription(response.status)} ($code)',
      null => _statusDescription(response.status),
    },
  };
}

Map<String, Object?>? _contentSchema(String contentType, {String? refId}) {
  if (refId case final refId?) {
    return <String, Object?>{r'$ref': '#/components/schemas/$refId'};
  }

  return switch (_contentTypeEssence(contentType)) {
    'application/json' => <String, Object?>{},
    'text/plain' || 'text/html' => <String, Object?>{'type': 'string'},
    _ => null,
  };
}

JsonObjectSchema? _objectSchema(
  String? schemaId,
  JsonSchemaRegistry? schemaRegistry,
) {
  final schema = schemaId == null ? null : schemaRegistry?.schemaFor(schemaId);
  return switch (schema) {
    final JsonObjectSchema schema => schema,
    _ => null,
  };
}

Map<String, Object?> _openApiSchemaObject(Object? value) {
  final normalized = _rewriteSchema(value);
  if (normalized is Map<String, Object?>) {
    return normalized;
  }
  if (normalized is Map) {
    return {
      for (final entry in normalized.entries) '${entry.key}': entry.value,
    };
  }
  return const <String, Object?>{};
}

Object? _rewriteSchema(Object? value) {
  switch (value) {
    case List():
      return value.map(_rewriteSchema).toList(growable: false);
    case Map():
      final rewritten = <String, Object?>{};
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (key == r'$id') {
          continue;
        }
        if (key == r'$ref' && entry.value is String) {
          final ref = entry.value as String;
          rewritten[key] = _rewriteRef(ref);
          continue;
        }
        rewritten[key] = _rewriteSchema(entry.value);
      }
      return rewritten;
    default:
      return value;
  }
}

String _rewriteRef(String ref) {
  if (ref.startsWith('#/')) {
    return ref;
  }
  return '#/components/schemas/$ref';
}

String _contentTypeEssence(String contentType) =>
    contentType.split(';').first.trim().toLowerCase();

String _statusDescription(int status) => switch (status) {
  200 => 'OK',
  201 => 'Created',
  202 => 'Accepted',
  204 => 'No Content',
  400 => 'Bad Request',
  401 => 'Unauthorized',
  404 => 'Not Found',
  409 => 'Conflict',
  415 => 'Unsupported Media Type',
  422 => 'Unprocessable Entity',
  500 => 'Internal Server Error',
  _ => 'HTTP $status',
};
