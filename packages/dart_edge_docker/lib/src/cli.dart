import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'docker_generator.dart';
import 'package_version.dart';

Future<int> runDartEdgeDocker(
  List<String> arguments, {
  Directory? projectRoot,
  DockerProcessRunner processRunner = const DockerProcessRunner(),
}) async {
  final runner =
      CommandRunner<int>(
          'dart_edge_docker',
          'Generate and build Docker images for Dart Edge workspaces.',
        )
        ..addCommand(_GenerateCommand(projectRoot))
        ..addCommand(_BuildCommand(projectRoot, processRunner))
        ..addCommand(_BakeCommand(projectRoot))
        ..addCommand(_PrintConfigCommand(projectRoot))
        ..addCommand(_PackageVersionCommand(projectRoot));

  try {
    return await runner.run(arguments) ?? 0;
  } on UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('');
    stderr.writeln(error.usage);
    return 64;
  } on DockerConfigException catch (error) {
    stderr.writeln('Configuration error: ${error.message}');
    return 78;
  } on PackageVersionException catch (error) {
    stderr.writeln('Package version error: ${error.message}');
    return 78;
  } on Object catch (error) {
    stderr.writeln('dart_edge_docker failed: $error');
    return 1;
  }
}

final class _GenerateCommand extends Command<int> {
  _GenerateCommand(this._projectRoot);

  final Directory? _projectRoot;

  @override
  String get description => 'Generate Dockerfiles and Docker Bake targets.';

  @override
  String get name => 'generate';

  @override
  String get invocation => 'dart_edge_docker generate [image]';

  @override
  Future<int> run() async {
    final imageName = argResults!.rest.singleOrNull;
    if (argResults!.rest.length > 1) {
      usageException('Expected at most one image name.');
    }
    final result = await DartEdgeDockerGenerator(
      projectRoot: _projectRoot ?? Directory.current,
    ).generate(selectedImage: imageName);
    for (final image in result.images) {
      stdout.writeln('Generated ${image.name}: ${image.dockerfile.path}');
    }
    stdout.writeln('Generated bake file: ${result.bakeFile.path}');
    return 0;
  }
}

final class _BuildCommand extends Command<int> {
  _BuildCommand(this._projectRoot, this._processRunner) {
    argParser.addFlag('push', help: 'Pass --push to docker buildx build.');
  }

  final Directory? _projectRoot;
  final DockerProcessRunner _processRunner;

  @override
  String get description => 'Generate and run docker buildx build.';

  @override
  String get name => 'build';

  @override
  String get invocation => 'dart_edge_docker build [--push] <image>';

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) {
      usageException('Expected exactly one image name.');
    }
    final imageName = argResults!.rest.single;
    final generator = DartEdgeDockerGenerator(
      projectRoot: _projectRoot ?? Directory.current,
    );
    final result = await generator.generate(selectedImage: imageName);
    final image = result.images.single;
    final command = buildxCommand(
      image,
      push: argResults!.flag('push'),
      labels: result.labels,
    );

    stdout.writeln('Generated Dockerfile: ${image.dockerfile.path}');
    stdout.writeln('Running: ${shellCommand(command)}');
    final exitCode = await _processRunner.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: generator.projectRoot.path,
    );
    if (exitCode != 0) {
      stderr.writeln('Docker build failed for "$imageName".');
      stderr.writeln('Dockerfile: ${image.dockerfile.path}');
      stderr.writeln('Command: ${shellCommand(command)}');
    }
    return exitCode;
  }
}

final class _BakeCommand extends Command<int> {
  _BakeCommand(this._projectRoot);

  final Directory? _projectRoot;

  @override
  String get description => 'Generate Docker Bake target file.';

  @override
  String get name => 'bake';

  @override
  Future<int> run() async {
    final result = await DartEdgeDockerGenerator(
      projectRoot: _projectRoot ?? Directory.current,
    ).generate();
    stdout.writeln(result.bakeFile.path);
    return 0;
  }
}

final class _PrintConfigCommand extends Command<int> {
  _PrintConfigCommand(this._projectRoot);

  final Directory? _projectRoot;

  @override
  String get description => 'Print the normalized docker.yaml model.';

  @override
  String get name => 'print-config';

  @override
  Future<int> run() async {
    final generator = DartEdgeDockerGenerator(
      projectRoot: _projectRoot ?? Directory.current,
    );
    final config = await generator.loadConfig();
    stdout.write(config.toPrettyJson());
    return 0;
  }
}

final class _PackageVersionCommand extends Command<int> {
  _PackageVersionCommand(this._projectRoot) {
    argParser
      ..addFlag('json', help: 'Print JSON instead of key=value lines.')
      ..addFlag(
        'github-output',
        help: 'Append version and version_tag to the GITHUB_OUTPUT file.',
      );
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Read version and version_tag from a pubspec.yaml.';

  @override
  String get name => 'package-version';

  @override
  String get invocation =>
      'dart_edge_docker package-version [--json] [--github-output] <package-path>';

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) {
      usageException('Expected exactly one package path.');
    }
    final root = _projectRoot ?? Directory.current;
    final packagePath = argResults!.rest.single;
    final packageRoot = Directory(
      p.isAbsolute(packagePath) ? packagePath : p.join(root.path, packagePath),
    );
    final version = await PackageVersionOutput.read(packageRoot);

    if (argResults!.flag('github-output')) {
      final githubOutput = Platform.environment['GITHUB_OUTPUT'];
      if (githubOutput == null || githubOutput.isEmpty) {
        usageException('GITHUB_OUTPUT is not set.');
      }
      await File(
        githubOutput,
      ).writeAsString(version.toEnv(), mode: FileMode.append);
    }

    stdout.write(argResults!.flag('json') ? version.toJson() : version.toEnv());
    return 0;
  }
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
