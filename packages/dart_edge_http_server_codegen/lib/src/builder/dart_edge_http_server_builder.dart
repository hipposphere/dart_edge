import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:source_gen/source_gen.dart';

import '../http_server/dart_edge_http_server_generator.dart';

const _typedJsonRouteChecker = TypeChecker.typeNamedLiterally('TypedJsonRoute');
const _routeBodyChecker = TypeChecker.typeNamedLiterally('RouteBody');
const _pathParamChecker = TypeChecker.typeNamedLiterally('PathParam');
const _queryParamChecker = TypeChecker.typeNamedLiterally('QueryParam');
const _headerParamChecker = TypeChecker.typeNamedLiterally('HeaderParam');
const _successResponseChecker = TypeChecker.typeNamedLiterally(
  'SuccessResponse',
);
const _routeErrorResponseChecker = TypeChecker.typeNamedLiterally(
  'RouteErrorResponse',
);

/// Turns `@TypedJsonRoute` top-level functions into Dart Edge route artifacts.
final class DartEdgeHttpServerBuilderGenerator extends Generator {
  const DartEdgeHttpServerBuilderGenerator(this.options);

  final BuilderOptions options;

  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final annotatedRoutes = library.annotatedWith(
      _typedJsonRouteChecker,
      throwOnUnresolved: false,
    );
    if (annotatedRoutes.isEmpty) {
      return null;
    }

    final routes = <DartEdgeHttpRouteSpec>[];
    final schemas = <String, JsonSchema>{};
    final codecs = <String, DartEdgeRuntimeCodecSpec>{};
    final additionalImports = <String>{};

    for (final annotatedRoute in annotatedRoutes) {
      final function = annotatedRoute.element;
      if (function is! TopLevelFunctionElement) {
        throw InvalidGenerationSourceError(
          '@TypedJsonRoute can only be used on top-level functions.',
          element: function,
        );
      }

      final route = _buildRoute(function, annotatedRoute.annotation);
      routes.add(route.spec);
      additionalImports.addAll(route.additionalImports);

      for (final schema in route.schemas) {
        if (schema.id case final id?) {
          schemas.putIfAbsent(id, () => schema);
        }
      }

      for (final codec in route.codecs) {
        codecs.putIfAbsent(codec.schemaId, () => codec);
      }
    }

    final clientClassName = options.config['client_class_name'];

    return const DartEdgeHttpServerGenerator().generatePart(
      DartEdgeHttpServerLibrarySpec(
        routes: routes,
        schemas: schemas.values.toList(growable: false),
        codecs: codecs.values.toList(growable: false),
        additionalImports: additionalImports.toList(growable: false),
        clientClassName: clientClassName is String && clientClassName.isNotEmpty
            ? clientClassName
            : null,
      ),
    );
  }
}

