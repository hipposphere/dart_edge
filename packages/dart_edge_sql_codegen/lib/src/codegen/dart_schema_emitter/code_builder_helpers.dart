part of '../dart_schema_emitter.dart';

Method _toStringMethod(String className, Iterable<String> fieldNames) {
  final description = fieldNames.map((name) => '$name: \$$name').join(', ');
  return Method((method) {
    method
      ..annotations.add(refer('override'))
      ..returns = refer('String')
      ..name = 'toString'
      ..lambda = true
      ..body = Code("'$className($description)'");
  });
}

Method _getter(String name, Reference returns, Expression body) {
  return Method((method) {
    method
      ..annotations.add(refer('override'))
      ..type = MethodType.getter
      ..returns = returns
      ..name = name
      ..lambda = true
      ..body = body.code;
  });
}

Method _encodeMethod(String name, String valueType) {
  return Method((method) {
    method
      ..annotations.add(refer('override'))
      ..returns = _mapOf(refer('String'), refer('Object?'))
      ..name = name
      ..requiredParameters.add(_typedParameter('value', refer(valueType)))
      ..lambda = true
      ..body = refer('value').property('toColumns').call(const []).code;
  });
}

Constructor _fieldConstructor(Iterable<Parameter> parameters) {
  return Constructor((constructor) {
    constructor
      ..constant = true
      ..optionalParameters.addAll(parameters);
  });
}

Constructor _privateConstConstructor() {
  return Constructor((constructor) {
    constructor
      ..constant = true
      ..name = '_';
  });
}

Field _staticConstField({
  required String name,
  Reference? type,
  required Expression assignment,
}) {
  return Field((field) {
    field
      ..static = true
      ..modifier = FieldModifier.constant
      ..type = type
      ..name = name
      ..assignment = assignment.code;
  });
}

Field _instanceFinalField(String name, Reference type) {
  return Field((field) {
    field
      ..modifier = FieldModifier.final$
      ..type = type
      ..name = name;
  });
}

Parameter _fieldParameter(
  String name, {
  bool required = false,
  Code? defaultTo,
}) {
  return Parameter((parameter) {
    parameter
      ..name = name
      ..named = true
      ..toThis = true
      ..required = required
      ..defaultTo = defaultTo;
  });
}

Parameter _typedParameter(String name, Reference type) {
  return Parameter((parameter) {
    parameter
      ..name = name
      ..type = type;
  });
}

Parameter _namedParameter(String name, {Reference? type, Code? defaultTo}) {
  return Parameter((parameter) {
    parameter
      ..name = name
      ..named = true
      ..type = type
      ..defaultTo = defaultTo;
  });
}

Expression _jsonLookup(String key) {
  return CodeExpression(Code("json['${_escapeLiteral(key)}']"));
}

String _code(Spec spec) => '${spec.accept(DartEmitter())}';

String _typeCode(Reference reference) => '${reference.accept(DartEmitter())}';

String _format(Library library) {
  return _dartFormatter.format('${library.accept(DartEmitter())}');
}
