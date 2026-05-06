import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_style/dart_style.dart';

import '../json_schema_route_id.dart';

/// Build-time description of one generated client library.
final class DartEdgeClientLibrarySpec {
  const DartEdgeClientLibrarySpec({
    required this.className,
    required this.operations,
    this.webSockets = const <DartEdgeClientWebSocketOperation>[],
    this.schemas = const <JsonSchema>[],
    this.additionalImports = const <String>[],
  });

  final String className;
  final List<DartEdgeClientOperation> operations;
  final List<DartEdgeClientWebSocketOperation> webSockets;
  final List<JsonSchema> schemas;
  final List<String> additionalImports;

  factory DartEdgeClientLibrarySpec.fromRouter({
    required String className,
    required Router<dynamic> router,
    List<JsonSchema> schemas = const <JsonSchema>[],
    Map<String, String> schemaTypes = const <String, String>{},
    List<String> additionalImports = const <String>[],
    DartEdgeClientGenerationOptions options =
        const DartEdgeClientGenerationOptions(),
  }) {
    final operations = <DartEdgeClientOperation>[];
    final webSockets = <DartEdgeClientWebSocketOperation>[];

    for (final registration in router.routeRegistry.registrations) {
      final path = registration.httpPath;
      if (path == null) {
        continue;
      }

      final fullPath = joinRoutePath(registration.prefix, path);
      if (options.ignoresPath(fullPath)) {
        continue;
      }

      switch (registration.route) {
        case final HttpRouteDefinition<dynamic, dynamic> route:
          final method = registration.httpMethod;
          if (method == null) {
            continue;
          }
          final routeOptions = _effectiveRouteOptions(
            registration,
            route.options.normalized(),
          );
          if (!routeOptions.exposure.client ||
              options.ignoresOperation(routeOptions.operationId!)) {
            continue;
          }
          operations.add(
            _operationFromOptions(
              method: method,
              path: fullPath,
              options: routeOptions,
              schemaTypes: schemaTypes,
            ),
          );
        case final NativeHttpRouteMount route:
          final routeOptions = _effectiveRouteOptions(
            registration,
            route.options.normalized(),
          );
          if (!routeOptions.exposure.client ||
              options.ignoresOperation(routeOptions.operationId!)) {
            continue;
          }
          operations.add(
            _operationFromOptions(
              method: route.method,
              path: fullPath,
              options: routeOptions,
              schemaTypes: schemaTypes,
            ),
          );
        case final WebSocketRouteDefinition<dynamic> route:
          final webSocketOptions = _effectiveWebSocketOptions(
            registration,
            route.options.normalized(),
          );
          if (!webSocketOptions.exposure.client ||
              options.ignoresOperation(webSocketOptions.operationId!)) {
            continue;
          }
          webSockets.add(
            DartEdgeClientWebSocketOperation(
              path: fullPath,
              operationId: webSocketOptions.operationId!,
            ),
          );
      }
    }

    return DartEdgeClientLibrarySpec(
      className: className,
      operations: operations,
      webSockets: webSockets,
      schemas: schemas,
      additionalImports: additionalImports,
    );
  }
}

/// Client-generation filters applied after route exposure metadata.
final class DartEdgeClientGenerationOptions {
  const DartEdgeClientGenerationOptions({
    this.ignorePaths = const <String>{},
    this.ignoreOperations = const <String>{},
  });

  /// Full public route template prefixes to skip after router prefixes are applied.
  ///
  /// A value matches the exact route path and any descendant path. For example,
  /// `/auth/admin` skips `/auth/admin` and `/auth/admin/users`, but not
  /// `/auth/administrator`.
  final Set<String> ignorePaths;

  /// Operation id prefixes to skip.
  final Set<String> ignoreOperations;

  bool ignoresPath(String path) {
    return ignorePaths.any((ignored) => _matchesPathPrefix(path, ignored));
  }

  bool ignoresOperation(String operationId) {
    return ignoreOperations.any(operationId.startsWith);
  }
}

/// Writes generated Dart client files into a directory.
final class DartEdgeClientFileEmitter {
  const DartEdgeClientFileEmitter({
    this.generator = const DartEdgeClientGenerator(),
  });

  final DartEdgeClientGenerator generator;

