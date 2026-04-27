import 'package:dart_edge_docker/dart_edge_docker.dart';

const docker = DartEdgeDockerConfig(
  imageName: 'dart-edge-api',
  entrypoint: 'bin/server.dart',
  executableName: 'server',
  ports: [8080],
  environment: {'DART_EDGE_HOST': '0.0.0.0', 'DART_EDGE_PORT': '8080'},
  labels: {'org.opencontainers.image.title': 'Dart Edge API'},
  extraFiles: ['config'],
);
