import 'dart:async';
import 'dart:math';

/// Request-scoped observability values propagated through Dart zones.
final class ObservabilityRequestContext {
  const ObservabilityRequestContext({
    required this.requestId,
    this.traceId,
    this.spanId,
    this.userId,
    this.workspaceId,
    this.route,
    this.method,
  });

  final String requestId;
  final String? traceId;
  final String? spanId;
  final String? userId;
  final String? workspaceId;
  final String? route;
  final String? method;

  ObservabilityRequestContext copyWith({
    String? requestId,
    String? traceId,
    String? spanId,
    String? userId,
    String? workspaceId,
    String? route,
    String? method,
  }) {
    return ObservabilityRequestContext(
      requestId: requestId ?? this.requestId,
      traceId: traceId ?? this.traceId,
      spanId: spanId ?? this.spanId,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      route: route ?? this.route,
      method: method ?? this.method,
    );
  }

  Map<String, Object?> toLogFields() => <String, Object?>{
    'requestId': requestId,
    'traceId': ?traceId,
    'spanId': ?spanId,
    'userId': ?userId,
    'workspaceId': ?workspaceId,
    'route': ?route,
    'method': ?method,
  };
}

/// Zone-backed access to the current request context.
abstract final class ObservabilityContext {
  static const Object _zoneKey = #dartEdgeObservabilityRequestContext;

  static ObservabilityRequestContext? get current =>
      Zone.current[_zoneKey] as ObservabilityRequestContext?;

  static R run<R>(ObservabilityRequestContext context, R Function() fn) {
    return runZoned(fn, zoneValues: <Object?, Object?>{_zoneKey: context});
  }
}

/// Extracts an inbound request id or generates one.
String requestIdFromHeaders(Map<String, String> headers) {
  final explicit = headers['x-request-id'] ?? headers['x-correlation-id'];
  if (explicit != null && explicit.trim().isNotEmpty) {
    return explicit.trim();
  }
  return generateRequestId();
}

/// Generates a compact random request id.
String generateRequestId() => _randomHex(16);

/// Generates an OpenTelemetry-compatible trace id.
String generateTraceId() => _randomHex(32);

/// Generates an OpenTelemetry-compatible span id.
String generateSpanId() => _randomHex(16);

TraceParent? parseTraceParent(String? value) {
  if (value == null) {
    return null;
  }
  final parts = value.trim().split('-');
  if (parts.length < 4 || parts[1].length != 32 || parts[2].length != 16) {
    return null;
  }
  return TraceParent(traceId: parts[1], parentSpanId: parts[2]);
}

final class TraceParent {
  const TraceParent({required this.traceId, required this.parentSpanId});

  final String traceId;
  final String parentSpanId;
}

final Random _random = Random.secure();

String _randomHex(int length) {
  const chars = '0123456789abcdef';
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(chars[_random.nextInt(chars.length)]);
  }
  return buffer.toString();
}
