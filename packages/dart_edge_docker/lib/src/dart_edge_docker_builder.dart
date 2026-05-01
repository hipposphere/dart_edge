import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;

final class DartEdgeDockerBuilder implements Builder {
  DartEdgeDockerBuilder(this.options);

  final BuilderOptions options;

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.dockerfile', '.dockerignore', '.docker_build.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final source = await buildStep.readAsString(buildStep.inputId);
    final configs = _parseConfigs(source);
    if (configs.isEmpty) {
      return;
    }
    if (configs.length > 1) {
      throw FormatException(
        'Only one DartEdgeDockerConfig is supported per Dart file: '
        '${buildStep.inputId}.',
      );
    }

    final config = configs.single;
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.dockerfile'),
      _dockerfile(config),
    );
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.dockerignore'),
      _dockerignore(config),
    );
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.docker_build.json'),
      _buildMetadata(buildStep.inputId, config),
    );
  }
}

final class _DockerConfig {
  const _DockerConfig({
    required this.imageName,
    required this.entrypoint,
    required this.executableName,
    required this.buildContext,
    required this.dartSdkImage,
    required this.runtimeImage,
    required this.workdir,
    required this.ports,
    required this.environment,
    required this.buildArgs,
    required this.labels,
    required this.extraFiles,
    required this.compileArgs,
    required this.runtimeArgs,
    required this.dockerignore,
    this.user,
  });

  final String imageName;
  final String entrypoint;
  final String executableName;
  final String buildContext;
  final String dartSdkImage;
  final String runtimeImage;
  final String workdir;
  final String? user;
  final List<int> ports;
  final Map<String, String> environment;
  final Map<String, String> buildArgs;
  final Map<String, String> labels;
  final List<String> extraFiles;
  final List<String> compileArgs;
  final List<String> runtimeArgs;
  final List<String> dockerignore;
}

List<_DockerConfig> _parseConfigs(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final configs = <_DockerConfig>[];

  for (final declaration in unit.declarations) {
    if (declaration is! TopLevelVariableDeclaration) {
      continue;
    }
    for (final variable in declaration.variables.variables) {
      final initializer = variable.initializer;
      if (initializer == null) {
        continue;
      }
      if (!_isDockerConfigExpression(initializer)) {
        continue;
      }
      configs.add(_configFromExpression(initializer));
    }
  }

  return configs;
}

bool _isDockerConfigExpression(Expression expression) {
  if (expression is InstanceCreationExpression) {
    final typeName = expression.constructorName.type.toSource();
    return typeName == 'DartEdgeDockerConfig' ||
        typeName.endsWith('.DartEdgeDockerConfig');
  }
  if (expression is MethodInvocation) {
    final target = expression.target;
    final name = target == null
        ? expression.methodName.name
        : '${target.toSource()}.${expression.methodName.name}';
    return name == 'DartEdgeDockerConfig' ||
        name.endsWith('.DartEdgeDockerConfig');
  }
  return false;
}

_DockerConfig _configFromExpression(Expression expression) {
  final args = <String, Expression>{};
  for (final argument in _argumentList(expression).arguments) {
    if (argument is NamedArgument) {
      args[argument.name.lexeme] = argument.argumentExpression;
    }
  }

  final imageName = _requiredString(args, 'imageName');
  final entrypoint = _requiredString(args, 'entrypoint');

  return _DockerConfig(
    imageName: imageName,
    entrypoint: entrypoint,
    executableName: _optionalString(args, 'executableName') ?? 'server',
    buildContext: _optionalString(args, 'buildContext') ?? '.',
    dartSdkImage: _optionalString(args, 'dartSdkImage') ?? 'dart:stable',
    runtimeImage:
        _optionalString(args, 'runtimeImage') ?? 'debian:bookworm-slim',
    workdir: _optionalString(args, 'workdir') ?? '/app',
    user: _optionalString(args, 'user'),
    ports: _intList(args['ports']),
    environment: _stringMap(args['environment']),
    buildArgs: _stringMap(args['buildArgs']),
    labels: _stringMap(args['labels']),
    extraFiles: _stringList(args['extraFiles']),
    compileArgs: _stringList(args['compileArgs']),
    runtimeArgs: _stringList(args['runtimeArgs']),
    dockerignore: _stringList(args['dockerignore']).ifEmpty(const <String>[
      '.dart_tool/',
      'build/',
      '.git/',
      '*.dockerfile',
      '*.docker_build.json',
    ]),
  );
}

