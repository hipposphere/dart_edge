import 'package:code_builder/code_builder.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_style/dart_style.dart';

import '../client/dart_edge_client_generator.dart';

/// Build-time description of one generated HTTP server library.
final class DartEdgeHttpServerLibrarySpec {
  const DartEdgeHttpServerLibrarySpec({
    required this.routes,
    this.schemas = const <JsonSchema>[],
    this.codecs = const <DartEdgeRuntimeCodecSpec>[],
    this.additionalImports = const <String>[],
    this.routesFactoryName = r'$generatedRoutes',
    this.schemaRegistryName = r'$generatedSchemas',
    this.codecRegistryFactoryName = r'$generatedCodecs',
    this.clientClassName,
  });

  /// Routes generated from annotated source.
  final List<DartEdgeHttpRouteSpec> routes;

  /// Shared schema graph used by runtime validation, OpenAPI, and clients.
  final List<JsonSchema> schemas;

  /// Runtime codec slots required by the generated route contracts.
  final List<DartEdgeRuntimeCodecSpec> codecs;

  /// Imports for model types referenced by route and codec specs.
  final List<String> additionalImports;

  /// Name of the generated route-definition factory.
  final String routesFactoryName;

  /// Name of the generated [JsonSchemaRegistry] variable.
  final String schemaRegistryName;

  /// Name of the generated runtime codec registry factory.
  final String codecRegistryFactoryName;

  /// Optional generated HTTP client class name.
  final String? clientClassName;
}

/// Build-time description of one generated JSON route.
final class DartEdgeHttpRouteSpec {
  const DartEdgeHttpRouteSpec({
    required this.routeClassName,
    required this.contract,
    required this.successType,
    this.handlerParameterName,
    this.clientMethodName,
    this.paramsType,
    this.queryType,
    this.headersType,
    this.bodyType,
  });

  /// Concrete `JsonRouteDefinition` class name to emit.
  final String routeClassName;

  /// Normalized runtime contract for the route.
  final RouteContract contract;

  /// Dart success type returned by the generated route and client method.
  final String successType;

  /// Parameter name used by the generated route factory for this handler.
  final String? handlerParameterName;

  /// Optional method name override for generated clients.
  final String? clientMethodName;

  final String? paramsType;
  final String? queryType;
  final String? headersType;
  final String? bodyType;

  String get resolvedHandlerParameterName =>
      handlerParameterName ?? _lowerCamel(routeClassName);
}

/// Runtime codec slot emitted into the generated codec registry factory.
final class DartEdgeRuntimeCodecSpec {
  const DartEdgeRuntimeCodecSpec({
    required this.schemaId,
    required this.dartType,
    this.parameterName,
  });

  /// Schema id used by `RouteContract` and `JsonSchemaRegistry`.
  final String schemaId;

  /// Dart model type handled by this codec.
  final String dartType;

  /// Optional generated factory parameter name.
  final String? parameterName;

  String get resolvedParameterName =>
      parameterName ?? '${_lowerCamel(dartType)}Codec';
}

/// Emits Dart source for generated HTTP route contracts and registries.
final class DartEdgeHttpServerGenerator {
  const DartEdgeHttpServerGenerator();

  String generate(DartEdgeHttpServerLibrarySpec spec) {
    return _generate(spec, emitImports: true);
  }

  /// Emits declarations suitable for a generated `part` file.
  String generatePart(DartEdgeHttpServerLibrarySpec spec) {
    return _generate(spec, emitImports: false);
  }

  List<Spec> buildSpecs(DartEdgeHttpServerLibrarySpec spec) {
    return <Spec>[
      _schemaRegistryField(spec),
      _codecRegistryFactory(spec),
      for (final route in spec.routes) ...[
        _contractField(route),
        _handlerTypeDef(route),
        _routeClass(route),
      ],
      _routesFactory(spec),
      if (spec.clientClassName case final clientClassName?)
        ...const DartEdgeClientGenerator().buildSpecs(
          DartEdgeClientLibrarySpec(
            className: clientClassName,
            operations: [
              for (final route in spec.routes)
                DartEdgeClientOperation(
                  contract: route.contract,
                  successType: route.successType,
                  methodName: route.clientMethodName,
                  paramsType: route.paramsType,
                  queryType: route.queryType,
                  headersType: route.headersType,
                  bodyType: route.bodyType,
                ),
            ],
          ),
        ),
    ];
  }

