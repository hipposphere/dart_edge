part of '../dart_schema_emitter.dart';

Class _routinesClass(_SchemaGroup group) {
  final seenNames = <String, int>{};
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = group.routinesClassName
      ..constructors.add(_privateConstConstructor())
      ..fields.add(
        _staticConstField(
          name: 'routines',
          assignment: refer(
            group.routinesClassName,
          ).constInstanceNamed('_', const []),
        ),
      );

    for (final routine in group.routines) {
      final baseName = _schemaRoutineMemberName(routine.name);
      final count = (seenNames[baseName] ?? 0) + 1;
      seenNames[baseName] = count;
      final methodName = count == 1 ? baseName : '$baseName$count';
      builder.methods.add(_routineMethod(group, routine, methodName));
    }
  });
}

Method _routineMethod(
  _SchemaGroup group,
  IntrospectedRoutine routine,
  String methodName,
) {
  return Method((method) {
    method
      ..returns = _type('Future', [refer('SqlResult')])
      ..modifier = MethodModifier.async
      ..name = methodName
      ..requiredParameters.add(
        _typedParameter('executor', refer('SqlExecutor')),
      )
      ..optionalParameters.addAll([
        for (final parameter in routine.parameters)
          _namedParameter(
            _routineParameterMemberName(parameter.name),
            type: refer(parameter.dartType),
            required: true,
          ),
      ])
      ..body = Code(_routineMethodBody(group, routine));
  });
}

String _routineMethodBody(_SchemaGroup group, IntrospectedRoutine routine) {
  final statement = _routineSql(group, routine);
  final parameters = routine.parameters;
  final parameterMap = parameters.isEmpty
      ? '<String, Object?>{}'
      : '<String, Object?>{${parameters.map((parameter) {
          final name = _routineParameterMemberName(parameter.name);
          return "'${_escapeLiteral(name)}': $name";
        }).join(', ')}}';

  return '''
return executor.execute(
  SqlStatement.named(
    '${_escapeLiteral(statement)}',
    $parameterMap,
  ),
);
''';
}

String _routineSql(_SchemaGroup group, IntrospectedRoutine routine) {
  final qualifiedName =
      '"${_escapeSqlIdentifier(group.schemaName)}"."${_escapeSqlIdentifier(routine.name)}"';
  final arguments = routine.parameters
      .map((parameter) => '@${_routineParameterMemberName(parameter.name)}')
      .join(', ');

  return switch (routine.kind) {
    IntrospectedRoutineKind.procedure => 'CALL $qualifiedName($arguments)',
    IntrospectedRoutineKind.function when routine.returnsSet =>
      'SELECT * FROM $qualifiedName($arguments)',
    IntrospectedRoutineKind.function =>
      'SELECT $qualifiedName($arguments) AS value',
  };
}

String _routineParameterMemberName(String parameterName) {
  final memberName = _lowerCamel(parameterName);
  return _reservedRoutineParameterNames.contains(memberName)
      ? '${memberName}Parameter'
      : memberName;
}
