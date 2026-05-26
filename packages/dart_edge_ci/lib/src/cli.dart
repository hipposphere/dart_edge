import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'docker_generator.dart';
import 'flutter_release_builder.dart';
import 'flutter_release_config.dart';
import 'package_version.dart';
import 'server_benchmark.dart';
import 'test_suite_runner.dart';

Future<int> runDartEdgeCi(
  List<String> arguments, {
  Directory? projectRoot,
  DockerProcessRunner processRunner = const DockerProcessRunner(),
}) async {
  final runner =
      CommandRunner<int>(
          'dart_edge_ci',
          'CI utilities for Dart Edge workspaces.',
        )
        ..addCommand(_DockerCommand(projectRoot, processRunner))
        ..addCommand(_FlutterCommand(projectRoot))
        ..addCommand(_PackageVersionCommand(projectRoot))
        ..addCommand(_TestCommand(projectRoot))
        ..addCommand(_BenchCommand(projectRoot));

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
  } on FlutterReleaseException catch (error) {
    stderr.writeln('Flutter release error: ${error.message}');
    return 78;
  } on TestSuiteException catch (error) {
    stderr.writeln('Test suite error: ${error.message}');
    return 78;
  } on Object catch (error) {
    stderr.writeln('dart_edge_ci failed: $error');
    return 1;
  }
}

final class _FlutterCommand extends Command<int> {
  _FlutterCommand(Directory? projectRoot) {
    addSubcommand(_FlutterBuildCommand(projectRoot));
    addSubcommand(_FlutterPublishCommand(projectRoot));
    addSubcommand(_FlutterSigningCommand(projectRoot));
    addSubcommand(_FlutterPrintConfigCommand(projectRoot));
    addSubcommand(_FlutterArtifactPathsCommand(projectRoot));
  }

  @override
  String get description => 'Build Flutter release artifacts.';

  @override
  String get name => 'flutter';
}

final class _FlutterSigningCommand extends Command<int> {
  _FlutterSigningCommand(Directory? projectRoot) {
    addSubcommand(_FlutterSigningIosCommand(projectRoot));
  }

  @override
  String get description => 'Install signing material for Flutter releases.';

  @override
  String get name => 'signing';
}

final class _FlutterSigningIosCommand extends Command<int> {
  _FlutterSigningIosCommand(this._projectRoot) {
    argParser
      ..addOption(
        'config',
        defaultsTo: 'flutter_release.yaml',
        help: 'Path to the Flutter release config file.',
      )
      ..addOption('target', help: 'iOS release target to validate.')
      ..addFlag('dry-run', help: 'Print commands without executing them.');
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Install iOS signing certificate and profiles.';

  @override
  String get name => 'ios';

  @override
  Future<int> run() async {
    final root = _projectRoot ?? Directory.current;
    final config = await _loadFlutterReleaseConfig(
      root,
      argResults!.option('config')!,
    );
    return FlutterReleaseBuilder(projectRoot: root).installIosSigningMaterial(
      targetName: argResults!.option('target'),
      config: config,
      dryRun: argResults!.flag('dry-run'),
    );
  }
}

final class _FlutterPublishCommand extends Command<int> {
  _FlutterPublishCommand(Directory? projectRoot) {
    addSubcommand(_FlutterPublishIosAppStoreCommand(projectRoot));
  }

  @override
  String get description => 'Publish Flutter release artifacts.';

  @override
  String get name => 'publish';
}

final class _FlutterPublishIosAppStoreCommand extends Command<int> {
  _FlutterPublishIosAppStoreCommand(this._projectRoot) {
    argParser
      ..addOption(
        'config',
        defaultsTo: 'flutter_release.yaml',
        help: 'Path to the Flutter release config file.',
      )
      ..addOption('target', help: 'Release target to publish.')
      ..addFlag('dry-run', help: 'Print commands without executing them.');
  }

  final Directory? _projectRoot;

  @override
  String get description =>
      'Upload the configured iOS IPA to App Store Connect.';

  @override
  String get name => 'ios-app-store';

