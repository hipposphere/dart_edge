import 'package:code_builder/code_builder.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_style/dart_style.dart';

import '../client/dart_edge_client_generator.dart';

/// Build-time description of one generated HTTP server library.
final class DartEdgeHttpServerLibrarySpec {
  const DartEdgeHttpServerLibrarySpec({
    required this.routes,
    this.schemas = const <JsonSchema>[],
    this.additionalImports = const <String>[],
    this.routesFactoryName = r'$generatedRoutes',
    this.schemaRegistryName = r'$generatedSchemas',
    this.clientClassName,
  });

  /// Routes described by normalized source metadata.
  final List<DartEdgeHttpRouteSpec> routes;

  /// Shared schema graph used by runtime validation, OpenAPI, and clients.
  final List<JsonSchema> schemas;

  /// Imports for model types referenced by route and codec specs.
  final List<String> additionalImports;

  /// Name of the generated route mounting function.
  final String routesFactoryName;

  /// Name of the generated [JsonSchemaRegistry] variable.
  final String schemaRegistryName;

  /// Optional generated HTTP client class name.
  final String? clientClassName;
}

/// Build-time description of one generated HTTP route.
final class DartEdgeHttpRouteSpec {
  const DartEdgeHttpRouteSpec({
    required this.routeClassName,
    required this.method,
    required this.path,
    required this.options,
    required this.successType,
    this.handlerParameterName,
    this.clientMethodName,
    this.paramsType,
    this.queryType,
    this.headersType,
    this.bodyType,
    this.inputs = const <DartEdgeRouteInputSpec>[],
    this.params = const <DartEdgeRouteFieldSpec>[],
    this.query = const <DartEdgeRouteFieldSpec>[],
    this.headers = const <DartEdgeRouteFieldSpec>[],
  });

  /// Concrete `HttpRouteDefinition` class name to emit.
  final String routeClassName;

  /// HTTP method accepted by the generated route.
  final HttpMethod method;

  /// Route path pattern, for example `/users/<id>`.
  final String path;

  /// Normalized runtime options for the route.
  final RouteOptions options;

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
  final List<DartEdgeRouteInputSpec> inputs;
  final List<DartEdgeRouteFieldSpec> params;
  final List<DartEdgeRouteFieldSpec> query;
  final List<DartEdgeRouteFieldSpec> headers;

  String get resolvedHandlerParameterName =>
      handlerParameterName ?? _lowerCamel(routeClassName);
}

enum DartEdgeRouteInputSource { params, query, headers, body }

/// One generated route handler argument read from the request.
final class DartEdgeRouteInputSpec {
  const DartEdgeRouteInputSpec({
    required this.source,
    required this.parameterName,
    required this.dartType,
    required this.required,
    this.wireName,
  });

  /// Request location for this handler argument.
  final DartEdgeRouteInputSource source;

  /// Handler parameter name.
  final String parameterName;

  /// Dart value type passed to the handler.
  final String dartType;

  /// Whether the source annotated parameter was required.
  final bool required;

  /// Wire name used by path, query, and header inputs.
  final String? wireName;
}

/// One generated route handler argument read from path, query, or headers.
final class DartEdgeRouteFieldSpec {
  const DartEdgeRouteFieldSpec({
    required this.parameterName,
    required this.wireName,
    required this.dartType,
    required this.required,
  });

  /// Handler parameter name.
  final String parameterName;

  /// Wire name used by the HTTP request.
  final String wireName;

  /// Dart value type passed to the handler.
  final String dartType;

  /// Whether the source annotated parameter was required.
  final bool required;
}