ArgumentList _argumentList(Expression expression) {
  return switch (expression) {
    final InstanceCreationExpression expression => expression.argumentList,
    final MethodInvocation expression => expression.argumentList,
    _ => throw const FormatException(
      'DartEdgeDockerConfig must be a const constructor invocation.',
    ),
  };
}

String _dockerfile(_DockerConfig config) {
  final lines = <String>[
    '# GENERATED CODE - DO NOT MODIFY BY HAND.',
    '# Generated by package:dart_edge_docker.',
    '',
    for (final entry in config.buildArgs.entries)
      'ARG ${entry.key}=${_shell(entry.value)}',
    'ARG DART_SDK_IMAGE=${_shell(config.dartSdkImage)}',
    'FROM \${DART_SDK_IMAGE} AS build',
    'WORKDIR /app',
    'COPY pubspec.* ./',
    'COPY . .',
    'RUN dart pub get',
    'RUN mkdir -p /app/build && dart compile exe '
        '${_shell(config.entrypoint)} '
        '-o /app/build/${_shell(config.executableName)}'
        '${config.compileArgs.isEmpty ? '' : ' ${config.compileArgs.map(_shell).join(' ')}'}',
    '',
    'FROM ${config.runtimeImage}',
    'WORKDIR ${_shell(config.workdir)}',
    'COPY --from=build /app/build/ ./',
    for (final file in config.extraFiles)
      'COPY --from=build /app/${_shell(file)} ./'
          '${_shell(p.basename(file))}',
    if (config.labels.isNotEmpty)
      for (final entry in config.labels.entries)
        'LABEL ${entry.key}=${_shell(entry.value)}',
    if (config.environment.isNotEmpty)
      for (final entry in config.environment.entries)
        'ENV ${entry.key}=${_shell(entry.value)}',
    for (final port in config.ports) 'EXPOSE $port',
    if (config.user case final user?) 'USER ${_shell(user)}',
    'ENTRYPOINT ${jsonEncode(['./${config.executableName}', ...config.runtimeArgs])}',
    '',
  ];
  return lines.join('\n');
}

String _dockerignore(_DockerConfig config) {
  return [
    '# GENERATED CODE - DO NOT MODIFY BY HAND.',
    '# Generated by package:dart_edge_docker.',
    ...config.dockerignore,
    '',
  ].join('\n');
}

String _buildMetadata(AssetId input, _DockerConfig config) {
  final dockerfile = input.changeExtension('.dockerfile').path;
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({
    'imageName': config.imageName,
    'dockerfile': dockerfile,
    'buildContext': config.buildContext,
    'command': ['docker', 'build', '-t', config.imageName, '-f', dockerfile, config.buildContext],
  })}\n';
}

String _requiredString(Map<String, Expression> args, String name) {
  final value = _optionalString(args, name);
  if (value == null || value.isEmpty) {
    throw FormatException('DartEdgeDockerConfig.$name is required.');
  }
  return value;
}

String? _optionalString(Map<String, Expression> args, String name) {
  final expression = args[name];
  if (expression == null || expression is NullLiteral) {
    return null;
  }
  return _stringValue(expression);
}

String _stringValue(Expression expression) {
  if (expression is StringLiteral) {
    final value = expression.stringValue;
    if (value != null) {
      return value;
    }
  }
  throw const FormatException(
    'DartEdgeDockerConfig only supports string literals.',
  );
}

List<String> _stringList(Expression? expression) {
  if (expression == null) {
    return const <String>[];
  }
  if (expression is! ListLiteral) {
    throw const FormatException(
      'DartEdgeDockerConfig only supports list literals.',
    );
  }
  return [
    for (final element in expression.elements)
      if (element is Expression) _stringValue(element),
  ];
}

List<int> _intList(Expression? expression) {
  if (expression == null) {
    return const <int>[];
  }
  if (expression is! ListLiteral) {
    throw const FormatException(
      'DartEdgeDockerConfig only supports list literals.',
    );
  }
  return [
    for (final element in expression.elements)
      if (element is IntegerLiteral) element.value ?? 0,
  ];
}

Map<String, String> _stringMap(Expression? expression) {
  if (expression == null) {
    return const <String, String>{};
  }
  if (expression is! SetOrMapLiteral) {
    throw const FormatException(
      'DartEdgeDockerConfig only supports map literals.',
    );
  }

  return {
    for (final element in expression.elements)
      if (element is MapLiteralEntry)
        _stringValue(element.key): _stringValue(element.value),
  };
}

String _shell(String value) {
  if (RegExp(r'^[A-Za-z0-9_./:@+=-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", r"'\''")}'";
}

extension _ListIfEmpty<T> on List<T> {
  List<T> ifEmpty(List<T> fallback) => isEmpty ? fallback : this;
}