  @override
  Future<int> run() async {
    final root = _projectRoot ?? Directory.current;
    final config = await _loadFlutterReleaseConfig(
      root,
      argResults!.option('config')!,
    );
    return FlutterReleaseBuilder(projectRoot: root).publishIosAppStore(
      targetName: argResults!.option('target'),
      config: config,
      dryRun: argResults!.flag('dry-run'),
    );
  }
}

final class _FlutterBuildCommand extends Command<int> {
  _FlutterBuildCommand(this._projectRoot) {
    argParser
      ..addOption(
        'config',
        defaultsTo: 'flutter_release.yaml',
        help: 'Path to the Flutter release config file.',
      )
      ..addFlag('all', help: 'Build every enabled target in the config.')
      ..addFlag('dry-run', help: 'Print commands without executing them.')
      ..addFlag(
        'github-output',
        help: 'Append artifact paths to the GITHUB_OUTPUT file.',
      );
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Run flutter build for a configured target.';

  @override
  String get name => 'build';

  @override
  String get invocation =>
      'dart_edge_ci flutter build [--all] [--dry-run] [target]';

  @override
  Future<int> run() async {
    final root = _projectRoot ?? Directory.current;
    final config = await _loadFlutterReleaseConfig(
      root,
      argResults!.option('config')!,
    );
    final targetNames = _selectedFlutterTargets(config);
    final builder = FlutterReleaseBuilder(projectRoot: root);

    for (final targetName in targetNames) {
      final exitCode = await builder.build(
        targetName,
        config: config,
        dryRun: argResults!.flag('dry-run'),
      );
      if (exitCode != 0) {
        return exitCode;
      }
    }

    if (argResults!.flag('github-output')) {
      await _writeFlutterGithubOutput(config, targetNames);
    }
    return 0;
  }

  List<String> _selectedFlutterTargets(FlutterReleaseConfig config) {
    if (argResults!.flag('all')) {
      if (argResults!.rest.isNotEmpty) {
        usageException('Do not pass a target when using --all.');
      }
      return [
        for (final entry in config.targets.entries)
          if (entry.value.enabled) entry.key,
      ];
    }
    if (argResults!.rest.length != 1) {
      usageException('Expected exactly one target, or pass --all.');
    }
    return [argResults!.rest.single];
  }
}

final class _FlutterPrintConfigCommand extends Command<int> {
  _FlutterPrintConfigCommand(this._projectRoot) {
    argParser.addOption(
      'config',
      defaultsTo: 'flutter_release.yaml',
      help: 'Path to the Flutter release config file.',
    );
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Print the normalized flutter_release.yaml model.';

  @override
  String get name => 'print-config';

  @override
  Future<int> run() async {
    final config = await _loadFlutterReleaseConfig(
      _projectRoot ?? Directory.current,
      argResults!.option('config')!,
    );
    stdout.write(config.toPrettyJson());
    return 0;
  }
}

final class _FlutterArtifactPathsCommand extends Command<int> {
  _FlutterArtifactPathsCommand(this._projectRoot) {
    argParser.addOption(
      'config',
      defaultsTo: 'flutter_release.yaml',
      help: 'Path to the Flutter release config file.',
    );
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Print default artifact upload paths.';

  @override
  String get name => 'artifact-paths';

  @override
  String get invocation => 'dart_edge_ci flutter artifact-paths [target]';

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) {
      usageException('Expected exactly one target.');
    }
    final targetName = argResults!.rest.single;
    final config = await _loadFlutterReleaseConfig(
      _projectRoot ?? Directory.current,
      argResults!.option('config')!,
    );
    stdout.write(flutterReleaseArtifactPaths(config, targetName).join('\n'));
    stdout.writeln();
    return 0;
  }
}

final class _TestCommand extends Command<int> {
  _TestCommand(Directory? projectRoot) {
    addSubcommand(_RunSuiteCommand(projectRoot, name: 'routes'));
    addSubcommand(_RunSuiteCommand(projectRoot, name: 'e2e'));
    addSubcommand(_EnvCommand(projectRoot));
  }

  @override
  String get description => 'Run route, end-to-end, and environment tests.';

