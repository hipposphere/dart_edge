part of '../dart_schema_emitter.dart';

Enum _enumSpec(IntrospectedEnum value) {
  final className = _enumClassName(value.name);
  final valueNameCounts = <String, int>{};
  String enumValueName(String label) {
    final baseName = _enumValueName(label);
    final count = valueNameCounts.update(
      baseName,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    return count == 0 ? baseName : '$baseName$count';
  }

  return Enum((builder) {
    builder
      ..name = className
      ..values.addAll([
        for (final label in value.values)
          EnumValue((enumValue) {
            enumValue
              ..name = enumValueName(label)
              ..arguments.add(literalString(label));
          }),
      ])
      ..constructors.add(
        Constructor((constructor) {
          constructor
            ..constant = true
            ..requiredParameters.add(
              Parameter((parameter) {
                parameter
                  ..name = 'value'
                  ..toThis = true;
              }),
            );
        }),
      )
      ..fields.add(_instanceFinalField('value', refer('String')))
      ..methods.add(
        Method((method) {
          method
            ..static = true
            ..returns = refer(className)
            ..name = 'fromDatabase'
            ..requiredParameters.add(_typedParameter('value', refer('Object?')))
            ..body = Code('''
final text = value as String;
for (final entry in values) {
  if (entry.value == text) {
    return entry;
  }
}
throw ArgumentError.value(value, 'value', 'Unknown $className database value.');
''');
        }),
      )
      ..methods.add(
        Method((method) {
          method
            ..annotations.add(refer('override'))
            ..returns = refer('String')
            ..name = 'toString'
            ..lambda = true
            ..body = refer('value').code;
        }),
      );
  });
}

List<_EnumImportSpec> _tableEnumImports(
  IntrospectedTable table,
  _SchemaGroup group,
  List<_SchemaGroup> schemaGroups,
) {
  final enumKeys = table.columns
      .where((column) => column.enumName != null)
      .map(
        (column) =>
            (schema: _schemaName(column.enumSchema), name: column.enumName!),
      )
      .toSet();

  return [
    for (final enumGroup in schemaGroups)
      for (final value in enumGroup.enums)
        if (enumKeys.contains((
          schema: _schemaName(value.schema),
          name: value.name,
        )))
          _EnumImportSpec(
            path: enumGroup.schemaName == group.schemaName
                ? '../enums/${_enumFileName(value)}'
                : '../../${enumGroup.folderName}/enums/${_enumFileName(value)}',
          ),
  ];
}

final class _EnumImportSpec {
  const _EnumImportSpec({required this.path});

  final String path;
}
