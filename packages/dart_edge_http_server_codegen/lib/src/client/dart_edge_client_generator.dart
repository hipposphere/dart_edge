import 'package:code_builder/code_builder.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_style/dart_style.dart';

import '../json_schema_route_id.dart';

/// Build-time description of one generated client library.
final class DartEdgeClientLibrarySpec {
  const DartEdgeClientLibrarySpec({
    required this.className,
    required this.operations,
    this.additionalImports = const <String>[],
  });

  final String className;
  final List<DartEdgeClientOperation> operations;
  final List<String> additionalImports;
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

/// Emits Dart source for an HTTP client backed by normalized route options.
final class DartEdgeClientGenerator {
  const DartEdgeClientGenerator();

  String generate(DartEdgeClientLibrarySpec spec) {
    final library = Library((builder) {
      builder
        ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
        ..directives.add(
          Directive.import(
            'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart',
          ),
        )
        ..directives.add(
          Directive.import(
            'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
          ),
        )
        ..body.addAll(buildSpecs(spec));

      for (final import in spec.additionalImports) {
        builder.directives.add(Directive.import(import));
      }
    });

    return _dartFormatter.format('${library.accept(DartEmitter())}');
  }

  List<Spec> buildSpecs(DartEdgeClientLibrarySpec spec) {
    return <Spec>[_clientClass(spec)];
  }

  Class _clientClass(DartEdgeClientLibrarySpec spec) {
    return Class((builder) {
      builder
        ..modifier = ClassModifier.final$
        ..name = spec.className
        ..extend = refer('DartEdgeGeneratedClientBase')
        ..constructors.add(_clientConstructor())
        ..methods.addAll(spec.operations.map(_operationMethod));
    });
  }

  Constructor _clientConstructor() {
    return Constructor((builder) {
      builder.optionalParameters.addAll([
        _superParameter('baseUri', required: true),
        _superParameter('transport', required: true),
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
          if (bodyEncoder != null) 'encoder': bodyEncoder,
        },
        <Reference>[refer(operation.bodyType!)],
      );
    }

    return arguments;
  }
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
      if (encode != null) 'encoder': encode,
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

final _dartFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

String _lowerCamel(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toLowerCase()}${value.substring(1)}';
}