  @override
  String get name => 'test';
}

final class _RunSuiteCommand extends Command<int> {
  _RunSuiteCommand(this._projectRoot, {required this.name}) {
    argParser
      ..addOption(
        'suite',
        defaultsTo: 'packages/dart_edge_test_suite',
        help: 'Path to the project-specific test suite package.',
      )
      ..addOption(
        'path',
        defaultsTo: 'test/$name',
        help: 'Path inside the suite package to run with dart test.',
      )
      ..addOption(
        'base-url',
        help: 'Base URL exposed to tests as TEST_BASE_URL.',
      )
      ..addOption(
        'compose-file',
        help: 'Optional Docker Compose file to start before tests.',
      )
      ..addOption(
        'compose-project-name',
        help: 'Optional Docker Compose project name.',
      )
      ..addFlag(
        'compose-down',
        defaultsTo: true,
        help: 'Run docker compose down after tests.',
      )
      ..addOption(
        'health-url',
        help: 'Optional URL to poll before running tests.',
      )
      ..addOption(
        'health-timeout',
        defaultsTo: '90',
        help: 'Seconds to wait for the health URL.',
      )
      ..addOption(
        'reporter',
        defaultsTo: 'expanded',
        help: 'dart test reporter to use.',
      )
      ..addOption(
        'dart',
        defaultsTo: 'dart',
        help: 'Dart executable used to run tests.',
      );
  }

  final Directory? _projectRoot;

  @override
  final String name;

  @override
  String get description => 'Run the $name test suite.';

  @override
  String get invocation =>
      'dart_edge_ci test $name [options] [-- dart-test-args]';

  @override
  Future<int> run() {
    final baseUrl = argResults!.option('base-url');
    final healthUrl = argResults!.option('health-url') ?? baseUrl;
    return TestSuiteRunner().run(
      TestSuiteConfig(
        projectRoot: _projectRoot ?? Directory.current,
        suitePath: argResults!.option('suite')!,
        testPath: argResults!.option('path')!,
        environment: _testEnvironment(baseUrl),
        extraTestArguments: argResults!.rest,
        reporter: argResults!.option('reporter')!,
        composeFile: argResults!.option('compose-file'),
        composeProjectName: argResults!.option('compose-project-name'),
        composeDown: argResults!.flag('compose-down'),
        healthUrl: healthUrl == null ? null : Uri.parse(healthUrl),
        healthTimeout: Duration(
          seconds: int.parse(argResults!.option('health-timeout')!),
        ),
        dartExecutable: argResults!.option('dart')!,
      ),
    );
  }
}

final class _EnvCommand extends Command<int> {
  _EnvCommand(Directory? projectRoot) {
    addSubcommand(_ComposeCommand(projectRoot, name: 'up'));
    addSubcommand(_ComposeCommand(projectRoot, name: 'down'));
  }

  @override
  String get description => 'Manage a Docker Compose test environment.';

  @override
  String get name => 'env';
}

final class _ComposeCommand extends Command<int> {
  _ComposeCommand(this._projectRoot, {required this.name}) {
    argParser
      ..addOption(
        'compose-file',
        defaultsTo: 'environment/compose.yaml',
        help: 'Docker Compose file to use.',
      )
      ..addOption(
        'compose-project-name',
        help: 'Optional Docker Compose project name.',
      );
  }

  final Directory? _projectRoot;

  @override
  final String name;

  @override
  String get description => name == 'up'
      ? 'Start the Docker Compose test environment.'
      : 'Stop the Docker Compose test environment.';

