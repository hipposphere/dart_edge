part of '../bluetooth_code_emitter.dart';

String _emitClientLibrary(
  BluetoothGattApplication application, {
  required String className,
  required String backendClassName,
}) {
  final services = _services(application, className);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.addAll(
        _dartImports(application, const ['dart:async', 'dart:typed_data']),
      )
      ..directives.add(
        Directive.import(
          'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart',
        ),
      )
      ..directives.addAll(_codecPackageImports(application))
      ..directives.addAll(_codecRelativeImports(application))
      ..body.add(
        _clientClass(application, className, backendClassName, services),
      )
      ..body.add(
        _clientRawClass(
          application,
          '${className}Raw',
          backendClassName,
          _characteristics(application),
        ),
      )
      ..body.addAll(
        _clientServiceClasses(
          services: services,
          backendClassName: backendClassName,
        ),
      );
  });

  return '${library.accept(DartEmitter())}';
}

Class _clientClass(
  BluetoothGattApplication application,
  String className,
  String backendClassName,
  List<_ServiceEntry> services,
) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = className
      ..constructors.add(
        _clientConstructor(className, backendClassName, services),
      )
      ..fields.add(
        Field((field) {
          field
            ..modifier = FieldModifier.final$
            ..type = refer(backendClassName)
            ..name = '_backend';
        }),
      )
      ..fields.add(
        Field((field) {
          field
            ..modifier = FieldModifier.final$
            ..type = refer('${className}Raw')
            ..name = 'raw';
        }),
      )
      ..fields.addAll(
        services.map(
          (service) => Field((field) {
            field
              ..modifier = FieldModifier.final$
              ..type = refer(service.className)
              ..name = service.memberName;
          }),
        ),
      )
      ..methods.add(_clientBackendMethod('connect'))
      ..methods.add(_clientBackendMethod('disconnect'));
  });
}

Constructor _clientConstructor(
  String className,
  String backendClassName,
  List<_ServiceEntry> services,
) {
  return Constructor((builder) {
    builder
      ..optionalParameters.add(
        Parameter((parameter) {
          parameter
            ..named = true
            ..required = true
            ..type = refer(backendClassName)
            ..name = 'backend';
        }),
      )
      ..initializers.add(Code('_backend = backend'))
      ..initializers.add(Code('raw = ${className}Raw._(backend)'))
      ..initializers.addAll(
        services.map(
          (service) =>
              Code('${service.memberName} = ${service.className}._(backend)'),
        ),
      );
  });
}

Class _clientRawClass(
  BluetoothGattApplication application,
  String className,
  String backendClassName,
  List<_CharacteristicEntry> entries, {
  bool serviceScoped = false,
}) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = className
      ..constructors.add(
        Constructor((constructor) {
          constructor
            ..name = '_'
            ..requiredParameters.add(
              Parameter((parameter) {
                parameter
                  ..type = refer(backendClassName)
                  ..name = 'backend';
              }),
            )
            ..initializers.add(const Code('_backend = backend'));
        }),
      )
      ..fields.add(
        Field((field) {
          field
            ..modifier = FieldModifier.final$
            ..type = refer(backendClassName)
            ..name = '_backend';
        }),
      )
      ..fields.addAll(_pathConstants(application, serviceScoped: serviceScoped))
      ..methods.addAll(_clientMembers(entries));
  });
}

Method _clientBackendMethod(String name) {
  return Method((builder) {
    builder
      ..returns = refer('Future<void>')
      ..name = name
      ..lambda = true
      ..body = Code('_backend.$name()');
  });
}

Iterable<Method> _clientMembers(List<_CharacteristicEntry> entries) {
  return <Method>[
    for (final entry in entries) ...[
      if (entry.characteristic.read.enabled)
        Method((builder) {
          builder
            ..returns = refer('Future<Uint8List>')
            ..name = 'read${entry.memberName}'
            ..body = Code(
              'return _backend.readCharacteristic(${entry.pathName});',
            );
        }),
      if (entry.characteristic.write.enabled)
        Method((builder) {
          builder
            ..returns = refer('Future<void>')
            ..name = 'write${entry.memberName}'
            ..requiredParameters.add(
              Parameter((parameter) {
                parameter
                  ..type = refer('Uint8List')
                  ..name = 'value';
              }),
            )
            ..optionalParameters.add(
              Parameter((parameter) {
                parameter
                  ..named = true
                  ..type = refer('bool')
                  ..name = 'withoutResponse'
                  ..defaultTo = const Code('false');
              }),
            )
            ..body = Code(
              'return _backend.writeCharacteristic(${entry.pathName}, value, withoutResponse: withoutResponse);',
            );
        }),
      if (entry.characteristic.notify.enabled)
        Method((builder) {
          builder
            ..returns = refer('Stream<Uint8List>')
            ..name = 'watch${entry.memberName}'
            ..body = Code(
              'return _backend.subscribeToCharacteristic(${entry.pathName});',
            );
        }),
      for (final descriptor in entry.characteristic.descriptors)
        ..._clientDescriptorMembers(entry, descriptor),
    ],
  ];
}