  Future<void> emit(
    DartEdgeClientLibrarySpec spec, {
    required Directory output,
    String libraryFile = 'client.g.dart',
    String bindingsFile = 'client.bindings.g.dart',
    String modelsFile = 'client.models.g.dart',
  }) async {
    await output.create(recursive: true);
    await File('${output.path}/$libraryFile').writeAsString(
      generator.generateLibrary(
        spec,
        bindingsPart: bindingsFile,
        modelsPart: modelsFile,
      ),
    );
    await File('${output.path}/$bindingsFile').writeAsString(
      generator.generateBindingsPart(spec, libraryFile: libraryFile),
    );
    await File('${output.path}/$modelsFile').writeAsString(
      generator.generateModelsPart(spec, libraryFile: libraryFile),
    );
  }
}

/// Build-time description of one generated client method.
final class DartEdgeClientOperation {
  const DartEdgeClientOperation({
    required this.method,
    required this.path,
    required this.options,
    required this.successType,
    this.methodName,
    this.paramsType,
    this.queryType,
    this.headersType,
    this.bodyType,
  });

  final HttpMethod method;
  final String path;
  final RouteOptions options;
  final String successType;
  final String? methodName;
  final String? paramsType;
  final String? queryType;
  final String? headersType;
  final String? bodyType;

  String get resolvedMethodName =>
      methodName ?? _lowerCamel(options.operationId!);
}

/// Build-time description of one generated WebSocket client method.
final class DartEdgeClientWebSocketOperation {
  const DartEdgeClientWebSocketOperation({
    required this.path,
    required this.operationId,
    this.methodName,
    this.paramsType,
    this.queryType,
    this.headersType,
  });

  final String path;
  final String operationId;
  final String? methodName;
  final String? paramsType;
  final String? queryType;
  final String? headersType;

  String get resolvedMethodName => methodName ?? _lowerCamel(operationId);
}

/// Emits Dart source for an HTTP client backed by normalized route options.
final class DartEdgeClientGenerator {
  const DartEdgeClientGenerator();

  String generate(DartEdgeClientLibrarySpec spec) {
    final library = Library((builder) {
      builder
        ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
        ..directives.add(
          Directive.import('package:dart_edge_core/dart_edge_core.dart'),
        )
        ..body.addAll(buildSpecs(spec));

      for (final import in spec.additionalImports) {
        builder.directives.add(Directive.import(import));
      }
    });

    return _dartFormatter.format('${library.accept(DartEmitter())}');
  }

  String generateLibrary(
    DartEdgeClientLibrarySpec spec, {
    String bindingsPart = 'client.bindings.g.dart',
    String modelsPart = 'client.models.g.dart',
  }) {
    final library = Library((builder) {
      builder
        ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
        ..directives.add(
          Directive.import('package:dart_edge_core/dart_edge_core.dart'),
        );

      for (final import in spec.additionalImports) {
        builder.directives.add(Directive.import(import));
      }

      builder.directives
        ..add(Directive.part(modelsPart))
        ..add(Directive.part(bindingsPart));
    });

    return _dartFormatter.format('${library.accept(DartEmitter())}');
  }

  String generateBindingsPart(
    DartEdgeClientLibrarySpec spec, {
    String libraryFile = 'client.g.dart',
  }) {
    final library = Library((builder) {
      builder
        ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
        ..directives.add(Directive.partOf(libraryFile))
        ..body.addAll(buildSpecs(spec));
    });

    return _dartFormatter.format('${library.accept(DartEmitter())}');
  }

  String generateModelsPart(
    DartEdgeClientLibrarySpec spec, {
    String libraryFile = 'client.g.dart',
  }) {
    final library = Library((builder) {
      builder
        ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
        ..directives.add(Directive.partOf(libraryFile))
        ..body.addAll(_modelClasses(spec));
    });

    return _dartFormatter.format('${library.accept(DartEmitter())}');
  }

  List<Spec> buildSpecs(DartEdgeClientLibrarySpec spec) {
    return <Spec>[_clientClass(spec)];
  }

  List<Class> _modelClasses(DartEdgeClientLibrarySpec spec) {
    final generatedTypeIds = {
      for (final operation in spec.operations)
        if (!_isRawTransportType(operation.successType)) operation.successType,
    };
    return [
      for (final schema in spec.schemas)
        if (schema is JsonObjectSchema &&
            schema.id != null &&
            generatedTypeIds.contains(schema.id))
          _modelClass(schema.id!, schema),
    ];
  }