  String _generate(
    DartEdgeHttpServerLibrarySpec spec, {
    required bool emitImports,
  }) {
    final library = Library((builder) {
      if (emitImports) {
        builder
          ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
          ..directives.add(Directive.import('dart:async'))
          ..directives.add(
            Directive.import(
              'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
            ),
          );

        if (spec.clientClassName != null) {
          builder.directives.add(
            Directive.import(
              'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart',
            ),
          );
        }

        for (final import in spec.additionalImports) {
          builder.directives.add(Directive.import(import));
        }
      }

      builder.body.addAll(buildSpecs(spec));
    });

    final emitted = '${library.accept(DartEmitter())}';
    return emitImports ? _dartFormatter.format(emitted) : emitted;
  }

  Field _schemaRegistryField(DartEdgeHttpServerLibrarySpec spec) {
    return Field((builder) {
      builder
        ..modifier = FieldModifier.final$
        ..type = refer('JsonSchemaRegistry')
        ..name = spec.schemaRegistryName
        ..assignment =
            refer('JsonSchemaRegistry').newInstance(const <Expression>[], {
              'schemas': literalList(
                spec.schemas.map(_schemaExpression),
                refer('JsonSchema'),
              ),
            }).code;
    });
  }

  Method _codecRegistryFactory(DartEdgeHttpServerLibrarySpec spec) {
    return Method((builder) {
      builder
        ..returns = refer('DartEdgeCodecRegistry')
        ..name = spec.codecRegistryFactoryName
        ..optionalParameters.addAll(
          spec.codecs.map(
            (codec) => _namedParameter(
              codec.resolvedParameterName,
              type: _type('DartEdgeCodec', [refer(codec.dartType)]),
              required: true,
            ),
          ),
        )
        ..body = _codecRegistryExpression(spec.codecs).returned.statement;
    });
  }

  Field _contractField(DartEdgeHttpRouteSpec route) {
    return Field((builder) {
      builder
        ..modifier = FieldModifier.final$
        ..type = refer('RouteContract')
        ..name = _contractName(route)
        ..assignment = _routeContractExpression(route.contract).code;
    });
  }

  TypeDef _handlerTypeDef(DartEdgeHttpRouteSpec route) {
    return TypeDef((builder) {
      builder
        ..name = _handlerTypeName(route)
        ..types.add(refer('TServices'))
        ..definition = FunctionType((function) {
          function
            ..returnType = _type('FutureOr', [refer(route.successType)])
            ..requiredParameters.add(
              _type('RequestContext', [refer('TServices')]),
            );
        });
    });
  }

  Class _routeClass(DartEdgeHttpRouteSpec route) {
    return Class((builder) {
      builder
        ..modifier = ClassModifier.final$
        ..name = route.routeClassName
        ..types.add(refer('TServices'))
        ..extend = _type('JsonRouteDefinition', [
          refer('TServices'),
          refer(route.successType),
        ])
        ..constructors.add(
          Constructor((constructor) {
            constructor.requiredParameters.add(
              Parameter((parameter) {
                parameter
                  ..name = 'handler'
                  ..toThis = true;
              }),
            );
          }),
        )
        ..fields.add(
          Field((field) {
            field
              ..modifier = FieldModifier.final$
              ..type = _type(_handlerTypeName(route), [refer('TServices')])
              ..name = 'handler';
          }),
        )
        ..methods.addAll([
          Method((method) {
            method
              ..annotations.add(refer('override'))
              ..type = MethodType.getter
              ..returns = refer('RouteContract')
              ..name = 'contract'
              ..lambda = true
              ..body = refer(_contractName(route)).code;
          }),
          Method((method) {
            method
              ..annotations.add(refer('override'))
              ..returns = _type('FutureOr', [refer(route.successType)])
              ..name = 'handle'
              ..requiredParameters.add(
                Parameter((parameter) {
                  parameter
                    ..type = _type('RequestContext', [refer('TServices')])
                    ..name = 'ctx';
                }),
              )
              ..body = refer('handler').call([refer('ctx')]).returned.statement;
          }),
        ]);
    });
  }

  Method _routesFactory(DartEdgeHttpServerLibrarySpec spec) {
    return Method((builder) {
      builder
        ..returns = _type('List', [
          _type('RouteDefinition', [refer('TServices')]),
        ])
        ..name = spec.routesFactoryName
        ..types.add(refer('TServices'))
        ..optionalParameters.addAll(
          spec.routes.map(
            (route) => _namedParameter(
              route.resolvedHandlerParameterName,
              type: _type(_handlerTypeName(route), [refer('TServices')]),
              required: true,
            ),
          ),
        )
        ..body = literalList(
          spec.routes.map(
            (route) => _type(route.routeClassName, [
              refer('TServices'),
            ]).newInstance([refer(route.resolvedHandlerParameterName)]),
          ),
          _type('RouteDefinition', [refer('TServices')]),
        ).returned.statement;
    });
  }