_RouteBuildResult _buildRoute(
  TopLevelFunctionElement function,
  ConstantReader routeAnnotation,
) {
  final operationId = routeAnnotation.read('operationId').stringValue;
  final methodName = _enumName(routeAnnotation.read('method'));
  final method = _httpMethod(methodName);
  final path = routeAnnotation.read('path').stringValue;
  final summary = routeAnnotation.read('summary').isNull
      ? null
      : routeAnnotation.read('summary').stringValue;
  final tags = routeAnnotation
      .read('tags')
      .listValue
      .map((value) => value.toStringValue()!)
      .toList(growable: false);
  final deprecated = routeAnnotation.read('deprecated').boolValue;

  final params = <_NamedField>[];
  final query = <_NamedField>[];
  final headers = <_NamedField>[];
  _TypedPart? body;

  for (final parameter in function.formalParameters) {
    final pathParam = _firstAnnotation(_pathParamChecker, parameter);
    if (pathParam != null) {
      params.add(
        _NamedField(
          name: _annotationString(pathParam, 'name') ?? parameter.displayName,
          type: parameter.type,
          required: parameter.isRequired,
        ),
      );
      continue;
    }

    final queryParam = _firstAnnotation(_queryParamChecker, parameter);
    if (queryParam != null) {
      query.add(
        _NamedField(
          name: _annotationString(queryParam, 'name') ?? parameter.displayName,
          type: parameter.type,
          required: parameter.isRequired,
        ),
      );
      continue;
    }

    final headerParam = _firstAnnotation(_headerParamChecker, parameter);
    if (headerParam != null) {
      headers.add(
        _NamedField(
          name: ConstantReader(headerParam).read('name').stringValue,
          type: parameter.type,
          required: parameter.isRequired,
        ),
      );
      continue;
    }

    final routeBody = _firstAnnotation(_routeBodyChecker, parameter);
    if (routeBody != null) {
      body = _TypedPart(
        schemaId: _schemaId(parameter.type),
        dartType: _dartType(parameter.type),
        contentType: ConstantReader(routeBody).read('contentType').stringValue,
        type: parameter.type,
      );
    }
  }

  final success = _successResponse(function);
  final returnType = _successType(function.returnType);
  final successPart = _TypedPart(
    schemaId: _schemaId(returnType),
    dartType: _dartType(returnType),
    contentType: success.contentType,
    type: returnType,
  );

  final routeClassName = '${_upperCamel(operationId)}Route';
  final routeSchemas = <JsonSchema>[];
  final routeCodecs = <DartEdgeRuntimeCodecSpec>[];
  final additionalImports = <String>{};

  JsonSchemaRef<Object?>? paramsRef;
  JsonSchemaRef<Object?>? queryRef;
  JsonSchemaRef<Object?>? headersRef;

  if (params.isNotEmpty) {
    final id = '${_upperCamel(operationId)}Params';
    paramsRef = JsonSchemaRef<Object?>(id);
    routeSchemas.add(_objectSchema(id, params));
  }
  if (query.isNotEmpty) {
    final id = '${_upperCamel(operationId)}Query';
    queryRef = JsonSchemaRef<Object?>(id);
    routeSchemas.add(_objectSchema(id, query));
  }
  if (headers.isNotEmpty) {
    final id = '${_upperCamel(operationId)}Headers';
    headersRef = JsonSchemaRef<Object?>(id);
    routeSchemas.add(_objectSchema(id, headers));
  }

  RequestBody? requestBody;
  if (body case final body?) {
    requestBody = RequestBody.json<Object?>(
      ref: JsonSchemaRef<Object?>(body.schemaId),
    );
    routeSchemas.add(_schemaForType(body.type, body.schemaId));
    routeCodecs.add(
      DartEdgeRuntimeCodecSpec(
        schemaId: body.schemaId,
        dartType: body.dartType,
      ),
    );
    _addImport(additionalImports, body.type);
  }

  routeSchemas.add(_schemaForType(successPart.type, successPart.schemaId));
  routeCodecs.add(
    DartEdgeRuntimeCodecSpec(
      schemaId: successPart.schemaId,
      dartType: successPart.dartType,
    ),
  );
  _addImport(additionalImports, successPart.type);

  return _RouteBuildResult(
    spec: DartEdgeHttpRouteSpec(
      routeClassName: routeClassName,
      contract: RouteContract(
        method: method,
        path: path,
        options: RouteOptions(
          operationId: operationId,
          summary: summary,
          tags: tags,
          deprecated: deprecated,
          params: paramsRef,
          query: queryRef,
          headers: headersRef,
          body: requestBody,
          success: ResponseSpec.json<Object?>(
            status: success.status,
            ref: JsonSchemaRef<Object?>(successPart.schemaId),
          ),
          errors: _errorResponses(function),
        ),
      ),
      successType: successPart.dartType,
      paramsType: params.isEmpty ? null : 'Map<String, Object?>',
      queryType: query.isEmpty ? null : 'Map<String, Object?>',
      headersType: headers.isEmpty ? null : 'Map<String, Object?>',
      bodyType: body?.dartType,
    ),
    schemas: routeSchemas,
    codecs: routeCodecs,
    additionalImports: additionalImports,
  );
}

JsonSchema _objectSchema(String id, List<_NamedField> fields) {
  return JsonSchema.object(
    ref: JsonSchemaRef<Object?>(id),
    nullable: false,
    properties: <String, JsonSchema>{
      for (final field in fields) field.name: _schemaForFieldType(field.type),
    },
    required: [
      for (final field in fields)
        if (field.required) field.name,
    ],
    additionalProperties: false,
  );
}

JsonSchema _schemaForType(DartType type, String id) {
  final baseType = _unwrapFuture(type);
  if (baseType is! InterfaceType || _isCoreType(baseType)) {
    return _schemaForFieldType(baseType, ref: JsonSchemaRef<Object?>(id));
  }

  final properties = <String, JsonSchema>{};
  final required = <String>[];
  for (final field in baseType.element.fields) {
    if (field.isStatic || field.isPrivate) {
      continue;
    }
    properties[field.displayName] = _schemaForFieldType(field.type);
    if (field.type.nullabilitySuffix != NullabilitySuffix.question) {
      required.add(field.displayName);
    }
  }

  if (properties.isEmpty) {
    return JsonSchema.any(ref: JsonSchemaRef<Object?>(id));
  }

  return JsonSchema.object(
    ref: JsonSchemaRef<Object?>(id),
    nullable: baseType.nullabilitySuffix == NullabilitySuffix.question,
    properties: properties,
    required: required,
    additionalProperties: false,
  );
}

