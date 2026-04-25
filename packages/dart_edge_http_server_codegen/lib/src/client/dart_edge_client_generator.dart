import 'package:code_builder/code_builder.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_style/dart_style.dart';

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
    required this.contract,
    required this.successType,
    this.methodName,
    this.paramsType,
    this.queryType,
    this.headersType,
    this.bodyType,
  });

  final RouteContract contract;
  final String successType;
  final String? methodName;
  final String? paramsType;
  final String? queryType;
  final String? headersType;
  final String? bodyType;

  String get resolvedMethodName =>
      methodName ?? _lowerCamel(contract.options.operationId!);
}

/// Emits Dart source for an HTTP client backed by normalized route contracts.
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
          'codecs',
          defaultTo: refer(
            'DartEdgeClientCodecRegistry',
          ).property('empty').code,
        ),
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
    final contract = operation.contract;
    final arguments = <String, Expression>{
      'method': refer('HttpMethod').property(contract.method.name),
      'pathTemplate': literalString(contract.path),
      'successStatus': literalNum(contract.responses.success.status),
      'successContentType': literalString(
        contract.responses.success.contentType,
      ),
    };

    if (contract.responses.success.ref case final ref?) {
      arguments['successSchemaId'] = literalString(ref.id);
    }
    if (contract.options.params case final ref?) {
      arguments
        ..['paramsSchemaId'] = literalString(ref.id)
        ..['params'] = refer('params');
    }
    if (contract.options.query case final ref?) {
      arguments
        ..['querySchemaId'] = literalString(ref.id)
        ..['query'] = refer('query');
    }
    if (contract.options.headers case final ref?) {
      arguments
        ..['headersSchemaId'] = literalString(ref.id)
        ..['headers'] = refer('headers');
    }
    if (contract.options.body case final body?) {
      arguments['requestContentType'] = literalString(body.contentType);
      if (body.ref case final ref?) {
        arguments['bodySchemaId'] = literalString(ref.id);
      }
      arguments['body'] = refer('body');
    }

    return refer(
      'invoke',
    ).call(const <Expression>[], arguments, [refer(operation.successType)]);
  }
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
