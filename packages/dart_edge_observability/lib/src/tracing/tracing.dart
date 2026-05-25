import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../config/observability_config.dart';
import '../context/observability_context.dart';
import '../error/error_normalizer.dart';
import '../logging/json_logger.dart';
import '../logging/log_helpers.dart';

/// Minimal tracer provider for request and operation spans.
final class TracerProvider {
  TracerProvider({
    required this.config,
    TraceExporter? exporter,
    Random? random,
  }) : exporter = exporter ?? OtlpHttpTraceExporter(config: config),
       _random = random ?? Random.secure();

  final ObservabilityConfig config;
  final TraceExporter exporter;
  final Random _random;

  bool get shouldSample => _random.nextDouble() < config.otelTracesSamplerArg;

  ObservabilitySpan startSpan(
    String name, {
    String? traceId,
    String? parentSpanId,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return ObservabilitySpan(
      name: name,
      traceId: traceId ?? generateTraceId(),
      spanId: generateSpanId(),
      parentSpanId: parentSpanId,
      sampled: shouldSample,
      attributes: attributes,
    );
  }
}

final class ObservabilitySpan {
  ObservabilitySpan({
    required this.name,
    required this.traceId,
    required this.spanId,
    required this.sampled,
    this.parentSpanId,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) : attributes = Map<String, Object?>.of(attributes),
       startedAt = DateTime.now().toUtc();

  final String name;
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final bool sampled;
  final DateTime startedAt;
  final Map<String, Object?> attributes;
  DateTime? endedAt;
  String status = 'ok';

  void setAttribute(String key, Object? value) {
    attributes[key] = value;
  }

  void recordError(Object error, {StackTrace? stackTrace}) {
    status = 'error';
    attributes.addAll(
      normalizeError(error, stackTrace: stackTrace).toLogFields(),
    );
  }

  void end() {
    endedAt ??= DateTime.now().toUtc();
  }

  Map<String, Object?> toJson(ObservabilityConfig config) {
    final end = endedAt ?? DateTime.now().toUtc();
    return <String, Object?>{
      'traceId': traceId,
      'spanId': spanId,
      'parentSpanId': ?parentSpanId,
      'name': name,
      'kind': 'SPAN_KIND_INTERNAL',
      'startTimeUnixNano': '${startedAt.microsecondsSinceEpoch * 1000}',
      'endTimeUnixNano': '${end.microsecondsSinceEpoch * 1000}',
      'status': {
        'code': status == 'ok' ? 'STATUS_CODE_OK' : 'STATUS_CODE_ERROR',
      },
      'attributes': [
        _attribute('service.name', config.serviceName),
        _attribute('service.version', config.serviceVersion),
        _attribute('deployment.environment', config.environment),
        for (final entry in attributes.entries)
          _attribute(entry.key, entry.value),
      ],
    };
  }
}

abstract interface class TraceExporter {
  Future<void> export(List<ObservabilitySpan> spans);
}

/// OTLP HTTP JSON trace exporter.
final class OtlpHttpTraceExporter implements TraceExporter {
  OtlpHttpTraceExporter({required this.config, HttpClient? client})
    : _client = client ?? HttpClient();

  final ObservabilityConfig config;
  final HttpClient _client;

  @override
  Future<void> export(List<ObservabilitySpan> spans) async {
    final endpoint = config.otlpTracesEndpoint;
    if (endpoint == null || spans.isEmpty) {
      return;
    }
    final sampled = spans.where((span) => span.sampled).toList(growable: false);
    if (sampled.isEmpty) {
      return;
    }
    final payload = jsonEncode({
      'resourceSpans': [
        {
          'scopeSpans': [
            {'spans': sampled.map((span) => span.toJson(config)).toList()},
          ],
        },
      ],
    });

    try {
      final request = await _client.postUrl(Uri.parse(endpoint));
      request.headers.contentType = ContentType.json;
      request.write(payload);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Tracing export must not fail the request path.
    }
  }
}

Future<T> observeOperation<T>({
  required String name,
  required ObservabilityRequestContext context,
  required FutureOr<T> Function(ObservabilityRequestContext context) fn,
  required JsonLogger logger,
  required TracerProvider tracerProvider,
  Map<String, Object?> attributes = const <String, Object?>{},
}) async {
  final span = tracerProvider.startSpan(
    name,
    traceId: context.traceId,
    parentSpanId: context.spanId,
    attributes: attributes,
  );
  final operationContext = context.copyWith(
    traceId: span.traceId,
    spanId: span.spanId,
  );
  final startedAt = DateTime.now();
  logOperationStarted(
    logger,
    name: name,
    attributes: <String, Object?>{
      ...operationContext.toLogFields(),
      ...attributes,
    },
  );

  try {
    final result = await fn(operationContext);
    span.end();
    logOperationCompleted(
      logger,
      name: name,
      duration: DateTime.now().difference(startedAt),
      attributes: <String, Object?>{
        ...operationContext.toLogFields(),
        ...attributes,
      },
    );
    unawaited(tracerProvider.exporter.export([span]));
    return result;
  } catch (error, stackTrace) {
    span.recordError(error, stackTrace: stackTrace);
    span.end();
    logOperationFailed(
      logger,
      name: name,
      duration: DateTime.now().difference(startedAt),
      error: error,
      stackTrace: stackTrace,
      includeStackTrace: tracerProvider.config.includeErrorStacks,
      attributes: <String, Object?>{
        ...operationContext.toLogFields(),
        ...attributes,
      },
    );
    unawaited(tracerProvider.exporter.export([span]));
    rethrow;
  }
}

Map<String, Object?> _attribute(String key, Object? value) {
  return {
    'key': key,
    'value': switch (value) {
      final bool value => {'boolValue': value},
      final int value => {'intValue': '$value'},
      final double value => {'doubleValue': value},
      _ => {'stringValue': '$value'},
    },
  };
}
