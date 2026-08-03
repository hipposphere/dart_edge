import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'pgrust_exception.dart';

/// A locally managed experimental pgrust server.
///
/// pgrust is not production ready. This endpoint is intended for disposable
/// development databases, compatibility tests, and performance experiments.
final class PgrustDatabase implements ManagedPostgresEndpoint {
  PgrustDatabase._({
    required this._process,
    required this.connectionString,
    required this.storagePath,
    required this.port,
    required this._deleteStorageOnClose,
    required this._shutdownTimeout,
    required this._logBuffer,
  }) : _exitCode = _process.exitCode {
    _exitCode.then((code) => _observedExitCode = code);
  }

  /// Starts pgrust with a newly initialized temporary PostgreSQL data
  /// directory. The directory is deleted when this endpoint closes.
  static Future<PgrustDatabase> temporary({
    String? executable,
    String? initdbExecutable,
    String? postgresShareDirectory,
    String? timezoneDirectory,
    int? port,
    Duration startupTimeout = const Duration(seconds: 20),
    Duration shutdownTimeout = const Duration(seconds: 5),
    Map<String, String> environment = const {},
    List<String> initdbArguments = const [],
    List<String> serverArguments = const [],
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_pgrust_',
    );

    try {
      return await _start(
        directory: directory,
        deleteStorageOnClose: true,
        executable: executable,
        initdbExecutable: initdbExecutable,
        postgresShareDirectory: postgresShareDirectory,
        timezoneDirectory: timezoneDirectory,
        port: port,
        startupTimeout: startupTimeout,
        shutdownTimeout: shutdownTimeout,
        environment: environment,
        initdbArguments: initdbArguments,
        serverArguments: serverArguments,
      );
    } catch (_) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// Starts pgrust with a persistent PostgreSQL data directory at [path].
  ///
  /// An empty directory is initialized automatically. Existing PostgreSQL 18
  /// data directories are left intact and are never deleted by this endpoint.
  static Future<PgrustDatabase> open(
    String path, {
    String? executable,
    String? initdbExecutable,
    String? postgresShareDirectory,
    String? timezoneDirectory,
    int? port,
    Duration startupTimeout = const Duration(seconds: 20),
    Duration shutdownTimeout = const Duration(seconds: 5),
    Map<String, String> environment = const {},
    List<String> initdbArguments = const [],
    List<String> serverArguments = const [],
  }) {
    return _start(
      directory: Directory(path).absolute,
      deleteStorageOnClose: false,
      executable: executable,
      initdbExecutable: initdbExecutable,
      postgresShareDirectory: postgresShareDirectory,
      timezoneDirectory: timezoneDirectory,
      port: port,
      startupTimeout: startupTimeout,
      shutdownTimeout: shutdownTimeout,
      environment: environment,
      initdbArguments: initdbArguments,
      serverArguments: serverArguments,
    );
  }

  /// PostgreSQL wire-protocol URL for this pgrust server.
  @override
  final String connectionString;

  /// Absolute path to the server's PostgreSQL data directory.
  final String storagePath;

  /// TCP port allocated to this server.
  final int port;

  final Process _process;
  final bool _deleteStorageOnClose;
  final Duration _shutdownTimeout;
  final _PgrustLogBuffer _logBuffer;
  final Future<int> _exitCode;
  int? _observedExitCode;
  Future<void>? _closeFuture;

  /// Operating-system process identifier for the managed server.
  int get processId => _process.pid;

  /// Completes with the pgrust process exit code.
  Future<int> get exitCode => _exitCode;

  /// Recent stdout and stderr lines captured from pgrust.
  List<String> get logs => _logBuffer.lines;

  /// Creates a `dart_edge_sql` pool that owns this endpoint.
  PostgresPool asPostgresPool({int maxSessions = 10}) {
    return PostgresPool.managed(this, maxSessions: maxSessions);
  }

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    if (_observedExitCode == null) {
      _process.kill(ProcessSignal.sigint);
      try {
        await _exitCode.timeout(_shutdownTimeout);
      } on TimeoutException {
        _process.kill(ProcessSignal.sigterm);
        try {
          await _exitCode.timeout(_shutdownTimeout);
        } on TimeoutException {
          _process.kill(ProcessSignal.sigkill);
          await _exitCode;
        }
      }
    }

    await _logBuffer.close();

    if (_deleteStorageOnClose) {
      final directory = Directory(storagePath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  static Future<PgrustDatabase> _start({
    required Directory directory,
    required bool deleteStorageOnClose,
    required String? executable,
    required String? initdbExecutable,
    required String? postgresShareDirectory,
    required String? timezoneDirectory,
    required int? port,
    required Duration startupTimeout,
    required Duration shutdownTimeout,
    required Map<String, String> environment,
    required List<String> initdbArguments,
    required List<String> serverArguments,
  }) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError(
        'dart_edge_sql_pgrust currently supports Linux and macOS.',
      );
    }
    if (startupTimeout <= Duration.zero || shutdownTimeout <= Duration.zero) {
      throw ArgumentError('pgrust lifecycle timeouts must be positive.');
    }
    if (port != null && (port < 1 || port > 65535)) {
      throw RangeError.range(port, 1, 65535, 'port');
    }

    final resolvedEnvironment = <String, String>{...environment};
    final pgrustExecutable =
        executable ??
        resolvedEnvironment['PGRUST_EXECUTABLE'] ??
        Platform.environment['PGRUST_EXECUTABLE'] ??
        'pgrust';
    final postgresInitdb =
        initdbExecutable ??
        resolvedEnvironment['PGRUST_INITDB_EXECUTABLE'] ??
        Platform.environment['PGRUST_INITDB_EXECUTABLE'] ??
        'initdb';

    await directory.create(recursive: true);
    await _initializeDataDirectory(
      directory,
      executable: postgresInitdb,
      environment: resolvedEnvironment,
      additionalArguments: initdbArguments,
    );

    final allocatedPort = port ?? await _reservePort();
    if (postgresShareDirectory != null) {
      resolvedEnvironment['PGRUST_PGSHAREDIR'] = postgresShareDirectory;
    }
    if (timezoneDirectory != null) {
      resolvedEnvironment['PGRUST_TZDIR'] = timezoneDirectory;
    }
    resolvedEnvironment.putIfAbsent('RUST_MIN_STACK', () => '33554432');

    final arguments = <String>[
      '-D',
      directory.path,
      '-p',
      '$allocatedPort',
      '-c',
      'listen_addresses=127.0.0.1',
      '-c',
      'io_method=sync',
      ...serverArguments,
    ];
    final command = _formatCommand(pgrustExecutable, arguments);

    late final Process process;
    try {
      process = await Process.start(
        pgrustExecutable,
        arguments,
        environment: resolvedEnvironment,
        includeParentEnvironment: true,
      );
    } on ProcessException catch (error) {
      throw PgrustException(
        'Could not start pgrust: ${error.message}',
        command: command,
      );
    }

    final logBuffer = _PgrustLogBuffer(process);
    final database = PgrustDatabase._(
      process: process,
      connectionString:
          'postgresql://postgres@127.0.0.1:$allocatedPort/postgres?sslmode=disable',
      storagePath: directory.absolute.path,
      port: allocatedPort,
      deleteStorageOnClose: deleteStorageOnClose,
      shutdownTimeout: shutdownTimeout,
      logBuffer: logBuffer,
    );

    try {
      await database._waitUntilListening(startupTimeout);
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  static Future<void> _initializeDataDirectory(
    Directory directory, {
    required String executable,
    required Map<String, String> environment,
    required List<String> additionalArguments,
  }) async {
    final versionFile = File('${directory.path}/PG_VERSION');
    if (await versionFile.exists()) {
      await _validateDataDirectoryVersion(versionFile);
      return;
    }

    final entries = await directory.list().take(1).toList();
    if (entries.isNotEmpty) {
      throw PgrustException(
        'Refusing to initialize the non-empty data directory '
        '${directory.path}.',
      );
    }

    final arguments = <String>[
      '-D',
      directory.path,
      '--no-locale',
      '--encoding=UTF8',
      '--username=postgres',
      '--auth=trust',
      ...additionalArguments,
    ];
    final command = _formatCommand(executable, arguments);
    late final ProcessResult result;
    try {
      result = await Process.run(
        executable,
        arguments,
        environment: environment,
        includeParentEnvironment: true,
      );
    } on ProcessException catch (error) {
      throw PgrustException(
        'Could not run PostgreSQL initdb: ${error.message}',
        command: command,
      );
    }

    if (result.exitCode != 0) {
      final output = <String>[
        '${result.stdout}'.trim(),
        '${result.stderr}'.trim(),
      ].where((line) => line.isNotEmpty).toList();
      throw PgrustException(
        'PostgreSQL initdb exited with code ${result.exitCode}.',
        command: command,
        logs: output,
      );
    }
    if (!await versionFile.exists()) {
      throw PgrustException(
        'PostgreSQL initdb completed without creating PG_VERSION.',
        command: command,
      );
    }
    await _validateDataDirectoryVersion(versionFile);
  }

  static Future<void> _validateDataDirectoryVersion(File versionFile) async {
    final version = (await versionFile.readAsString()).trim();
    if (version != '18') {
      throw PgrustException(
        'pgrust targets PostgreSQL 18 data directories, but '
        '${versionFile.parent.path} contains PG_VERSION $version.',
      );
    }
  }

  static Future<int> _reservePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<void> _waitUntilListening(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;

    while (DateTime.now().isBefore(deadline)) {
      final processExitCode = _observedExitCode;
      if (processExitCode != null) {
        throw PgrustException(
          'pgrust exited with code $processExitCode before accepting '
          'connections.',
          logs: logs,
        );
      }

      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 200),
        );
        socket.destroy();
        return;
      } on SocketException catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    throw PgrustException(
      'pgrust did not accept connections within $timeout.'
      '${lastError == null ? '' : ' Last socket error: $lastError'}',
      logs: logs,
    );
  }
}

final class _PgrustLogBuffer {
  _PgrustLogBuffer(Process process) {
    _subscriptions = [
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _add('stdout', line)),
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _add('stderr', line)),
    ];
  }

  static const _maximumLines = 200;
  final List<String> _lines = [];
  late final List<StreamSubscription<String>> _subscriptions;

  List<String> get lines => List.unmodifiable(_lines);

  void _add(String stream, String line) {
    _lines.add('[$stream] $line');
    if (_lines.length > _maximumLines) {
      _lines.removeAt(0);
    }
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}

String _formatCommand(String executable, List<String> arguments) {
  return <String>[executable, ...arguments].map(_shellQuote).join(' ');
}

String _shellQuote(String value) {
  if (RegExp(r'^[A-Za-z0-9_./:=?@+-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", "'\\''")}'";
}