  Expression _codecRegistryExpression(List<DartEdgeRuntimeCodecSpec> codecs) {
    var expression = refer('DartEdgeCodecRegistry').property('empty');
    for (final codec in codecs) {
      expression = expression
          .property('withCodec')
          .call(
            [literalString(codec.schemaId), refer(codec.resolvedParameterName)],
            const <String, Expression>{},
            [refer(codec.dartType)],
          );
    }
    return expression;
  }

  Expression _routeContractExpression(RouteContract contract) {
    return refer('RouteContract').newInstance(const <Expression>[], {
      'method': refer('HttpMethod').property(contract.method.name),
      'path': literalString(contract.path),
      'options': _routeOptionsExpression(contract.options),
    });
  }

  Expression _routeOptionsExpression(RouteOptions options) {
    final arguments = <String, Expression>{
      'operationId': literalString(options.operationId!),
    };

    if (options.summary case final summary?) {
      arguments['summary'] = literalString(summary);
    }
    if (options.tags.isNotEmpty) {
      arguments['tags'] = literalList(
        options.tags.map(literalString),
        refer('String'),
      );
    }
    if (options.deprecated) {
      arguments['deprecated'] = literalBool(true);
    }
    if (options.params case final ref?) {
      arguments['params'] = _jsonSchemaRefExpression(ref.id);
    }
    if (options.query case final ref?) {
      arguments['query'] = _jsonSchemaRefExpression(ref.id);
    }
    if (options.headers case final ref?) {
      arguments['headers'] = _jsonSchemaRefExpression(ref.id);
    }
    if (options.body case final body?) {
      arguments['body'] = _requestBodyExpression(body);
    }
    arguments['success'] = _responseSpecExpression(options.success!);
    if (options.errors.isNotEmpty) {
      arguments['errors'] = literalList(
        options.errors.map(_errorResponseExpression),
        refer('ErrorResponse'),
      );
    }

    return refer('RouteOptions').newInstance(const <Expression>[], arguments);
  }
}

Expression _schemaExpression(JsonSchema schema) {
  return switch (schema) {
    JsonAnySchema() => refer('JsonSchema').newInstanceNamed(
      'any',
      const <Expression>[],
      _schemaCommonArguments(schema),
    ),
    JsonObjectSchema() =>
      refer('JsonSchema').newInstanceNamed('object', const <Expression>[], {
        ..._schemaCommonArguments(schema),
        'nullable': literalBool(schema.nullable),
        'properties': literalMap(
          schema.properties.map(
            (key, value) =>
                MapEntry(literalString(key), _schemaExpression(value)),
          ),
          refer('String'),
          refer('JsonSchema'),
        ),
        'required': literalList(
          schema.required.map(literalString),
          refer('String'),
        ),
        if (schema.additionalProperties case final additionalProperties?)
          'additionalProperties': literalBool(additionalProperties),
      }),
    JsonArraySchema() =>
      refer('JsonSchema').newInstanceNamed('array', const <Expression>[], {
        ..._schemaCommonArguments(schema),
        'nullable': literalBool(schema.nullable),
        if (schema.items case final items?) 'items': _schemaExpression(items),
      }),
    JsonStringSchema() =>
      refer('JsonSchema').newInstanceNamed('string', const <Expression>[], {
        ..._schemaCommonArguments(schema),
        'nullable': literalBool(schema.nullable),
        if (schema.format case final format?) 'format': literalString(format),
      }),
    JsonIntegerSchema() =>
      refer('JsonSchema').newInstanceNamed('integer', const <Expression>[], {
        ..._schemaCommonArguments(schema),
        'nullable': literalBool(schema.nullable),
        if (schema.format case final format?) 'format': literalString(format),
      }),
    JsonNumberSchema() =>
      refer('JsonSchema').newInstanceNamed('number', const <Expression>[], {
        ..._schemaCommonArguments(schema),
        'nullable': literalBool(schema.nullable),
        if (schema.format case final format?) 'format': literalString(format),
      }),
    JsonBooleanSchema() => refer('JsonSchema').newInstanceNamed(
      'boolean',
      const <Expression>[],
      {
        ..._schemaCommonArguments(schema),
        'nullable': literalBool(schema.nullable),
      },
    ),
    JsonReferenceSchema() => refer('JsonSchema').newInstanceNamed('ref', [
      literalString(schema.targetRef),
    ], _schemaCommonArguments(schema, includeRef: false)),
    JsonRawSchema() => refer('JsonSchema').newInstanceNamed(
      'raw',
      [_objectExpression(schema.schema)],
      {if (schema.ref case final ref?) 'ref': _jsonSchemaRefExpression(ref.id)},
    ),
    _ => throw UnsupportedError('Cannot emit schema literal for $schema.'),
  };
}

