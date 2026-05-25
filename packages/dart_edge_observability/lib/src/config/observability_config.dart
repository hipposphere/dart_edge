import 'dart:io';

import '../logging/json_logger.dart';

/// Shared environment-backed configuration for service observability.
final class ObservabilityConfig {
  const ObservabilityConfig({
    required this.serviceName,
    required this.serviceVersion,
    required this.environment,
    required this.logLevel,
    this.lokiUrl,
    this.otlpTracesEndpoint,
    this.otelTracesSamplerArg = 1,
    this.monitoringPort,
    this.requestLoggingEnabled = true,
    this.includeErrorStacks = false,
  });

  /// Reads configuration from process environment variables.
  factory ObservabilityConfig.fromEnvironment({
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final runtimeEnvironment = env['ENVIRONMENT'] ?? 'development';
    return ObservabilityConfig(
      serviceName: env['SERVICE_NAME'] ?? 'dart-edge-service',
      serviceVersion: env['SERVICE_VERSION'] ?? '0.0.0',
      environment: runtimeEnvironment,
      logLevel: LogLevel.parse(env['LOG_LEVEL']) ?? LogLevel.info,
      lokiUrl: _nonEmpty(env['LOKI_URL']),
      otlpTracesEndpoint: _nonEmpty(env['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT']),
      otelTracesSamplerArg:
          double.tryParse(env['OTEL_TRACES_SAMPLER_ARG'] ?? '') ?? 1,
      monitoringPort: int.tryParse(env['MONITORING_PORT'] ?? ''),
      requestLoggingEnabled: _parseBool(env['REQUEST_LOGGING_ENABLED']) ?? true,
      includeErrorStacks:
          runtimeEnvironment == 'development' || runtimeEnvironment == 'dev',
    );
  }

  final String serviceName;
  final String serviceVersion;
  final String environment;
  final LogLevel logLevel;
  final String? lokiUrl;
  final String? otlpTracesEndpoint;
  final double otelTracesSamplerArg;
  final int? monitoringPort;
  final bool requestLoggingEnabled;
  final bool includeErrorStacks;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

bool? _parseBool(String? value) {
  return switch (value?.toLowerCase().trim()) {
    'true' || '1' || 'yes' || 'on' => true,
    'false' || '0' || 'no' || 'off' => false,
    _ => null,
  };
}
