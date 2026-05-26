import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'process_utils.dart';

final class TestSuiteConfig {
  const TestSuiteConfig({
    required this.projectRoot,
    required this.suitePath,
    required this.testPath,
    required this.environment,
    required this.extraTestArguments,
    required this.reporter,
    this.composeFile,
    this.composeProjectName,
    this.composeDown = true,
    this.healthUrl,
    this.healthTimeout = const Duration(seconds: 90),
    this.dartExecutable = 'dart',
  });

  final Directory projectRoot;
  final String suitePath;
  final String testPath;
  final Map<String, String> environment;
  final List<String> extraTestArguments;
  final String reporter;
  final String? composeFile;
  final String? composeProjectName;
  final bool composeDown;
  final Uri? healthUrl;
  final Duration healthTimeout;
  final String dartExecutable;
}

final class TestSuiteRunner {
  const TestSuiteRunner({
    this.processRunner = const CommandProcessRunner(),
    this._httpClient,
  });

  final CommandProcessRunner processRunner;
  final HttpClient? _httpClient;

  Future<int> run(TestSuiteConfig config) async {
    final suiteRoot = _resolve(config.projectRoot, config.suitePath);
    if (!suiteRoot.existsSync()) {
      throw TestSuiteException('Test suite does not exist: ${suiteRoot.path}');
    }
    final testTarget = _resolve(suiteRoot, config.testPath);
    if (!testTarget.existsSync()) {
      throw TestSuiteException(
        'Test target does not exist: ${testTarget.path}',
      );
    }

    var composeStarted = false;
    try {
      if (config.composeFile != null) {
        await _compose(config, [
          'up',
          '--build',
          '--detach',
        ], description: 'Starting compose environment');
        composeStarted = true;
      }
      if (config.healthUrl != null) {
        await waitForHttpOk(config.healthUrl!, timeout: config.healthTimeout);
      }

      final command = [
        config.dartExecutable,
        'test',
        p.relative(testTarget.path, from: suiteRoot.path),
        '--reporter',
        config.reporter,
        ...config.extraTestArguments,
      ];
      stdout.writeln('Running: ${shellCommand(command)}');
      return await processRunner.run(
        command.first,
        command.skip(1).toList(),
        workingDirectory: suiteRoot.path,
        environment: config.environment,
      );
    } finally {
      if (composeStarted && config.composeDown) {
        await _compose(config, [
          'down',
          '--remove-orphans',
        ], description: 'Stopping compose environment');
      }
    }
  }

  Future<void> waitForHttpOk(Uri url, {required Duration timeout}) async {
    final client = _httpClient ?? HttpClient();
    final stopwatch = Stopwatch()..start();
    Object? lastError;

    while (stopwatch.elapsed < timeout) {
      try {
        final request = await client.getUrl(url);
        final response = await request.close().timeout(
          const Duration(seconds: 5),
        );
        await response.drain<void>();
        if (response.statusCode >= 200 && response.statusCode < 500) {
          stdout.writeln('Health check passed: $url (${response.statusCode})');
          return;
        }
        lastError = 'HTTP ${response.statusCode}';
      } on Object catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    throw TestSuiteException(
      'Timed out waiting for $url after ${timeout.inSeconds}s. '
      'Last error: $lastError',
    );
  }

  Future<void> _compose(
    TestSuiteConfig config,
    List<String> arguments, {
    required String description,
  }) async {
    final command = [
      'docker',
      'compose',
      if (config.composeFile case final composeFile?) ...[
        '--file',
        composeFile,
      ],
      if (config.composeProjectName case final projectName?) ...[
        '--project-name',
        projectName,
      ],
      ...arguments,
    ];
    stdout.writeln('$description: ${shellCommand(command)}');
    final exitCode = await processRunner.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: config.projectRoot.path,
    );
    if (exitCode != 0) {
      throw TestSuiteException(
        'Docker compose command failed with exit code $exitCode.',
      );
    }
  }
}

Directory _resolve(Directory base, String path) {
  return Directory(p.isAbsolute(path) ? path : p.join(base.path, path));
}

final class TestSuiteException implements Exception {
  const TestSuiteException(this.message);

  final String message;

  @override
  String toString() => message;
}
