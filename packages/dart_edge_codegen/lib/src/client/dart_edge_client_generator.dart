import 'dart:convert';

import 'package:dart_edge_runtime/dart_edge_runtime.dart';

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
      methodName ?? _lowerCamel(contract.operationId);
}

/// Emits Dart source for an HTTP client backed by normalized route contracts.
final class DartEdgeClientGenerator {
  const DartEdgeClientGenerator();

  String generate(DartEdgeClientLibrarySpec spec) {
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..writeln()
      ..writeln("import 'package:dart_edge_codegen/dart_edge_codegen.dart';")
      ..writeln("import 'package:dart_edge_runtime/dart_edge_runtime.dart';");

    for (final import in spec.additionalImports) {
      buffer.writeln('import ${jsonEncode(import)};');
    }

    buffer
      ..writeln()
      ..writeln(
        'final class ${spec.className} extends DartEdgeGeneratedClientBase {',
      )
      ..writeln('  ${spec.className}({')
      ..writeln('    required super.baseUri,')
      ..writeln('    required super.transport,')
      ..writeln('    super.codecs = DartEdgeClientCodecRegistry.empty,')
      ..writeln('    super.defaultHeaders = const <String, String>{},')
      ..writeln('  });')
      ..writeln();

    for (final operation in spec.operations) {
      _writeOperation(buffer, operation);
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  void _writeOperation(StringBuffer buffer, DartEdgeClientOperation operation) {
    final arguments = <String>[
      if (operation.paramsType case final type?) 'required $type params',
      if (operation.queryType case final type?) '$type? query',
      if (operation.headersType case final type?) '$type? headers',
      if (operation.bodyType case final type?) 'required $type body',
    ];

    buffer..writeln(
      '  Future<${operation.successType}> ${operation.resolvedMethodName}({',
    );

    if (arguments.isEmpty) {
      buffer.writeln('  }) {');
    } else {
      for (final argument in arguments) {
        buffer.writeln('    $argument,');
      }
      buffer.writeln('  }) {');
    }

    buffer
      ..writeln('    return invoke<${operation.successType}>(')
      ..writeln('      method: HttpMethod.${operation.contract.method.name},')
      ..writeln('      pathTemplate: ${_literal(operation.contract.path)},')
      ..writeln(
        '      successStatus: ${operation.contract.responses.success.status},',
      )
      ..writeln(
        '      successContentType: ${_literal(operation.contract.responses.success.contentType)},',
      );

    if (operation.contract.responses.success.ref case final ref?) {
      buffer.writeln('      successSchemaId: ${_literal(ref.id)},');
    }
    if (operation.contract.params case final ref?) {
      buffer
        ..writeln('      paramsSchemaId: ${_literal(ref.id)},')
        ..writeln('      params: params,');
    }
    if (operation.contract.query case final ref?) {
      buffer
        ..writeln('      querySchemaId: ${_literal(ref.id)},')
        ..writeln('      query: query,');
    }
    if (operation.contract.headers case final ref?) {
      buffer
        ..writeln('      headersSchemaId: ${_literal(ref.id)},')
        ..writeln('      headers: headers,');
    }
    if (operation.contract.body case final body?) {
      buffer
        ..writeln('      requestContentType: ${_literal(body.contentType)},');
      if (body.ref case final ref?) {
        buffer.writeln('      bodySchemaId: ${_literal(ref.id)},');
      }
      buffer.writeln('      body: body,');
    }

    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln();
  }
}

String _literal(String value) => jsonEncode(value);

String _lowerCamel(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toLowerCase()}${value.substring(1)}';
}
