# dart_edge_docker

Build runner helpers for generating Docker assets for Dart Edge apps.

Define a `const DartEdgeDockerConfig` in Dart:

```dart
import 'package:dart_edge_docker/dart_edge_docker.dart';

const docker = DartEdgeDockerConfig(
  imageName: 'my-api',
  entrypoint: 'bin/server.dart',
  executableName: 'server',
  ports: [8080],
  environment: {'DART_EDGE_HOST': '0.0.0.0'},
);
```

Run build runner:

```sh
dart run build_runner build
```

The builder emits:

- `*.dockerfile`
- `*.dockerignore`
- `*.docker_build.json`

The generated Dockerfile builds a compiled Dart AOT executable in a Dart SDK
stage and copies the compiled output into a slim runtime stage.
