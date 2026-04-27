import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_edge_docker/builder.dart';
import 'package:test/test.dart';

void main() {
  test('generates Docker assets from a Dart config object', () async {
    final builder = dartEdgeDockerBuilder(
      BuilderOptions(const <String, Object?>{}),
    );

    await testBuilder(
      builder,
      const <String, String>{
        'app|lib/docker.dart': '''
import 'package:dart_edge_docker/dart_edge_docker.dart';

const docker = DartEdgeDockerConfig(
  imageName: 'my-api',
  entrypoint: 'bin/server.dart',
  executableName: 'api',
  ports: [8080],
  environment: {'DART_EDGE_HOST': '0.0.0.0'},
  buildArgs: {'APP_ENV': 'production'},
  labels: {'org.opencontainers.image.title': 'My API'},
  extraFiles: ['config'],
  compileArgs: ['--verbosity=warning'],
  runtimeArgs: ['--serve'],
);
''',
      },
      outputs: {
        'app|lib/docker.dockerfile': decodedMatches(
          allOf([
            contains('FROM \${DART_SDK_IMAGE} AS build'),
            contains('ARG APP_ENV=production'),
            contains('RUN dart pub get'),
            contains(
              'dart compile exe bin/server.dart -o /app/build/api --verbosity=warning',
            ),
            contains('COPY --from=build /app/build/ ./'),
            contains('COPY --from=build /app/config ./config'),
            contains('ENV DART_EDGE_HOST=0.0.0.0'),
            contains('EXPOSE 8080'),
            contains('ENTRYPOINT ["./api","--serve"]'),
          ]),
        ),
        'app|lib/docker.dockerignore': decodedMatches(
          allOf([contains('.dart_tool/'), contains('*.docker_build.json')]),
        ),
        'app|lib/docker.docker_build.json': decodedMatches(
          allOf([
            contains('"imageName": "my-api"'),
            contains('"dockerfile": "lib/docker.dockerfile"'),
            contains('"docker"'),
            contains('"build"'),
          ]),
        ),
      },
    );
  });
}
