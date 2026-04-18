/// Core runtime and shared contract library for Dart Edge.
///
/// Import this library when you want direct access to the runtime surface,
/// including [DartEdge], the request/response contracts, JSON Schema registry
/// types, and the native transport bridge.
library dart_edge_runtime;

export 'src/context/request_context.dart';
export 'src/context/request_input.dart';
export 'src/context/request_telemetry.dart';
export 'src/context/web_socket_context.dart';
export 'src/contracts/http/error_response.dart';
export 'src/contracts/http/http_method.dart';
export 'src/contracts/http/json_encodable.dart';
export 'src/contracts/http/json_schema_definition.dart';
export 'src/contracts/http/json_schema_ref.dart';
export 'src/contracts/http/json_schema_registry.dart';
export 'src/contracts/http/raw_response.dart';
export 'src/contracts/http/request_body.dart';
export 'src/contracts/http/response_set.dart';
export 'src/contracts/http/response_spec.dart';
export 'src/contracts/http/route_contract.dart';
export 'src/contracts/web_socket/incoming_web_socket_messages.dart';
export 'src/contracts/web_socket/web_socket_contract.dart';
export 'src/native/dart_edge_native.dart';
export 'src/routes/handler_json_route_definition.dart';
export 'src/routes/json_route_definition.dart';
export 'src/routes/route_definition.dart';
export 'src/routes/web_socket_route_definition.dart';
export 'src/runtime/dart_edge.dart';
export 'src/runtime/dart_edge_codec.dart';
export 'src/runtime/dart_edge_server.dart';
export 'src/runtime/open_api_document.dart';
export 'src/runtime/open_telemetry_config.dart';
export 'src/runtime/route_options.dart';
export 'src/runtime/router.dart';
export 'src/runtime/rust_middleware.dart';
export 'src/runtime/transport_request.dart';
