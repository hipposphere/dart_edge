/// Build-time generator-facing APIs for Dart Edge HTTP.
///
/// App-facing schema annotations are owned by `dart_edge_core` and re-exported
/// here for compatibility with older imports.
library dart_edge_http_server_codegen;

export 'src/annotations.dart';
export 'src/client/dart_edge_client_generator.dart';
export 'src/client/dart_edge_client_transport.dart';
export 'src/client/dart_edge_generated_client_base.dart';
export 'src/http_server/dart_edge_http_server_generator.dart';
