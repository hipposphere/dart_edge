import 'open_telemetry_config.dart';

/// Declarative middleware entry consumed by the Rust transport layer.
///
/// Add these to [DartEdge.middlewares] to configure server-level behavior that
/// runs before a request reaches Dart route handlers.
final class RustMiddleware {
  const RustMiddleware._(this.name, [this.configuration]);

  /// Stable middleware identifier understood by the native runtime.
  final String name;

  /// Optional middleware-specific configuration payload.
  final Object? configuration;

  /// Attaches or generates a request id for each request.
  static RustMiddleware requestId() => const RustMiddleware._('requestId');

  /// Enables tracing and optional OpenTelemetry export.
  static RustMiddleware tracing({OpenTelemetryConfig? openTelemetry}) {
    return RustMiddleware._('tracing', openTelemetry);
  }

  /// Configures basic CORS handling.
  static RustMiddleware cors({
    List<String> allowOrigins = const <String>[],
    List<String> allowHeaders = const <String>[],
  }) {
    return RustMiddleware._('cors', (
      allowOrigins: allowOrigins,
      allowHeaders: allowHeaders,
    ));
  }

  /// Enables response compression when the client supports it.
  static RustMiddleware compression() => const RustMiddleware._('compression');

  /// Rejects request bodies larger than [maxBytes].
  static RustMiddleware bodyLimit({required int maxBytes}) {
    return RustMiddleware._('bodyLimit', maxBytes);
  }
}
