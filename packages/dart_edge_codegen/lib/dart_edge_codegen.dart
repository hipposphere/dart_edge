/// Build-time annotations and metadata contracts for Dart Edge code generation.
///
/// Import this library from generator-facing code or annotated source when you
/// want to describe route metadata in a structured way without depending on the
/// full runtime implementation.
library dart_edge_codegen;

export 'src/annotations.dart';
export 'src/client/dart_edge_client_codec.dart';
export 'src/client/dart_edge_client_generator.dart';
export 'src/client/dart_edge_client_transport.dart';
export 'src/client/dart_edge_generated_client_base.dart';
export 'src/typed_json_route.dart';
