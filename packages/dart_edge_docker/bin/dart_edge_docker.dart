import 'dart:io' as io;

import 'package:dart_edge_docker/src/cli.dart';

Future<void> main(List<String> arguments) async {
  io.exitCode = await runDartEdgeDocker(arguments);
}