Iterable<Method> _clientDescriptorMembers(
  _CharacteristicEntry entry,
  BluetoothGattDescriptorDefinition descriptor,
) {
  final descriptorBaseName = _descriptorMemberName(entry, descriptor);
  final descriptorPathName = _descriptorPathName(entry, descriptor);

  return <Method>[
    if (descriptor.read.enabled)
      Method((builder) {
        builder
          ..returns = refer('Future<Uint8List>')
          ..name = 'read$descriptorBaseName'
          ..body = Code('return _backend.readDescriptor($descriptorPathName);');
      }),
    if (descriptor.write.enabled)
      Method((builder) {
        builder
          ..returns = refer('Future<void>')
          ..name = 'write$descriptorBaseName'
          ..requiredParameters.add(
            Parameter((parameter) {
              parameter
                ..type = refer('Uint8List')
                ..name = 'value';
            }),
          )
          ..body = Code(
            'return _backend.writeDescriptor($descriptorPathName, value);',
          );
      }),
  ];
}

Iterable<Class> _clientServiceClasses({
  required List<_ServiceEntry> services,
  required String backendClassName,
}) sync* {
  for (final service in services) {
    final serviceApp = BluetoothGattApplication(services: [service.service]);
    yield Class((builder) {
      builder
        ..modifier = ClassModifier.final$
        ..name = service.className
        ..constructors.add(
          Constructor((constructor) {
            constructor
              ..name = '_'
              ..requiredParameters.add(
                Parameter((parameter) {
                  parameter
                    ..type = refer(backendClassName)
                    ..name = 'backend';
                }),
              )
              ..initializers.add(
                Code('raw = ${service.className}Raw._(backend)'),
              );
          }),
        )
        ..fields.add(
          Field((field) {
            field
              ..modifier = FieldModifier.final$
              ..type = refer('${service.className}Raw')
              ..name = 'raw';
          }),
        )
        ..methods.addAll(
          _clientTypedMembers(_serviceCharacteristics(service.service)),
        );
    });
    yield _clientRawClass(
      serviceApp,
      '${service.className}Raw',
      backendClassName,
      _serviceCharacteristics(service.service),
      serviceScoped: true,
    );
  }
}

Iterable<Method> _clientTypedMembers(List<_CharacteristicEntry> entries) {
  return <Method>[
    for (final entry in entries)
      if (entry.characteristic.codec case final codec?) ...[
        if (entry.characteristic.read.enabled)
          Method((builder) {
            builder
              ..returns = refer('Future<${codec.dartType}>')
              ..name = 'read${entry.memberName}'
              ..modifier = MethodModifier.async
              ..body = Code('''
final value = await raw.read${entry.memberName}();
return ${codec.decodeExpression};
''');
          }),
        if (entry.characteristic.write.enabled)
          Method((builder) {
            builder
              ..returns = refer('Future<void>')
              ..name = 'write${entry.memberName}'
              ..requiredParameters.add(
                Parameter((parameter) {
                  parameter
                    ..type = refer(codec.dartType)
                    ..name = 'value';
                }),
              )
              ..optionalParameters.add(
                Parameter((parameter) {
                  parameter
                    ..named = true
                    ..type = refer('bool')
                    ..name = 'withoutResponse'
                    ..defaultTo = const Code('false');
                }),
              )
              ..body = Code('''
final bytes = ${codec.encodeExpression};
return raw.write${entry.memberName}(bytes, withoutResponse: withoutResponse);
''');
          }),
        if (entry.characteristic.notify.enabled)
          Method((builder) {
            builder
              ..returns = refer('Stream<${codec.dartType}>')
              ..name = 'watch${entry.memberName}'
              ..body = Code('''
return raw.watch${entry.memberName}().map((value) => ${codec.decodeExpression});
''');
          }),
      ],
  ];
}
