part of '../bluetooth_code_emitter.dart';

String _emitServerLibrary(
  BluetoothGattApplication application, {
  required String className,
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
          'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart',
        ),
      )
      ..directives.addAll(_codecPackageImports(application))
      ..directives.addAll(_codecRelativeImports(application))
      ..body.add(_serverClass(application, className, services))
      ..body.add(
        _serverRawClass(
          application,
          '${className}Raw',
          _characteristics(application),
        ),
      )
      ..body.addAll(_serverServiceClasses(services));
  });

  return '${library.accept(DartEmitter())}';
}

Class _serverClass(
  BluetoothGattApplication application,
  String className,
  List<_ServiceEntry> services,
) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = className
      ..constructors.add(_serverConstructor(className, services))
      ..fields.add(
        Field((field) {
          field
            ..modifier = FieldModifier.final$
            ..type = refer('DartEdgeBluetoothServer')
            ..name = 'server';
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
      );
  });
}

Constructor _serverConstructor(String className, List<_ServiceEntry> services) {
  return Constructor((builder) {
    builder
      ..requiredParameters.add(
        Parameter((parameter) {
          parameter
            ..toThis = true
            ..name = 'server';
        }),
      )
      ..initializers.add(Code('raw = ${className}Raw._(server)'))
      ..initializers.addAll(
        services.map(
          (service) =>
              Code('${service.memberName} = ${service.className}._(server)'),
        ),
      );
  });
}

Class _serverRawClass(
  BluetoothGattApplication application,
  String className,
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
            ..constant = true
            ..name = '_'
            ..requiredParameters.add(
              Parameter((parameter) {
                parameter
                  ..toThis = true
                  ..name = 'server';
              }),
            );
        }),
      )
      ..fields.add(
        Field((field) {
          field
            ..modifier = FieldModifier.final$
            ..type = refer('DartEdgeBluetoothServer')
            ..name = 'server';
        }),
      )
      ..fields.addAll(_pathConstants(application, serviceScoped: serviceScoped))
      ..methods.addAll(_serverMembers(entries));
  });
}

Iterable<Method> _serverMembers(List<_CharacteristicEntry> entries) {
  return <Method>[
    for (final entry in entries) ...[
      Method((builder) {
        builder
          ..returns = refer('Future<void>')
          ..name = 'set${entry.memberName}'
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
                ..name = 'notify'
                ..defaultTo = const Code('false');
            }),
          )
          ..body = Code(
            'return server.setCharacteristicValue(${entry.pathName}, value, notify: notify);',
          );
      }),
      if (entry.characteristic.read.enabled) ...[
        Method((builder) {
          builder
            ..returns = refer('Future<Uint8List>')
            ..name = 'read${entry.memberName}'
            ..body = Code(
              'return server.readCharacteristicValue(${entry.pathName});',
            );
        }),
        Method((builder) {
          builder
            ..type = MethodType.getter
            ..returns = refer('Stream<BluetoothCharacteristicReadEvent>')
            ..name = '${_lowerFirst(entry.memberName)}ReadEvents'
            ..body = Code(
              'return server.characteristicReadEvents.where((event) => _is${entry.memberName}Path(event.path));',
            );
        }),
      ],
      if (entry.characteristic.write.enabled)
        Method((builder) {
          builder
            ..type = MethodType.getter
            ..returns = refer('Stream<BluetoothCharacteristicWriteEvent>')
            ..name = '${_lowerFirst(entry.memberName)}WriteEvents'
            ..body = Code(
              'return server.characteristicWriteEvents.where((event) => _is${entry.memberName}Path(event.path));',
            );
        }),
      if (entry.characteristic.notify.enabled)
        Method((builder) {
          builder
            ..type = MethodType.getter
            ..returns = refer(
              'Stream<BluetoothCharacteristicSubscriptionEvent>',
            )
            ..name = '${_lowerFirst(entry.memberName)}SubscriptionEvents'
            ..body = Code(
              'return server.subscriptionEvents.where((event) => _is${entry.memberName}Path(event.path));',
            );
        }),
      for (final descriptor in entry.characteristic.descriptors)
        ..._serverDescriptorMembers(entry, descriptor),
      _serverPathMatcher(entry),
    ],
  ];
}

Iterable<Method> _serverDescriptorMembers(
  _CharacteristicEntry entry,
  BluetoothGattDescriptorDefinition descriptor,
) {
  final descriptorBaseName = _descriptorMemberName(entry, descriptor);
  final descriptorPathName = _descriptorPathName(entry, descriptor);

  return <Method>[
    Method((builder) {
      builder
        ..returns = refer('Future<void>')
        ..name = 'set$descriptorBaseName'
        ..requiredParameters.add(
          Parameter((parameter) {
            parameter
              ..type = refer('Uint8List')
              ..name = 'value';
          }),
        )
        ..body = Code(
          'return server.setDescriptorValue($descriptorPathName, value);',
        );
    }),
    if (descriptor.read.enabled)
      Method((builder) {
        builder
          ..returns = refer('Future<Uint8List>')
          ..name = 'read$descriptorBaseName'
          ..body = Code(
            'return server.readDescriptorValue($descriptorPathName);',
          );
      }),
  ];
}

Method _serverPathMatcher(_CharacteristicEntry entry) {
  return Method((builder) {
    builder
      ..returns = refer('bool')
      ..name = '_is${entry.memberName}Path'
      ..requiredParameters.add(
        Parameter((parameter) {
          parameter
            ..type = refer('BluetoothGattCharacteristicPath')
            ..name = 'path';
        }),
      )
      ..lambda = true
      ..body = Code(
        "path.serviceId == '${_escape(entry.service.id)}' && path.characteristicId == '${_escape(entry.characteristic.id)}'",
      );
  });
}

Iterable<Class> _serverServiceClasses(List<_ServiceEntry> services) sync* {
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
                    ..type = refer('DartEdgeBluetoothServer')
                    ..name = 'server';
                }),
              )
              ..initializers.add(
                Code('raw = ${service.className}Raw._(server)'),
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
          _serverTypedMembers(_serviceCharacteristics(service.service)),
        );
    });
    yield _serverRawClass(
      serviceApp,
      '${service.className}Raw',
      _serviceCharacteristics(service.service),
      serviceScoped: true,
    );
  }
}

Iterable<Method> _serverTypedMembers(List<_CharacteristicEntry> entries) {
  return <Method>[
    for (final entry in entries)
      if (entry.characteristic.codec case final codec?) ...[
        Method((builder) {
          builder
            ..returns = refer('Future<void>')
            ..name = 'set${entry.memberName}'
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
                  ..name = 'notify'
                  ..defaultTo = const Code('false');
              }),
            )
            ..body = Code('''
final bytes = ${codec.encodeExpression};
return raw.set${entry.memberName}(bytes, notify: notify);
''');
        }),
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
              ..type = MethodType.getter
              ..returns = refer('Stream<${codec.dartType}>')
              ..name = '${_lowerFirst(entry.memberName)}WriteValues'
              ..body = Code('''
return raw.${_lowerFirst(entry.memberName)}WriteEvents.map((event) {
  final value = event.value;
  return ${codec.decodeExpression};
});
''');
          }),
      ],
  ];
}
