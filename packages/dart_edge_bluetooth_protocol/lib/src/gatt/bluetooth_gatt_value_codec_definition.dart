final class BluetoothGattValueCodecDefinition {
  const BluetoothGattValueCodecDefinition({
    required this.dartType,
    required this.encodeExpression,
    required this.decodeExpression,
    this.imports = const <String>[],
  });

  const BluetoothGattValueCodecDefinition.binary({
    required String dartType,
    required String fromBytes,
    String toBytes = 'toBytes',
    List<String> imports = const <String>[],
  }) : this(
         dartType: dartType,
         encodeExpression: 'value.$toBytes()',
         decodeExpression: '$fromBytes(value)',
         imports: imports,
       );

  const BluetoothGattValueCodecDefinition.utf8String()
    : this(
        dartType: 'String',
        encodeExpression: 'Uint8List.fromList(utf8.encode(value))',
        decodeExpression: 'utf8.decode(value)',
        imports: const <String>['dart:convert'],
      );

  const BluetoothGattValueCodecDefinition.jsonObject({
    required String dartType,
    required String fromJson,
    String toJson = 'toJson',
  }) : this(
         dartType: dartType,
         encodeExpression:
             'Uint8List.fromList(utf8.encode(jsonEncode(value.$toJson())))',
         decodeExpression:
             '$fromJson(jsonDecode(utf8.decode(value)) as Map<String, Object?>)',
         imports: const <String>['dart:convert'],
       );

  /// Dart type exposed by generated typed helpers.
  final String dartType;

  /// Dart expression that converts a `value` variable from [dartType] to bytes.
  final String encodeExpression;

  /// Dart expression that converts a `value` variable from bytes to [dartType].
  final String decodeExpression;

  /// Extra imports required by [encodeExpression] or [decodeExpression].
  final List<String> imports;
}
