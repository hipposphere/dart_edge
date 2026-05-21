import 'dart:io';

import 'package:dart_edge_ci/dart_edge_ci.dart';
import 'package:test/test.dart';

void main() {
  test('generates Dockerfiles, nginx entrypoint, and bake targets', () async {
    final root = await _projectRoot();
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/docker.yaml').writeAsString(_dockerYaml);

    final result = await DockerGenerator(projectRoot: root).generate();

    expect(result.images.map((image) => image.name), [
      'server',
      'migrator',
      'app',
    ]);

    final serverDockerfile = await File(
      '${root.path}/.dart_tool/dart_edge_ci/docker/server/Dockerfile',
    ).readAsString();
    expect(serverDockerfile, contains('FROM debian:trixie-slim AS pjproject'));
    expect(serverDockerfile, contains('ARG PJPROJECT_VERSION=2.18'));
    expect(serverDockerfile, contains('RUN echo custom-build-step'));
    expect(
      serverDockerfile,
      contains('RUN dart build cli --target=bin/main.dart'),
    );
    expect(serverDockerfile, contains('EXPOSE 3000'));
    expect(serverDockerfile, contains('LD_PRELOAD=/usr/local/lib/libpjsua.so'));
    expect(
      serverDockerfile,
      contains('org.opencontainers.image.title="Callo Server"'),
    );
    expect(serverDockerfile, contains('ARG VERSION=1.0.0'));
    expect(
      serverDockerfile,
      contains(
        'COPY --parents pubspec.yaml pubspec.lock app/pubspec.yaml '
        'packages/db_migrator/pubspec.yaml server/pubspec.yaml ./',
      ),
    );

    final migratorDockerfile = await File(
      '${root.path}/.dart_tool/dart_edge_ci/docker/migrator/Dockerfile',
    ).readAsString();
    expect(migratorDockerfile, contains('libsqlite3-0'));
    expect(migratorDockerfile, contains('libpq5'));
    expect(migratorDockerfile, isNot(contains('zlib1g')));
    expect(migratorDockerfile, contains('ENTRYPOINT ["/app/bin/migrator"]'));

    final appDockerfile = await File(
      '${root.path}/.dart_tool/dart_edge_ci/docker/app/Dockerfile',
    ).readAsString();
    expect(
      appDockerfile,
      contains('FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build'),
    );
    expect(appDockerfile, contains('ARG BASE_HREF=/'));
    expect(appDockerfile, contains('flutter build web --release --wasm'));
    expect(appDockerfile, isNot(contains('--base-href')));
    expect(appDockerfile, contains('FROM nginx:1.29-alpine'));
    expect(
      appDockerfile,
      contains('RUN chmod +x /docker-entrypoint.d/99-dart-edge-env.sh'),
    );
    expect(appDockerfile, contains(r'flutter_bootstrap.js?v=$cache_tag'));

    final entrypoint = await File(
      '${root.path}/.dart_tool/dart_edge_ci/docker/app/nginx-env.sh',
    ).readAsString();
    expect(entrypoint, contains('API_URL is required'));
    expect(entrypoint, contains(r': "${BASE_HREF:=/}"'));
    expect(entrypoint, contains(r'env_file="$web_root/.env"'));
    expect(entrypoint, contains(r'env_url_file="$web_root/env-url.js"'));
    expect(entrypoint, contains('printf \'window.DART_EDGE_ENV_URL'));
    expect(entrypoint, contains('BASE_REDIRECT_PATH='));
    expect(
      entrypoint,
      contains(r'map \$arg_v \$dart_edge_static_cache_control'),
    );
    expect(entrypoint, contains(r'location = ${BASE_HREF}.env'));
    expect(entrypoint, contains(r'API_URL "${API_URL}"'));

    final bake = await result.bakeFile.readAsString();
    expect(bake, contains('target "server"'));
    expect(bake, contains('context = "../.."'));
    expect(
      bake,
      contains('dockerfile = ".dart_tool/dart_edge_ci/docker/app/Dockerfile"'),
    );
    expect(bake, contains('BASE_HREF = "/"'));
  });

  test('constructs docker buildx build command', () async {
    final root = await _projectRoot();
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/docker.yaml').writeAsString(_dockerYaml);
    final result = await DockerGenerator(
      projectRoot: root,
    ).generate(selectedImage: 'server');

    final command = buildxCommand(
      result.images.single,
      push: true,
      labels: result.labels,
    );

    expect(command.take(8), [
      'docker',
      'buildx',
      'build',
      '--file',
      '.dart_tool/dart_edge_ci/docker/server/Dockerfile',
      '--tag',
      'server',
      '--build-arg',
    ]);
    expect(command, contains('VERSION=1.0.0'));
    expect(command, contains('--push'));
    expect(command.last, '.');
  });
}

Future<Directory> _projectRoot() async {
  final root = await Directory.systemTemp.createTemp('dart_edge_ci_');
  await File('${root.path}/pubspec.yaml').writeAsString('''
name: workspace
version: 0.0.0
workspace:
  - server
  - app
  - packages/*
''');
  await File('${root.path}/pubspec.lock').writeAsString('');
  for (final entry in {
    'server': '1.0.0',
    'app': '2.0.0',
    'packages/db_migrator': '3.0.0',
  }.entries) {
    await Directory('${root.path}/${entry.key}').create(recursive: true);
    await File('${root.path}/${entry.key}/pubspec.yaml').writeAsString('''
name: ${entry.key.split('/').last}
version: ${entry.value}
''');
  }
  return root;
}

const _dockerYaml = '''
source: https://github.com/hipposphere/callo
flutter_version: 3.44.0
images:
  server:
    type: dart_server
    package: server
    target: bin/main.dart
    executable: main
    expose: 3000
    title: Callo Server
    description: Callo Server
    presets:
      pjproject:
        version: 2.18
    dockerfile:
      build_before_compile:
        - RUN echo custom-build-step

  migrator:
    type: db_migrator
    package: packages/db_migrator
    target: bin/migrator.dart
    executable: migrator
    title: Callo Migrator
    description: Callo database migrator
    databases:
      sqlite: true
      postgres: true
      pglite: false

  app:
    type: flutter_app
    package: app
    flutter_version: 3.44.0
    web:
      wasm: true
      base_href_env: BASE_HREF
    nginx:
      env:
        required:
          - API_URL
        optional:
          BASE_HREF: /
    title: Callo App
    description: Callo Flutter web app
''';
