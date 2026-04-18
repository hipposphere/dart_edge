/// Core runtime and shared contract library for Dart Edge.
///
/// Import this library when you want direct access to the runtime surface,
/// including [DartEdge], the request/response contracts, JSON Schema registry
/// types, and the native transport bridge.
library dart_edge_runtime;

export 'package:dart_edge_core/dart_edge_core.dart';

export 'src/native/dart_edge_native.dart';
export 'src/runtime/dart_edge.dart';
export 'src/runtime/dart_edge_codec.dart';
export 'src/runtime/dart_edge_server.dart';
export 'src/runtime/open_api_document.dart';
export 'src/runtime/open_telemetry_config.dart';
export 'src/runtime/rust_middleware.dart';
export 'src/runtime/transport_request.dart';
