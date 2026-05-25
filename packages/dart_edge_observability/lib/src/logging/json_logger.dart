import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/observability_config.dart';
import '../context/observability_context.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error;

  static LogLevel? parse(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'debug' => LogLevel.debug,
      'info' => LogLevel.info,
      'warn' || 'warning' => LogLevel.warning,
      'error' => LogLevel.error,
      _ => null,
    };
  }
}

/// Structured JSON logging surface.
abstract class JsonLogger {
  const JsonLogger();

  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  });

  void debug(String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.debug, message, fields: fields);
  }

  void info(String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.info, message, fields: fields);
  }

  void warning(String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.warning, message, fields: fields);
  }

  void error(String message, {Map<String, Object?> fields = const {}}) {
    log(LogLevel.error, message, fields: fields);
  }
}

/// JSON logger that writes one event per stdout line.
final class StdoutJsonLogger extends JsonLogger {
  StdoutJsonLogger(this.config, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ObservabilityConfig config;
  final DateTime Function() _clock;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    if (level.index < config.logLevel.index) {
      return;
    }
    final contextFields = ObservabilityContext.current?.toLogFields();
    final event = <String, Object?>{
      'timestamp': _clock().toUtc().toIso8601String(),
      'level': level.name,
      'message': message,
      'service': config.serviceName,
      'version': config.serviceVersion,
      'environment': config.environment,
      ...?contextFields,
      ...fields,
    };
    stdout.writeln(jsonEncode(_withoutNulls(event)));
  }
}

/// Loki push API sink for JSON events.
final class LokiJsonLogger extends JsonLogger {
  LokiJsonLogger({
    required this.config,
    required this.baseLogger,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  final ObservabilityConfig config;
  final JsonLogger baseLogger;
  final HttpClient _client;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    baseLogger.log(level, message, fields: fields);
    final lokiUrl = config.lokiUrl;
    if (lokiUrl == null || level.index < config.logLevel.index) {
      return;
    }
    unawaited(_push(lokiUrl, level, message, fields));
  }

  Future<void> _push(
    String lokiUrl,
    LogLevel level,
    String message,
    Map<String, Object?> fields,
  ) async {
    final uri = Uri.parse(lokiUrl);
    final contextFields = ObservabilityContext.current?.toLogFields();
    final event = jsonEncode(
      _withoutNulls(<String, Object?>{
        'level': level.name,
        'message': message,
        'service': config.serviceName,
        'version': config.serviceVersion,
        'environment': config.environment,
        ...?contextFields,
        ...fields,
      }),
    );
    final payload = jsonEncode({
      'streams': [
        {
          'stream': {
            'service': config.serviceName,
            'environment': config.environment,
            'level': level.name,
          },
          'values': [
            ['${DateTime.now().toUtc().microsecondsSinceEpoch * 1000}', event],
          ],
        },
      ],
    });

    try {
      final request = await _client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(payload);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Logging must not fail the request path.
    }
  }
}

Map<String, Object?> _withoutNulls(Map<String, Object?> fields) {
  return {
    for (final entry in fields.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