  @override
  Future<int> run() async {
    final command = [
      'docker',
      'compose',
      '--file',
      argResults!.option('compose-file')!,
      if (argResults!.option('compose-project-name')
          case final projectName?) ...[
        '--project-name',
        projectName,
      ],
      if (name == 'up') ...[
        'up',
        '--build',
        '--detach',
      ] else ...[
        'down',
        '--remove-orphans',
      ],
    ];
    stdout.writeln('Running: ${shellCommand(command)}');
    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: (_projectRoot ?? Directory.current).path,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

final class _BenchCommand extends Command<int> {
  _BenchCommand(Directory? projectRoot) {
    addSubcommand(_ServerBenchCommand(projectRoot));
  }

  @override
  String get description => 'Run reproducible benchmark suites.';

  @override
  String get name => 'bench';
}

final class _ServerBenchCommand extends Command<int> {
  _ServerBenchCommand(this._projectRoot) {
    argParser
      ..addOption('url', mandatory: true, help: 'HTTP endpoint to benchmark.')
      ..addOption('method', defaultsTo: 'GET', help: 'HTTP method to use.')
      ..addMultiOption(
        'header',
        help:
            'HTTP header in "Name: value" format. May be passed multiple times.',
      )
      ..addOption(
        'duration',
        defaultsTo: '30',
        help: 'Benchmark duration in seconds.',
      )
      ..addOption(
        'warmup',
        defaultsTo: '5',
        help: 'Warmup duration in seconds.',
      )
      ..addOption(
        'concurrency',
        defaultsTo: '16',
        help: 'Number of concurrent request loops.',
      )
      ..addOption(
        'output',
        defaultsTo: 'build/reports/bench/server.json',
        help: 'JSON report path.',
      )
      ..addOption(
        'compose-file',
        help: 'Optional Docker Compose file to start before benchmarking.',
      )
      ..addOption(
        'compose-project-name',
        help: 'Optional Docker Compose project name.',
      )
      ..addFlag(
        'compose-down',
        defaultsTo: true,
        help: 'Run docker compose down after benchmarking.',
      )
      ..addOption(
        'health-url',
        help: 'Optional URL to poll before benchmarking.',
      )
      ..addOption(
        'health-timeout',
        defaultsTo: '90',
        help: 'Seconds to wait for the health URL.',
      )
      ..addOption(
        'container',
        help: 'Optional Docker container name for CPU/memory sampling.',
      )
      ..addOption(
        'max-p95-latency-ms',
        help: 'Fail if p95 latency exceeds this threshold.',
      )
      ..addOption(
        'min-throughput',
        help: 'Fail if throughput is below this requests/sec threshold.',
      )
      ..addFlag(
        'github-summary',
        help: 'Append a benchmark summary to GITHUB_STEP_SUMMARY.',
      );
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Benchmark a server HTTP endpoint.';

  @override
  String get name => 'server';

  @override
  Future<int> run() {
    final url = Uri.parse(argResults!.option('url')!);
    return ServerBenchmarkRunner().run(
      ServerBenchmarkConfig(
        projectRoot: _projectRoot ?? Directory.current,
        url: url,
        duration: Duration(seconds: int.parse(argResults!.option('duration')!)),
        concurrency: int.parse(argResults!.option('concurrency')!),
        warmup: Duration(seconds: int.parse(argResults!.option('warmup')!)),
        outputPath: argResults!.option('output')!,
        headers: _parseHeaders(argResults!.multiOption('header')),
        method: argResults!.option('method')!,
        githubSummary: argResults!.flag('github-summary'),
        composeFile: argResults!.option('compose-file'),
        composeProjectName: argResults!.option('compose-project-name'),
        composeDown: argResults!.flag('compose-down'),
        healthUrl: Uri.parse(
          argResults!.option('health-url') ?? url.toString(),
        ),
        healthTimeout: Duration(
          seconds: int.parse(argResults!.option('health-timeout')!),
        ),
        container: argResults!.option('container'),
        maxP95LatencyMs: _tryParseDouble(
          argResults!.option('max-p95-latency-ms'),
        ),
        minThroughput: _tryParseDouble(argResults!.option('min-throughput')),
      ),
    );
  }
}

final class _DockerCommand extends Command<int> {
  _DockerCommand(Directory? projectRoot, DockerProcessRunner processRunner) {
    addSubcommand(_GenerateCommand(projectRoot));
    addSubcommand(_BuildCommand(projectRoot, processRunner));
    addSubcommand(_BakeCommand(projectRoot));
    addSubcommand(_PrintConfigCommand(projectRoot));
  }

  @override
  String get description => 'Generate and build Docker images.';

  @override
  String get name => 'docker';
}

final class _GenerateCommand extends Command<int> {
  _GenerateCommand(this._projectRoot) {
    argParser.addFlag(
      'github-output',
      help: 'Append generated Docker paths to the GITHUB_OUTPUT file.',
    );
  }

  final Directory? _projectRoot;

  @override
  String get description => 'Generate Dockerfiles and Docker Bake targets.';

  @override
  String get name => 'generate';

  @override
  String get invocation =>
      'dart_edge_ci docker generate [--github-output] [image]';

  @override
  Future<int> run() async {
    final imageName = argResults!.rest.singleOrNull;
    if (argResults!.rest.length > 1) {
      usageException('Expected at most one image name.');
    }
    final result = await DockerGenerator(
      projectRoot: _projectRoot ?? Directory.current,
    ).generate(selectedImage: imageName);
    for (final image in result.images) {
      stdout.writeln('Generated ${image.name}: ${image.dockerfile.path}');
    }
    stdout.writeln('Generated bake file: ${result.bakeFile.path}');

    if (argResults!.flag('github-output')) {
      final githubOutput = Platform.environment['GITHUB_OUTPUT'];
      if (githubOutput == null || githubOutput.isEmpty) {
        usageException('GITHUB_OUTPUT is not set.');
      }
      if (result.images.length != 1) {
        usageException(
          'Expected exactly one selected image when using --github-output.',
        );
      }
      final image = result.images.single;
      await File(githubOutput).writeAsString(
        DockerGenerateOutput(
          image: image.name,
          dockerfile: image.dockerfile.path,
          context: image.context.path,
        ).toEnv(),
        mode: FileMode.append,
      );
    }

    return 0;
  }
}

final class DockerGenerateOutput {
  const DockerGenerateOutput({
    required this.image,
    required this.dockerfile,
    required this.context,
  });

  final String image;
  final String dockerfile;
  final String context;

  Map<String, String> toMap() => {
    'image': image,
    'dockerfile': dockerfile,
    'context': context,
  };

  String toEnv() {
    final buffer = StringBuffer();
    for (final entry in toMap().entries) {
      buffer.writeln('${entry.key}=${entry.value}');
    }
    return buffer.toString();
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
  String get invocation => 'dart_edge_ci docker build [--push] <image>';

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) {
      usageException('Expected exactly one image name.');
    }
    final imageName = argResults!.rest.single;
    final generator = DockerGenerator(
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
    final result = await DockerGenerator(
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
    final generator = DockerGenerator(
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
      'dart_edge_ci package-version [--json] [--github-output] <package-path>';

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

Map<String, String> _parseHeaders(List<String> values) {
  final headers = <String, String>{};
  for (final value in values) {
    final separator = value.indexOf(':');
    if (separator <= 0) {
      throw UsageException(
        'Expected --header values in "Name: value" format.',
        '',
      );
    }
    headers[value.substring(0, separator).trim()] = value
        .substring(separator + 1)
        .trim();
  }
  return headers;
}

Map<String, String> _testEnvironment(String? baseUrl) {
  return baseUrl == null ? const {} : {'TEST_BASE_URL': baseUrl};
}

double? _tryParseDouble(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return double.parse(value);
}

Future<FlutterReleaseConfig> _loadFlutterReleaseConfig(
  Directory projectRoot,
  String configPath,
) async {
  final file = File(
    p.isAbsolute(configPath)
        ? configPath
        : p.join(projectRoot.path, configPath),
  );
  if (!await file.exists()) {
    throw FlutterReleaseException('${p.basename(configPath)} not found.');
  }
  return FlutterReleaseConfig.parse(await file.readAsString());
}

Future<void> _writeFlutterGithubOutput(
  FlutterReleaseConfig config,
  List<String> targetNames,
) async {
  final githubOutput = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutput == null || githubOutput.isEmpty) {
    throw const FlutterReleaseException('GITHUB_OUTPUT is not set.');
  }
  final buffer = StringBuffer();
  if (targetNames.length == 1) {
    final targetName = targetNames.single;
    final target = config.target(targetName);
    buffer
      ..writeln('target=$targetName')
      ..writeln('platform=${target.platform.name}')
      ..writeln(
        'artifact_path=${flutterReleaseArtifactPaths(config, targetName).join(',')}',
      );
  } else {
    buffer.writeln('artifact_paths<<dart_edge_ci');
    for (final targetName in targetNames) {
      for (final path in flutterReleaseArtifactPaths(config, targetName)) {
        buffer.writeln(path);
      }
    }
    buffer.writeln('dart_edge_ci');
  }
  await File(
    githubOutput,
  ).writeAsString(buffer.toString(), mode: FileMode.append);
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
