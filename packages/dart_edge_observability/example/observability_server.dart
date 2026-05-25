import 'dart:async';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_observability/dart_edge_observability.dart';

Future<void> main() async {
  final config = ObservabilityConfig.fromEnvironment();
  final observability = DartEdgeObservability(config: config);

  final app = DartEdge<AppServices>(
    services: AppServices.new,
    requestObservers: [observability.httpObserver<AppServices>()],
    middlewares: [
      RustMiddleware.requestId(),
      if (config.otlpTracesEndpoint != null)
        RustMiddleware.tracing(
          openTelemetry: OpenTelemetryConfig.otlpGrpc(
            serviceName: config.serviceName,
            endpoint: config.otlpTracesEndpoint!,
          ),
        ),
    ],
  );

  final api = app.router('/api');
  api.get<RawResponse>(
    '/health',
    options: const RouteOptions(
      operationId: 'healthCheck',
      success: ResponseSpec.json(),
    ),
    handler: (_) => RawResponse.json(status: 200, body: {'status': 'ok'}),
  );
  api.post<RawResponse>(
    '/transcriptions',
    options: const RouteOptions(
      operationId: 'createTranscription',
      success: ResponseSpec.json(status: 202),
    ),
    handler: (ctx) async {
      final requestContext = ctx.require<ObservabilityRequestContext>();
      final result = await observeOperation(
        name: 'audio_normalization',
        context: requestContext,
        logger: observability.logger,
        tracerProvider: observability.tracerProvider,
        attributes: const <String, Object?>{
          'audio.format': 'wav',
          'implementation': 'example',
        },
        fn: (operationContext) {
          return ctx.services.normalizeAudio(context: operationContext);
        },
      );
      return RawResponse.json(
        status: 202,
        body: {'status': 'queued', 'normalized': result},
      );
    },
  );

  app.mountMetricsEndpoint(observability: observability);

  await app.listen(port: 8080, workers: 1);
}

final class AppServices {
  Future<bool> normalizeAudio({
    required ObservabilityRequestContext context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return true;
  }
}