  Class _modelClass(String name, JsonObjectSchema schema) {
    return Class((builder) {
      builder
        ..modifier = ClassModifier.final$
        ..name = name
        ..implements.add(refer('JsonEncodable'))
        ..constructors.add(_modelConstructor(schema))
        ..constructors.add(_modelFromJsonFactory(name, schema))
        ..fields.addAll(_modelFields(schema))
        ..methods.add(_modelToJsonMethod(schema));
    });
  }

  Constructor _modelConstructor(JsonObjectSchema schema) {
    return Constructor((builder) {
      builder
        ..constant = true
        ..optionalParameters.addAll([
          for (final field in _modelFieldSpecs(schema))
            _namedParameter(field.name, required: field.required, toThis: true),
        ]);
    });
  }

  Constructor _modelFromJsonFactory(String name, JsonObjectSchema schema) {
    final fields = _modelFieldSpecs(schema);
    final assignments = fields
        .map((field) => '${field.name}: ${_decodeField(field)},')
        .join('\n');
    return Constructor((builder) {
      builder
        ..factory = true
        ..name = 'fromJson'
        ..requiredParameters.add(
          Parameter((parameter) {
            parameter
              ..name = 'value'
              ..type = refer('Object?');
          }),
        )
        ..body = Code('''
final json = Map<String, Object?>.from(value! as Map);
return $name(
$assignments
);
''');
    });
  }

  Iterable<Field> _modelFields(JsonObjectSchema schema) {
    return [
      for (final field in _modelFieldSpecs(schema))
        Field((builder) {
          builder
            ..modifier = FieldModifier.final$
            ..type = refer(field.type)
            ..name = field.name;
        }),
    ];
  }

  Method _modelToJsonMethod(JsonObjectSchema schema) {
    final entries = _modelFieldSpecs(
      schema,
    ).map((field) => "'${field.wireName}': ${_encodeField(field)},").join('\n');
    return Method((builder) {
      builder
        ..annotations.add(refer('override'))
        ..returns = refer('Map<String, Object?>')
        ..name = 'toJson'
        ..body = Code('''
return <String, Object?>{
$entries
};
''');
    });
  }

  List<_ClientModelFieldSpec> _modelFieldSpecs(JsonObjectSchema schema) {
    return [
      for (final entry in schema.properties.entries)
        _ClientModelFieldSpec(
          wireName: entry.key,
          name: _lowerCamel(entry.key),
          schema: entry.value,
          required: schema.required.contains(entry.key),
          type: _clientModelType(
            entry.value,
            nullable: !schema.required.contains(entry.key),
          ),
        ),
    ];
  }

  String _decodeField(_ClientModelFieldSpec field) {
    final access = field.required
        ? "json['${field.wireName}']!"
        : "json['${field.wireName}']";
    final decoded = _decodeSchemaValue(field.schema, access);
    if (field.required) {
      return decoded;
    }
    return "$access == null ? null : $decoded";
  }

  String _encodeField(_ClientModelFieldSpec field) {
    return _encodeSchemaValue(
      field.schema,
      field.name,
      nullable: !field.required,
    );
  }

  Class _clientClass(DartEdgeClientLibrarySpec spec) {
    return Class((builder) {
      builder
        ..modifier = ClassModifier.final$
        ..name = spec.className
        ..extend = refer('DartEdgeHttpClientBase')
        ..constructors.add(_clientConstructor())
        ..methods.addAll([
          ...spec.operations.map(_operationMethod),
          ...spec.webSockets.map(_webSocketMethod),
        ]);
    });
  }

  Constructor _clientConstructor() {
    return Constructor((builder) {
      builder.optionalParameters.addAll([
        _superParameter('baseUri', required: true),
        _superParameter('transport', required: true),
        _superParameter('webSocketTransport'),
        _superParameter(
          'defaultHeaders',
          defaultTo: literalConstMap(
            const <String, String>{},
            refer('String'),
            refer('String'),
          ).code,
        ),
      ]);
    });
  }

  Method _operationMethod(DartEdgeClientOperation operation) {
    return Method((builder) {
      builder
        ..returns = _type('Future', [refer(operation.successType)])
        ..name = operation.resolvedMethodName
        ..optionalParameters.addAll(_operationParameters(operation))
        ..body = _invokeExpression(operation).returned.statement;
    });
  }

