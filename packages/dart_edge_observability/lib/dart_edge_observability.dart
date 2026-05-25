/// Observability primitives for Dart Edge services.
///
/// This package owns generic logging, metrics, tracing, request correlation,
/// and Dart Edge route instrumentation. Product packages should define their
/// own business metric names, labels, and domain events on top of these APIs.
library;

export 'src/config/observability_config.dart';
export 'src/context/observability_context.dart';
export 'src/error/error_normalizer.dart';
export 'src/http/dart_edge_observability.dart';
export 'src/logging/json_logger.dart';
export 'src/logging/log_helpers.dart';
export 'src/metrics/metrics.dart';
export 'src/tracing/tracing.dart';
