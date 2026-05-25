# dart_edge_observability

Reusable observability primitives for Dart Edge services.

This package owns the generic machinery: request correlation, zone context
propagation, JSON logs, Prometheus metrics, OpenTelemetry spans, optional Loki
shipping, error normalization, and operation wrappers. Product packages should
own their domain metric names, labels, and events.

## Quick Start

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_observability/dart_edge_observability.dart';

Future<void> main() async {
  final observability = DartEdgeObservability(
    config: ObservabilityConfig.fromEnvironment(),
  );

  final app = DartEdge<AppServices>(
    services: AppServices.new,
    requestObservers: [observability.httpObserver<AppServices>()],
    middlewares: [RustMiddleware.requestId()],
  );

  app.get('/health', handler: (_) => const {'status': 'ok'});
  app.mountMetricsEndpoint(observability: observability);

  await app.listen(port: 8080);
}

final class AppServices {
  const AppServices();
}
```

See [example/observability_server.dart](example/observability_server.dart) for a
complete runnable example.

## Configuration

`ObservabilityConfig.fromEnvironment()` reads:

- `LOG_LEVEL`
- `ENVIRONMENT`
- `SERVICE_NAME`
- `SERVICE_VERSION`
- `LOKI_URL`
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
- `OTEL_TRACES_SAMPLER_ARG`
- `MONITORING_PORT`
- `REQUEST_LOGGING_ENABLED`

## HTTP Metrics

The built-in HTTP observer records:

- `http_server_requests_total`
- `http_server_errors_total`
- `http_server_request_duration_seconds`
- `http_server_request_body_bytes`
- `http_server_response_body_bytes`

Routes are labeled by normalized route pattern, not raw URL.

## Operation Spans

```dart
await observeOperation(
  name: 'audio_normalization',
  context: ctx.require<ObservabilityRequestContext>(),
  logger: observability.logger,
  tracerProvider: observability.tracerProvider,
  attributes: {'audio.format': 'wav'},
  fn: (operationContext) {
    return service.normalize(context: operationContext);
  },
);
```
