import 'package:build/build.dart';

import 'src/dart_edge_docker_builder.dart';

/// Builder entrypoint used by `build_runner`.
Builder dartEdgeDockerBuilder(BuilderOptions options) {
  return DartEdgeDockerBuilder(options);
}
