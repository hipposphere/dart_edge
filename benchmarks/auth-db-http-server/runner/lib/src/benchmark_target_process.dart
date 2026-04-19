import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import 'benchmark_targets.dart';
import 'cpu_throttler.dart';

/// Running benchmark target process plus captured output buffers.
final class BenchmarkTargetProcess {
  BenchmarkTargetProcess._({
    required this.process,
    required this.stdoutBuffer,
    required this.stderrBuffer,
    required this.cpuThrottler,
  }) {
    process.exitCode.then((code) => _exitCode = code);
  }

  final Process process;
  final StringBuffer stdoutBuffer;
  final StringBuffer stderrBuffer;
  final CpuThrottler? cpuThrottler;
  int? _exitCode;

  static final Set<String> _preparedWorkingDirectories = <String>{};

  static Future<BenchmarkTargetProcess> start({
    required BenchmarkTargetDefinition target,
    required Directory repoRoot,
    required int port,
    required bool singleCore,
    Map<String, String> environment = const <String, String>{},
  }) async {
    final workingDirectory =
        '${repoRoot.path}/benchmarks/auth-db-http-server/${target.directoryName}';

    if (_preparedWorkingDirectories.add(workingDirectory)) {
      await _prepareTarget(target: target, workingDirectory: workingDirectory);
    }

    final process = await _startProcess(
      target: target,
      workingDirectory: workingDirectory,
      port: port,
      environment: environment,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final cpuThrottler = singleCore ? CpuThrottler(pid: process.pid) : null;
    await cpuThrottler?.start();

    final targetProcess = BenchmarkTargetProcess._(
      process: process,
      stdoutBuffer: stdoutBuffer,
      stderrBuffer: stderrBuffer,
      cpuThrottler: cpuThrottler,
    );

    try {
      await targetProcess._waitUntilReady(port: port);
      return targetProcess;
    } catch (_) {
      await cpuThrottler?.dispose();
      rethrow;
    }
  }

  Future<void> stop() async {
    await cpuThrottler?.dispose();
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
    final uri = Uri.http('127.0.0.1:$port', benchmarkHealthPath);
    final deadline = DateTime.now().add(const Duration(seconds: 30));

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
      case BenchmarkTargetRuntime.node:
        return;
      case BenchmarkTargetRuntime.dartAot:
        await _buildDartCliBundle(
          target: target,
          workingDirectory: workingDirectory,
        );
        return;
    }
  }

  static Future<Process> _startProcess({
    required BenchmarkTargetDefinition target,
    required String workingDirectory,
    required int port,
    required Map<String, String> environment,
  }) {
    return switch (target.runtime) {
      BenchmarkTargetRuntime.dartAot => Process.start(
        '$workingDirectory/build/${target.id}/bundle/bin/server',
        ['--port=$port'],
        workingDirectory: workingDirectory,
        environment: environment,
      ),
      BenchmarkTargetRuntime.node => Process.start(
        'node',
        ['server.mjs', '--port=$port'],
        workingDirectory: workingDirectory,
        environment: environment,
      ),
    };
  }

  static Future<void> _buildDartCliBundle({
    required BenchmarkTargetDefinition target,
    required String workingDirectory,
  }) async {
    final outputDirectory = 'build/${target.id}';

    for (var attempt = 0; attempt < 2; attempt += 1) {
      final result = await Process.run(Platform.resolvedExecutable, [
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
}
