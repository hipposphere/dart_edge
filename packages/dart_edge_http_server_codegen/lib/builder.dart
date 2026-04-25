import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/builder/dart_edge_http_server_builder.dart';

/// Builder entrypoint used by `build_runner`.
Builder dartEdgeHttpServerBuilder(BuilderOptions options) {
  return SharedPartBuilder([
    DartEdgeHttpServerBuilderGenerator(options),
  ], 'dart_edge_http_server');
}