  Iterable<Parameter> _operationParameters(DartEdgeClientOperation operation) {
    return <Parameter>[
      if (operation.paramsType case final type?)
        _namedParameter('params', type: refer(type), required: true),
      if (operation.queryType case final type?)
        _namedParameter('query', type: refer('$type?')),
      if (operation.headersType case final type?)
        _namedParameter('headers', type: refer('$type?')),
      if (operation.bodyType case final type?)
        _namedParameter('body', type: refer(type), required: true),
    ];
  }

  Expression _invokeExpression(DartEdgeClientOperation operation) {
    final invocationTypes = _invocationTypes(operation);
    final invocation = refer('DartEdgeClientInvocation').newInstance(
      const <Expression>[],
      _invocationArguments(operation),
      invocationTypes,
    );

    return refer('invoke').call(
      <Expression>[invocation],
      const <String, Expression>{},
      invocationTypes,
    );
  }

  Method _webSocketMethod(DartEdgeClientWebSocketOperation operation) {
    final invocationTypes = _webSocketInvocationTypes(operation);
    return Method((builder) {
      builder
        ..returns = _type('Future', [refer('DartEdgeClientWebSocket')])
        ..name = operation.resolvedMethodName
        ..optionalParameters.addAll([
          ..._webSocketParameters(operation),
          _namedParameter(
            'protocols',
            type: _type('List', [refer('String')]),
            defaultTo: const Code('const <String>[]'),
          ),
        ])
        ..body = refer('connectWebSocket')
            .call(
              [
                refer(
                  'DartEdgeClientWebSocketInvocation',
                ).newInstance(const <Expression>[], {
                  'pathTemplate': literalString(operation.path),
                  if (operation.paramsType != null)
                    'params': _requestValueExpression(
                      type: operation.paramsType!,
                      schemaId: null,
                      value: refer('params'),
                      encode: _encoderFor(operation.paramsType!),
                    ),
                  if (operation.queryType != null)
                    'query': _requestValueExpression(
                      type: '${operation.queryType}?',
                      schemaId: null,
                      value: refer('query'),
                      encode: _nullableEncoderFor(operation.queryType!),
                    ),
                  if (operation.headersType != null)
                    'headers': _requestValueExpression(
                      type: '${operation.headersType}?',
                      schemaId: null,
                      value: refer('headers'),
                      encode: _nullableEncoderFor(operation.headersType!),
                    ),
                  'protocols': refer('protocols'),
                }, invocationTypes),
              ],
              const <String, Expression>{},
              invocationTypes,
            )
            .returned
            .statement;
    });
  }

  Iterable<Parameter> _webSocketParameters(
    DartEdgeClientWebSocketOperation operation,
  ) {
    return <Parameter>[
      if (operation.paramsType case final type?)
        _namedParameter('params', type: refer(type), required: true),
      if (operation.queryType case final type?)
        _namedParameter('query', type: refer('$type?')),
      if (operation.headersType case final type?)
        _namedParameter('headers', type: refer('$type?')),
    ];
  }

  List<Reference> _webSocketInvocationTypes(
    DartEdgeClientWebSocketOperation operation,
  ) {
    return <Reference>[
      refer(operation.paramsType ?? 'Never'),
      refer(operation.queryType == null ? 'Never' : '${operation.queryType}?'),
      refer(
        operation.headersType == null ? 'Never' : '${operation.headersType}?',
      ),
    ];
  }

  List<Reference> _invocationTypes(DartEdgeClientOperation operation) {
    return <Reference>[
      refer(operation.successType),
      refer(operation.paramsType ?? 'Never'),
      refer(operation.queryType == null ? 'Never' : '${operation.queryType}?'),
      refer(
        operation.headersType == null ? 'Never' : '${operation.headersType}?',
      ),
      refer(operation.bodyType ?? 'Never'),
    ];
  }