JsonSchema _schemaForFieldType(DartType type, {JsonSchemaRef<Object?>? ref}) {
  final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
  final unwrapped = _unwrapFuture(type);
  if (unwrapped is InterfaceType) {
    final elementName = unwrapped.element.name;
    if (elementName == 'String') {
      return JsonSchema.string(ref: ref, nullable: nullable);
    }
    if (elementName == 'int') {
      return JsonSchema.integer(ref: ref, nullable: nullable);
    }
    if (elementName == 'double' || elementName == 'num') {
      return JsonSchema.number(ref: ref, nullable: nullable);
    }
    if (elementName == 'bool') {
      return JsonSchema.boolean(ref: ref, nullable: nullable);
    }
    if (elementName == 'List' && unwrapped.typeArguments.isNotEmpty) {
      return JsonSchema.array(
        ref: ref,
        nullable: nullable,
        items: _schemaForFieldType(unwrapped.typeArguments.single),
      );
    }
    if (!_isCoreType(unwrapped)) {
      return JsonSchema.ref(_schemaId(unwrapped));
    }
  }
  return JsonSchema.any(ref: ref);
}

_SuccessSpec _successResponse(TopLevelFunctionElement function) {
  final annotation = _firstAnnotation(_successResponseChecker, function);
  if (annotation == null) {
    return const _SuccessSpec(status: 200, contentType: 'application/json');
  }

  final reader = ConstantReader(annotation);
  return _SuccessSpec(
    status: reader.read('status').intValue,
    contentType: reader.read('contentType').stringValue,
  );
}

List<ErrorResponse> _errorResponses(TopLevelFunctionElement function) {
  return _routeErrorResponseChecker
      .annotationsOf(function, throwOnUnresolved: false)
      .map((annotation) {
        final reader = ConstantReader(annotation);
        final code = reader.read('code');
        return ErrorResponse(
          status: reader.read('status').intValue,
          code: code.isNull ? null : code.stringValue,
        );
      })
      .toList(growable: false);
}

DartObject? _firstAnnotation(TypeChecker checker, Element element) {
  return checker.firstAnnotationOf(element, throwOnUnresolved: false);
}

String? _annotationString(DartObject annotation, String fieldName) {
  final value = ConstantReader(annotation).read(fieldName);
  return value.isNull ? null : value.stringValue;
}

HttpMethod _httpMethod(String name) {
  return switch (name) {
    'get' => HttpMethod.get,
    'post' => HttpMethod.post,
    'put' => HttpMethod.put,
    'patch' => HttpMethod.patch,
    'delete' => HttpMethod.delete,
    'head' => HttpMethod.head,
    'options' => HttpMethod.options,
    _ => throw InvalidGenerationSourceError('Unsupported HTTP method $name.'),
  };
}

String _enumName(ConstantReader reader) {
  final accessor = reader.revive().accessor;
  return accessor.contains('.') ? accessor.split('.').last : accessor;
}

DartType _successType(DartType returnType) {
  final unwrapped = _unwrapFuture(returnType);
  if (unwrapped is InterfaceType &&
      unwrapped.element.name == 'FutureOr' &&
      unwrapped.typeArguments.isNotEmpty) {
    return unwrapped.typeArguments.single;
  }
  return unwrapped;
}

DartType _unwrapFuture(DartType type) {
  if (type is InterfaceType &&
      type.element.name == 'Future' &&
      type.typeArguments.isNotEmpty) {
    return type.typeArguments.single;
  }
  return type;
}

String _schemaId(DartType type) => _dartType(_unwrapFuture(type));

String _dartType(DartType type) {
  final display = type.getDisplayString();
  return display.endsWith('?')
      ? display.substring(0, display.length - 1)
      : display;
}

bool _isCoreType(InterfaceType type) {
  final libraryUri = type.element.library.uri.toString();
  return libraryUri == 'dart:core';
}

void _addImport(Set<String> imports, DartType type) {
  final unwrapped = _unwrapFuture(type);
  if (unwrapped is! InterfaceType || _isCoreType(unwrapped)) {
    return;
  }

  final sourceUri = unwrapped.element.library.uri;
  if (sourceUri.isScheme('dart')) {
    return;
  }
  imports.add(sourceUri.toString());
}

String _upperCamel(String value) {
  final parts = value
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'Generated';
  }
  return parts
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

final class _RouteBuildResult {
  const _RouteBuildResult({
    required this.spec,
    required this.schemas,
    required this.codecs,
    required this.additionalImports,
  });

  final DartEdgeHttpRouteSpec spec;
  final List<JsonSchema> schemas;
  final List<DartEdgeRuntimeCodecSpec> codecs;
  final Set<String> additionalImports;
}

final class _TypedPart {
  const _TypedPart({
    required this.schemaId,
    required this.dartType,
    required this.contentType,
    required this.type,
  });

  final String schemaId;
  final String dartType;
  final String contentType;
  final DartType type;
}

final class _NamedField {
  const _NamedField({
    required this.name,
    required this.type,
    required this.required,
  });

  final String name;
  final DartType type;
  final bool required;
}

final class _SuccessSpec {
  const _SuccessSpec({required this.status, required this.contentType});

  final int status;
  final String contentType;
}
