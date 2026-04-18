import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'benchmark_targets.dart';

/// Running benchmark target process plus captured output buffers.
final class BenchmarkTargetProcess {
  BenchmarkTargetProcess._({
    required this.process,
    required this.stdoutBuffer,
    required this.stderrBuffer,
  }) {
    process.exitCode.then((code) => _exitCode = code);
  }

  final Process process;
  final StringBuffer stdoutBuffer;
  final StringBuffer stderrBuffer;
  int? _exitCode;

  static Future<BenchmarkTargetProcess> start({
    required BenchmarkTargetDefinition target,
    required Directory benchmarkSuiteRoot,
    required int port,
  }) async {
    final workingDirectory =
        '${benchmarkSuiteRoot.path}/${target.directoryName}';
    await _prepareTarget(target: target, workingDirectory: workingDirectory);

    final process = await _startProcess(
      target: target,
      workingDirectory: workingDirectory,
      port: port,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final targetProcess = BenchmarkTargetProcess._(
      process: process,
      stdoutBuffer: stdoutBuffer,
      stderrBuffer: stderrBuffer,
    );

    await targetProcess._waitUntilReady(port: port);
    return targetProcess;
  }

  Future<void> stop() async {
    process.kill();

    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }

  String get combinedOutput => 'stdout:\n$stdoutBuffer\nstderr:\n$stderrBuffer';

  Future<void> _waitUntilReady({required int port}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    final uri = Uri.http('127.0.0.1:$port', '/plaintext');
    final deadline = DateTime.now().add(const Duration(seconds: 15));

    try {
      while (DateTime.now().isBefore(deadline)) {
        if (_exitCode case final code?) {
          throw StateError(
            'Server exited before becoming ready with code $code.\n$combinedOutput',
          );
        }

        try {
          final request = await client.getUrl(uri);
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == HttpStatus.ok) {
            return;
          }
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    } finally {
      client.close(force: true);
    }

    throw StateError('Server did not become ready in time.\n$combinedOutput');
  }

  static Future<void> _prepareTarget({
    required BenchmarkTargetDefinition target,
    required String workingDirectory,
  }) async {
    switch (target.runtime) {
      case BenchmarkTargetRuntime.dartJit:
      case BenchmarkTargetRuntime.node:
      case BenchmarkTargetRuntime.python:
        return;
      case BenchmarkTargetRuntime.dartAot:
        await _buildDartCliBundle(
          target: target,
          workingDirectory: workingDirectory,
        );
        return;
      case BenchmarkTargetRuntime.rust:
        final result = await Process.run('cargo', const [
          'build',
          '--release',
        ], workingDirectory: workingDirectory);
        if (result.exitCode == 0) {
          return;
        }
        throw StateError(
          'Failed to build ${target.label}.\n'
          'stdout:\n${result.stdout}\n'
          'stderr:\n${result.stderr}',
        );
    }
  }

  static Future<Process> _startProcess({
    required BenchmarkTargetDefinition target,
    required String workingDirectory,
    required int port,
  }) {
    return switch (target.runtime) {
      BenchmarkTargetRuntime.dartJit => Process.start('dart', [
        'run',
        'bin/server.dart',
        '--port=$port',
      ], workingDirectory: workingDirectory),
      BenchmarkTargetRuntime.dartAot => Process.start(
        '$workingDirectory/build/${target.id}/bundle/bin/server',
        ['--port=$port'],
        workingDirectory: workingDirectory,
      ),
      BenchmarkTargetRuntime.node => Process.start('node', [
        'server.mjs',
        '--port=$port',
      ], workingDirectory: workingDirectory),
      BenchmarkTargetRuntime.python => Process.start(
        _resolvePythonExecutable(workingDirectory),
        [
          '-m',
          'uvicorn',
          'server:app',
          '--host=127.0.0.1',
          '--port=$port',
          '--workers=1',
          '--log-level=warning',
          '--no-access-log',
          '--no-server-header',
        ],
        workingDirectory: workingDirectory,
      ),
      BenchmarkTargetRuntime.rust => Process.start(
        '$workingDirectory/target/release/${target.rustBinaryName}',
        ['--port=$port'],
        workingDirectory: workingDirectory,
      ),
    };
  }

  static Future<void> _buildDartCliBundle({
    required BenchmarkTargetDefinition target,
    required String workingDirectory,
  }) async {
    final outputDirectory = 'build/${target.id}';

    for (var attempt = 0; attempt < 2; attempt += 1) {
      final result = await Process.run('dart', [
        'build',
        'cli',
        '--target=bin/server.dart',
        '--output=$outputDirectory',
      ], workingDirectory: workingDirectory);

      if (result.exitCode == 0) {
        return;
      }

      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();
      final needsRerun =
          stdout.contains('File modified during build. Build must be rerun.') ||
          stderr.contains('File modified during build. Build must be rerun.');
      if (needsRerun && attempt == 0) {
        continue;
      }

      throw StateError(
        'Failed to build ${target.label}.\n'
        'stdout:\n$stdout\n'
        'stderr:\n$stderr',
      );
    }
  }

  static String _resolvePythonExecutable(String workingDirectory) {
    final virtualEnvCandidates = switch (Platform.operatingSystem) {
      'windows' => const ['.venv/Scripts/python.exe', '.venv/Scripts/python'],
      _ => const ['.venv/bin/python3', '.venv/bin/python'],
    };

    for (final candidate in virtualEnvCandidates) {
      final path = '$workingDirectory/$candidate';
      if (File(path).existsSync()) {
        return path;
      }
    }

    return Platform.isWindows ? 'python' : 'python3';
  }
}