  Map<String, Expression> _invocationArguments(
    DartEdgeClientOperation operation,
  ) {
    final options = operation.options;
    final successSchemaId = jsonSchemaRouteId(options.responses.success.schema);
    final arguments = <String, Expression>{
      'method': refer('HttpMethod').property(operation.method.name),
      'pathTemplate': literalString(operation.path),
      'success': refer('DartEdgeClientResponseSpec').newInstance(
        const <Expression>[],
        <String, Expression>{
          'status': literalNum(options.responses.success.status),
          'contentType': literalString(options.responses.success.contentType),
          if (successSchemaId case final schemaId?)
            'schemaId': literalString(schemaId),
          if (successSchemaId != null)
            'decoder': refer(operation.successType).property('fromJson'),
        },
        <Reference>[refer(operation.successType)],
      ),
    };

    if (options.params case final schema?) {
      arguments['params'] = _requestValueExpression(
        type: operation.paramsType!,
        schemaId: jsonSchemaRouteId(schema),
        value: refer('params'),
        encode: _encoderFor(operation.paramsType!),
      );
    }
    if (options.query case final schema?) {
      arguments['query'] = _requestValueExpression(
        type: '${operation.queryType}?',
        schemaId: jsonSchemaRouteId(schema),
        value: refer('query'),
        encode: _nullableEncoderFor(operation.queryType!),
      );
    }
    if (options.headers case final schema?) {
      arguments['headers'] = _requestValueExpression(
        type: '${operation.headersType}?',
        schemaId: jsonSchemaRouteId(schema),
        value: refer('headers'),
        encode: _nullableEncoderFor(operation.headersType!),
      );
    }
    if (options.body case final body?) {
      final bodySchemaId = jsonSchemaRouteId(body.schema);
      final bodyEncoder = bodySchemaId == null
          ? null
          : _encoderFor(operation.bodyType!);
      arguments['body'] = refer('DartEdgeClientRequestBody').newInstance(
        const <Expression>[],
        <String, Expression>{
          'contentType': literalString(body.contentType),
          if (bodySchemaId case final schemaId?)
            'schemaId': literalString(schemaId),
          'value': refer('body'),
          'encoder': ?bodyEncoder,
        },
        <Reference>[refer(operation.bodyType!)],
      );
    }

    return arguments;
  }
}

final class _ClientModelFieldSpec {
  const _ClientModelFieldSpec({
    required this.wireName,
    required this.name,
    required this.schema,
    required this.required,
    required this.type,
  });

  final String wireName;
  final String name;
  final JsonSchema schema;
  final bool required;
  final String type;
}

String _clientModelType(JsonSchema schema, {required bool nullable}) {
  final baseType = switch (schema) {
    JsonReferenceSchema _ => jsonSchemaRouteId(schema) ?? 'Object?',
    JsonStringSchema _ => 'String',
    JsonIntegerSchema _ => 'int',
    JsonNumberSchema _ => 'num',
    JsonBooleanSchema _ => 'bool',
    JsonArraySchema _ =>
      'List<${_clientModelType(schema.items ?? const JsonSchema.any(), nullable: false)}>',
    JsonObjectSchema _ => 'Map<String, Object?>',
    JsonAnySchema _ => 'Object?',
    JsonRawSchema _ => 'Object?',
    _ => 'Object?',
  };
  if (nullable || schema.nullable) {
    if (baseType.endsWith('?')) {
      return baseType;
    }
    return '$baseType?';
  }
  return baseType;
}

String _decodeSchemaValue(JsonSchema schema, String value) {
  return switch (schema) {
    JsonReferenceSchema _ =>
      '${jsonSchemaRouteId(schema) ?? 'Object'}.fromJson(Map<String, Object?>.from($value as Map))',
    JsonStringSchema _ => '$value as String',
    JsonIntegerSchema _ => '($value as num).toInt()',
    JsonNumberSchema _ => '$value as num',
    JsonBooleanSchema _ => '$value as bool',
    JsonArraySchema _ =>
      '($value as List).map((item) => ${_decodeSchemaValue(schema.items ?? const JsonSchema.any(), 'item')}).toList(growable: false)',
    JsonObjectSchema _ => 'Map<String, Object?>.from($value as Map)',
    JsonAnySchema _ => value,
    JsonRawSchema _ => value,
    _ => value,
  };
}

String _encodeSchemaValue(
  JsonSchema schema,
  String value, {
  required bool nullable,
}) {
  return switch (schema) {
    JsonReferenceSchema _ => nullable ? '$value?.toJson()' : '$value.toJson()',
    JsonArraySchema _ when schema.items is JsonReferenceSchema =>
      nullable
          ? '$value?.map((item) => item.toJson()).toList(growable: false)'
          : '$value.map((item) => item.toJson()).toList(growable: false)',
    _ => value,
  };
}

Expression _requestValueExpression({
  required String type,
  required String? schemaId,
  required Expression value,
  Expression? encode,
}) {
  return refer('DartEdgeClientRequestValue').newInstance(
    const <Expression>[],
    <String, Expression>{
      if (schemaId case final schemaId?) 'schemaId': literalString(schemaId),
      'value': value,
      'encoder': ?encode,
    },
    <Reference>[refer(type)],
  );
}

