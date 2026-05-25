import 'dart:async';

import 'package:dart_edge_core/dart_edge_core.dart';

import '../config/observability_config.dart';
import '../context/observability_context.dart';
import '../error/error_normalizer.dart';
import '../logging/json_logger.dart';
import '../metrics/metrics.dart';
import '../tracing/tracing.dart';

/// Bundles the reusable observability primitives used by Dart Edge routes.
final class DartEdgeObservability {
  DartEdgeObservability({
    required this.config,
    JsonLogger? logger,
    MetricsRegistry? metrics,
    TracerProvider? tracerProvider,
  }) : logger = logger ?? StdoutJsonLogger(config),
       metrics = metrics ?? MetricsRegistry(),
       tracerProvider = tracerProvider ?? TracerProvider(config: config) {
    httpMetrics = StandardHttpMetrics(this.metrics);
  }

  final ObservabilityConfig config;
  final JsonLogger logger;
  final MetricsRegistry metrics;
  final TracerProvider tracerProvider;
  late final StandardHttpMetrics httpMetrics;

  HttpRequestObserver<TServices> httpObserver<TServices>() {
    return ObservabilityHttpRequestObserver<TServices>(this);
  }
}

final class ObservabilityHttpRequestObserver<TServices>
    implements HttpRequestObserver<TServices> {
  const ObservabilityHttpRequestObserver(this.observability);

  final DartEdgeObservability observability;

  @override
  Future<HttpRequestObservationResult> observe({
    required RequestContext<TServices> context,
    required HttpRequestObservation request,
    required Future<HttpRequestObservationResult> Function() next,
  }) async {
    final method = request.method.wireName;
    final route = request.route;
    final headers = context.req.headersMap;
    final traceParent = parseTraceParent(context.req.header('traceparent'));
    final span = observability.tracerProvider.startSpan(
      'HTTP $method $route',
      traceId: traceParent?.traceId,
      parentSpanId: traceParent?.parentSpanId,
      attributes: <String, Object?>{
        'http.request.method': method,
        'http.route': route,
        'http.operation_id': request.operationId,
      },
    );
    final requestContext = ObservabilityRequestContext(
      requestId: requestIdFromHeaders(headers),
      traceId: span.traceId,
      spanId: span.spanId,
      userId: headers['x-user-id'],
      workspaceId: headers['x-workspace-id'],
      route: route,
      method: method,
    );
    context.put<ObservabilityRequestContext>(requestContext);
    final startedAt = DateTime.now();

    if (observability.config.requestLoggingEnabled) {
      observability.logger.info(
        'http.request.started',
        fields: requestContext.toLogFields(),
      );
    }

    try {
      final result = await next();
      final duration = DateTime.now().difference(startedAt);
      _recordSuccess(
        result: result,
        duration: duration,
        method: method,
        route: route,
      );
      span
        ..setAttribute('http.response.status_code', result.statusCode)
        ..end();
      unawaited(observability.tracerProvider.exporter.export([span]));
      if (observability.config.requestLoggingEnabled) {
        observability.logger.info(
          'http.request.completed',
          fields: <String, Object?>{
            ...requestContext.toLogFields(),
            'statusCode': result.statusCode,
            'durationMs': duration.inMicroseconds / 1000,
          },
        );
      }
      return result;
    } catch (error, stackTrace) {
      final duration = DateTime.now().difference(startedAt);
      final normalized = normalizeError(
        error,
        stackTrace: stackTrace,
        includeStackTrace: observability.config.includeErrorStacks,
      );
      observability.httpMetrics.errorCounter.inc(
        labels: <String, String>{
          'method': method,
          'route': route,
          'errorName': normalized.errorName,
        },
      );
      observability.httpMetrics.latencyHistogram.observe(
        duration.inMicroseconds / Duration.microsecondsPerSecond,
        labels: <String, String>{
          'method': method,
          'route': route,
          'status': '500',
        },
      );
      span
        ..recordError(error, stackTrace: stackTrace)
        ..setAttribute('http.response.status_code', 500)
        ..end();
      unawaited(observability.tracerProvider.exporter.export([span]));
      observability.logger.error(
        'http.request.failed',
        fields: <String, Object?>{
          ...requestContext.toLogFields(),
          'statusCode': 500,
          'durationMs': duration.inMicroseconds / 1000,
          ...normalized.toLogFields(),
        },
      );
      rethrow;
    }
  }

  void _recordSuccess({
    required HttpRequestObservationResult result,
    required Duration duration,
    required String method,
    required String route,
  }) {
    final labels = <String, String>{
      'method': method,
      'route': route,
      'status': '${result.statusCode}',
    };
    observability.httpMetrics.requestCounter.inc(labels: labels);
    observability.httpMetrics.latencyHistogram.observe(
      duration.inMicroseconds / Duration.microsecondsPerSecond,
      labels: labels,
    );
    if (result.requestBodySize case final size?) {
      observability.httpMetrics.requestBodySize.observe(
        size.toDouble(),
        labels: <String, String>{'method': method, 'route': route},
      );
    }
    if (result.responseBodySize case final size?) {
      observability.httpMetrics.responseBodySize.observe(
        size.toDouble(),
        labels: labels,
      );
    }
  }
}

extension DartEdgeObservabilityMetricsEndpoint<TServices> on Router<TServices> {
  void mountMetricsEndpoint({
    required DartEdgeObservability observability,
    String path = '/metrics',
  }) {
    get<RawResponse>(
      path,
      options: const RouteOptions(
        operationId: 'metrics',
        success: ResponseSpec.text(),
      ),
      handler: (_) {
        return RawResponse.encoded(
          status: 200,
          contentType: 'text/plain; version=0.0.4; charset=utf-8',
          body: observability.metrics.scrape(),
        );
      },
    );
  }
}