Map<String, Expression> _schemaCommonArguments(
  JsonSchema schema, {
  bool includeRef = true,
}) {
  final ref = schema.ref;
  return <String, Expression>{
    if (includeRef && ref != null) 'ref': _jsonSchemaRefExpression(ref.id),
    if (schema.title case final title?) 'title': literalString(title),
    if (schema.description case final description?)
      'description': literalString(description),
  };
}

Expression _requestBodyExpression(RequestBody body) {
  if (body.ref case final ref?) {
    if (_isJsonContentType(body.contentType)) {
      return refer('RequestBody').newInstanceNamed(
        'json',
        const <Expression>[],
        {'ref': _jsonSchemaRefExpression(ref.id)},
        [refer('Object?')],
      );
    }
  } else if (_isJsonContentType(body.contentType)) {
    return refer('RequestBody').newInstanceNamed('jsonValue', const []);
  }

  if (body.contentType == 'text/plain; charset=utf-8') {
    return refer('RequestBody').newInstanceNamed('text', const []);
  }
  if (body.contentType == 'multipart/form-data') {
    return refer('RequestBody').newInstanceNamed('multipartFormData', const []);
  }
  throw UnsupportedError('Cannot emit RequestBody for ${body.contentType}.');
}

Expression _responseSpecExpression(ResponseSpec response) {
  if (_isJsonContentType(response.contentType)) {
    return refer('ResponseSpec').newInstanceNamed(
      'json',
      const <Expression>[],
      {
        'status': literalNum(response.status),
        if (response.ref case final ref?)
          'ref': _jsonSchemaRefExpression(ref.id),
      },
      [refer('Object?')],
    );
  }
  if (response.contentType == 'text/plain; charset=utf-8') {
    return refer('ResponseSpec').newInstanceNamed(
      'text',
      const <Expression>[],
      {'status': literalNum(response.status)},
    );
  }
  if (response.contentType == 'text/html; charset=utf-8') {
    return refer('ResponseSpec').newInstanceNamed(
      'html',
      const <Expression>[],
      {'status': literalNum(response.status)},
    );
  }
  if (response.contentType == 'text/event-stream; charset=utf-8') {
    return refer('ResponseSpec').newInstanceNamed('sse', const <Expression>[], {
      'status': literalNum(response.status),
    });
  }
  throw UnsupportedError(
    'Cannot emit ResponseSpec for ${response.contentType}.',
  );
}

Expression _errorResponseExpression(ErrorResponse error) {
  return refer('ErrorResponse').newInstance(const <Expression>[], {
    'status': literalNum(error.status),
    if (error.code case final code?) 'code': literalString(code),
  });
}

Expression _jsonSchemaRefExpression(String id) {
  return refer('JsonSchemaRef').constInstance(
    [literalString(id)],
    const <String, Expression>{},
    [refer('Object?')],
  );
}

Expression _objectExpression(Object? value) {
  return switch (value) {
    null => literalNull,
    String() => literalString(value),
    num() => literalNum(value),
    bool() => literalBool(value),
    List<Object?>() => literalList(
      value.map(_objectExpression),
      refer('Object?'),
    ),
    Map<String, Object?>() => literalMap(
      value.map(
        (key, value) => MapEntry(literalString(key), _objectExpression(value)),
      ),
      refer('String'),
      refer('Object?'),
    ),
    _ => throw UnsupportedError('Cannot emit object literal for $value.'),
  };
}

Parameter _namedParameter(
  String name, {
  Reference? type,
  bool required = false,
}) {
  return Parameter((builder) {
    builder
      ..name = name
      ..named = true
      ..type = type
      ..required = required;
  });
}

TypeReference _type(String symbol, [Iterable<Reference> types = const []]) {
  return TypeReference((builder) {
    builder
      ..symbol = symbol
      ..types.addAll(types);
  });
}

String _contractName(DartEdgeHttpRouteSpec route) {
  return '${_lowerCamel(route.routeClassName)}Contract';
}

String _handlerTypeName(DartEdgeHttpRouteSpec route) {
  return '_${route.routeClassName}Handler';
}

bool _isJsonContentType(String contentType) {
  return contentType == 'application/json' ||
      contentType == 'application/json; charset=utf-8';
}

final _dartFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

String _lowerCamel(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toLowerCase()}${value.substring(1)}';
}
