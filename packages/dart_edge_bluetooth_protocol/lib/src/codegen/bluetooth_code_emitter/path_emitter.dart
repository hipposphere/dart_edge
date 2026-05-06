part of '../bluetooth_code_emitter.dart';

Iterable<Field> _pathConstants(
  BluetoothGattApplication app, {
  bool serviceScoped = false,
}) {
  final entries = serviceScoped
      ? _serviceCharacteristics(app.services.single)
      : _characteristics(app);

  return <Field>[
    for (final entry in entries) ...[
      Field((builder) {
        builder
          ..static = true
          ..modifier = FieldModifier.constant
          ..name = entry.pathName
          ..assignment = refer('BluetoothGattCharacteristicPath').constInstance(
            const <Expression>[],
            {
              'serviceId': literalString(entry.service.id),
              'characteristicId': literalString(entry.characteristic.id),
            },
          ).code;
      }),
      for (final descriptor in entry.characteristic.descriptors)
        Field((builder) {
          builder
            ..static = true
            ..modifier = FieldModifier.constant
            ..name = _descriptorPathName(entry, descriptor)
            ..assignment = refer('BluetoothGattDescriptorPath').constInstance(
              const <Expression>[],
              {
                'serviceId': literalString(entry.service.id),
                'characteristicId': literalString(entry.characteristic.id),
                'descriptorId': literalString(descriptor.id),
              },
            ).code;
        }),
    ],
  ];
}