Expression? _encoderFor(String type) {
  if (_isRawTransportType(type)) {
    return null;
  }
  return const CodeExpression(Code('(value) => value.toJson()'));
}

Expression? _nullableEncoderFor(String type) {
  if (_isRawTransportType(type)) {
    return null;
  }
  return const CodeExpression(Code('(value) => value?.toJson()'));
}

bool _isRawTransportType(String type) {
  return type == 'Map<String, Object?>' ||
      type == 'Map<String, String>' ||
      type == 'String' ||
      type == 'int' ||
      type == 'double' ||
      type == 'num' ||
      type == 'bool' ||
      type == 'Object?' ||
      type == 'Object';
}

DartEdgeClientOperation _operationFromOptions({
  required HttpMethod method,
  required String path,
  required RouteOptions options,
  required Map<String, String> schemaTypes,
}) {
  return DartEdgeClientOperation(
    method: method,
    path: path,
    options: options,
    successType:
        _schemaType(options.success?.schema, schemaTypes) ??
        _defaultSuccessType(options.success),
    paramsType: _schemaType(options.params, schemaTypes),
    queryType: _schemaType(options.query, schemaTypes),
    headersType: _schemaType(options.headers, schemaTypes),
    bodyType: options.body == null
        ? null
        : _schemaType(options.body?.schema, schemaTypes) ?? 'Object?',
  );
}

RouteOptions _effectiveRouteOptions<TServices>(
  RouteRegistration<TServices> registration,
  RouteOptions options,
) {
  return RouteOptions(
    operationId: options.operationId!,
    summary: options.summary,
    tags: _mergeTags(registration.tags, options.tags),
    deprecated: options.deprecated,
    exposure: registration.exposure.restrict(options.exposure),
    params: options.params,
    query: options.query,
    headers: options.headers,
    body: options.body,
    success: options.responses.success,
    errors: options.responses.errors,
  );
}

WebSocketOptions _effectiveWebSocketOptions<TServices>(
  RouteRegistration<TServices> registration,
  WebSocketOptions options,
) {
  return WebSocketOptions(
    operationId: options.operationId,
    summary: options.summary,
    tags: _mergeTags(registration.tags, options.tags),
    deprecated: options.deprecated,
    exposure: registration.exposure.restrict(options.exposure),
  );
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

String? _schemaType(JsonSchema? schema, Map<String, String> schemaTypes) {
  final schemaId = jsonSchemaRouteId(schema);
  if (schemaId == null) {
    return null;
  }
  return schemaTypes[schemaId] ?? schemaId;
}

String _defaultSuccessType(ResponseSpec? response) {
  if (response == null) {
    return 'Object?';
  }
  final contentType = response.contentType.toLowerCase();
  if (contentType.startsWith('text/plain')) {
    return 'String';
  }
  return 'Object?';
}

bool _matchesPathPrefix(String path, String prefix) {
  final normalizedPrefix = _normalizeIgnoredPath(prefix);
  if (path == normalizedPrefix) {
    return true;
  }
  if (normalizedPrefix == '/') {
    return path.startsWith('/');
  }
  return path.startsWith('$normalizedPrefix/');
}

String _normalizeIgnoredPath(String path) {
  if (path == '/') {
    return path;
  }
  return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

Parameter _superParameter(
  String name, {
  bool required = false,
  Code? defaultTo,
}) {
  return Parameter((builder) {
    builder
      ..name = name
      ..named = true
      ..toSuper = true
      ..required = required
      ..defaultTo = defaultTo;
  });
}

Parameter _namedParameter(
  String name, {
  Reference? type,
  bool required = false,
  Code? defaultTo,
  bool toThis = false,
}) {
  return Parameter((builder) {
    builder
      ..name = name
      ..named = true
      ..type = type
      ..required = required
      ..defaultTo = defaultTo
      ..toThis = toThis;
  });
}

TypeReference _type(String symbol, [Iterable<Reference> types = const []]) {
  return TypeReference((builder) {
    builder
      ..symbol = symbol
      ..types.addAll(types);
  });
}

final _dartFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

String _lowerCamel(String value) {
  if (value.isEmpty) {
    return value;
  }
  final parts = value
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return value;
  }
  final first = parts.first;
  return [
    '${first[0].toLowerCase()}${first.substring(1)}',
    for (final part in parts.skip(1))
      '${part[0].toUpperCase()}${part.substring(1)}',
  ].join();
}
