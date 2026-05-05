part of '../bluetooth_code_emitter.dart';

String _descriptorMemberName(
  _CharacteristicEntry entry,
  BluetoothGattDescriptorDefinition descriptor,
) {
  return '${entry.memberName}${_pascalCase(descriptor.id)}Descriptor';
}

String _descriptorPathName(
  _CharacteristicEntry entry,
  BluetoothGattDescriptorDefinition descriptor,
) {
  return '${_lowerFirst(entry.memberName)}${_pascalCase(descriptor.id)}DescriptorPath';
}

String _dedupe(String value, Map<String, int> used) {
  final count = used[value] ?? 0;
  used[value] = count + 1;
  return count == 0 ? value : '$value${count + 1}';
}

String _fileStem(String className) {
  final words = _words(className);
  if (words.isEmpty) {
    return 'generated_bluetooth';
  }
  return words.map((word) => word.toLowerCase()).join('_');
}

String _camelCase(String value) {
  final pascal = _pascalCase(value);
  return _lowerFirst(pascal);
}

String _pascalCase(String value) {
  final words = _words(value);
  if (words.isEmpty) {
    return 'Generated';
  }
  return words.map((word) {
    final lower = word.toLowerCase();
    return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
  }).join();
}

String _lowerFirst(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value.substring(0, 1).toLowerCase()}${value.substring(1)}';
}

List<String> _words(String value) {
  final matches = RegExp(
    r'[A-Z]+(?=[A-Z][a-z0-9]|\b)|[A-Z]?[a-z0-9]+',
  ).allMatches(value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' '));
  return [for (final match in matches) match.group(0)!];
}

String _escape(String value) {
  return value.replaceAll('\\', r'\\').replaceAll("'", r"\'");
}

void _validateClassName(String value, {required String parameterName}) {
  final classNamePattern = RegExp(r'^[A-Z][A-Za-z0-9]*$');
  if (!classNamePattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      parameterName,
      'Expected an UpperCamelCase Dart class name.',
    );
  }
}

String _format(String source) {
  return _dartFormatter.format(source);
}

final _dartFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);