/// Emits Dart source for generated HTTP route options and registries.
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
      for (final route in spec.routes) ...[
        _optionsField(route),
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
                  method: route.method,
                  path: route.path,
                  options: route.options,
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

  Field _optionsField(DartEdgeHttpRouteSpec route) {
    return Field((builder) {
      builder
        ..modifier = FieldModifier.final$
        ..type = refer('RouteOptions')
        ..name = _optionsName(route)
        ..assignment = _routeOptionsExpression(route.options).code;
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
            ..requiredParameters.addAll(_handlerParameters(route));
        });
    });
  }

  Class _routeClass(DartEdgeHttpRouteSpec route) {
    return Class((builder) {
      builder
        ..modifier = ClassModifier.final$
        ..name = route.routeClassName
        ..types.add(refer('TServices'))
        ..extend = _type('HttpRouteDefinition', [
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
              ..returns = refer('RouteOptions')
              ..name = 'options'
              ..lambda = true
              ..body = refer(_optionsName(route)).code;
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
              ..body = _handleBody(route);
          }),
        ]);
    });
  }

  Method _routesFactory(DartEdgeHttpServerLibrarySpec spec) {
    return Method((builder) {
      builder
        ..returns = refer('void')
        ..name = spec.routesFactoryName
        ..types.add(refer('TServices'))
        ..requiredParameters.add(
          Parameter((parameter) {
            parameter
              ..type = _type('Router', [refer('TServices')])
              ..name = 'router';
          }),
        )
        ..optionalParameters.addAll(
          spec.routes.map(
            (route) => _namedParameter(
              route.resolvedHandlerParameterName,
              type: _type(_handlerTypeName(route), [refer('TServices')]),
              required: true,
            ),
          ),
        )
        ..body = Block.of(
          spec.routes.map(
            (route) => refer('router')
                .property(_routerRouteMethodName(route.method))
                .call([
                  literalString(route.path),
                  _type(route.routeClassName, [
                    refer('TServices'),
                  ]).newInstance([refer(route.resolvedHandlerParameterName)]),
                ])
                .statement,
          ),
        );
    });
  }

  String _routerRouteMethodName(HttpMethod method) {
    return switch (method) {
      HttpMethod.get => 'routeGet',
      HttpMethod.post => 'routePost',
      HttpMethod.put => 'routePut',
      HttpMethod.patch => 'routePatch',
      HttpMethod.delete => 'routeDelete',
      HttpMethod.head => 'routeHead',
      HttpMethod.options => 'routeOptions',
    };
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
    if (options.params case final schema?) {
      arguments['params'] = _schemaExpression(schema);
    }
    if (options.query case final schema?) {
      arguments['query'] = _schemaExpression(schema);
    }
    if (options.headers case final schema?) {
      arguments['headers'] = _schemaExpression(schema);
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

Iterable<Reference> _handlerParameters(DartEdgeHttpRouteSpec route) {
  return <Reference>[
    for (final input in route.inputs) refer(_inputParameterType(input)),
  ];
}

Code _handleBody(DartEdgeHttpRouteSpec route) {
  final arguments = <String>[
    for (final input in route.inputs) _readInputExpression(input),
  ];

  return Code('return handler(${arguments.join(', ')});');
}

String _inputParameterType(DartEdgeRouteInputSpec input) {
  if (input.required || input.dartType.endsWith('?')) {
    return input.dartType;
  }
  return '${input.dartType}?';
}

String _readInputExpression(DartEdgeRouteInputSpec input) {
  return switch (input.source) {
    DartEdgeRouteInputSource.params => _readScalarExpression(
      'ctx.req.param',
      input,
    ),
    DartEdgeRouteInputSource.query => _readScalarExpression(
      'ctx.req.queryParam',
      input,
    ),
    DartEdgeRouteInputSource.headers => _readScalarExpression(
      'ctx.req.header',
      input,
    ),
    DartEdgeRouteInputSource.body =>
      '${input.dartType}.fromJson(ctx.req.bodyOrNull)',
  };
}

String _readScalarExpression(String reader, DartEdgeRouteInputSpec input) {
  final source = "$reader('${input.wireName}')";
  final nullable = !input.required || input.dartType.endsWith('?');
  final raw = nullable ? source : '$source!';
  final type = input.dartType.endsWith('?')
      ? input.dartType.substring(0, input.dartType.length - 1)
      : input.dartType;

  return switch (type) {
    'String' => raw,
    'int' =>
      nullable
          ? '($source == null ? null : int.parse($source!))'
          : 'int.parse($raw)',
    'double' =>
      nullable
          ? '($source == null ? null : double.parse($source!))'
          : 'double.parse($raw)',
    'num' =>
      nullable
          ? '($source == null ? null : num.parse($source!))'
          : 'num.parse($raw)',
    'bool' =>
      nullable
          ? '($source == null ? null : $source == \'true\')'
          : '$raw == \'true\'',
    _ => raw,
  };
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
      literalString(schema.ref),
    ], _schemaCommonArguments(schema)),
    JsonRawSchema() => refer('JsonSchema').newInstanceNamed(
      'raw',
      [_objectExpression(schema.schema)],
      {if (schema.id case final id?) 'id': literalString(id)},
    ),
    _ => throw UnsupportedError('Cannot emit schema literal for $schema.'),
  };
}

Map<String, Expression> _schemaCommonArguments(JsonSchema schema) {
  return <String, Expression>{
    if (schema.id case final id?) 'id': literalString(id),
    if (schema.title case final title?) 'title': literalString(title),
    if (schema.description case final description?)
      'description': literalString(description),
    if (schema.enumValues.isNotEmpty)
      'enumValues': literalList(
        schema.enumValues.map(_objectExpression),
        refer('Object?'),
      ),
  };
}

Expression _requestBodyExpression(RequestBody body) {
  if (body.schema case final schema?) {
    if (_isJsonContentType(body.contentType)) {
      return refer('RequestBody').newInstanceNamed(
        'json',
        const <Expression>[],
        {'schema': _schemaExpression(schema)},
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
    return refer(
      'ResponseSpec',
    ).newInstanceNamed('json', const <Expression>[], {
      'status': literalNum(response.status),
      if (response.schema case final schema?)
        'schema': _schemaExpression(schema),
    });
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
    Map() => literalMap(
      {
        for (final entry in value.entries)
          literalString('${entry.key}'): _objectExpression(entry.value),
      },
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

String _optionsName(DartEdgeHttpRouteSpec route) {
  return '${_lowerCamel(route.routeClassName)}Options';
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
