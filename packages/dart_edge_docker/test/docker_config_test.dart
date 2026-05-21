import 'dart:io';

import 'package:dart_edge_docker/dart_edge_docker.dart';
import 'package:test/test.dart';

void main() {
  test('parses typed image configs from docker.yaml', () {
    final config = DockerProjectConfig.parse('''
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
      build_before_pub_get:
        - RUN apt-get update
  migrator:
    type: db_migrator
    package: packages/db_migrator
    target: bin/migrator.dart
    databases:
      all: true
  app:
    type: flutter_app
    package: app
    flutter_version: 3.44.0
    web:
      wasm: true
      renderer: auto
      base_href_env: BASE_HREF
    nginx:
      env:
        required:
          - API_URL
        optional:
          BASE_HREF: /
''');

    final server = config.images['server'] as DartServerImageConfig;
    expect(server.target, 'bin/main.dart');
    expect(server.executable, 'main');
    expect(server.expose, 3000);
    expect(server.presets.pjproject?.version, '2.18');
    expect(server.dockerfile.buildBeforePubGet, ['RUN apt-get update']);

    final migrator = config.images['migrator'] as DbMigratorImageConfig;
    expect(migrator.databases.sqlite, isTrue);
    expect(migrator.databases.postgres, isTrue);
    expect(migrator.databases.pglite, isTrue);

    final app = config.images['app'] as FlutterAppImageConfig;
    expect(app.flutterVersion, '3.44.0');
    expect(app.web.wasm, isTrue);
    expect(app.web.baseHrefEnv, 'BASE_HREF');
    expect(app.nginx.requiredEnv, ['API_URL']);
    expect(app.nginx.optionalEnv, {'BASE_HREF': '/'});
  });

  test('reports clear validation errors', () {
    expect(
      () => DockerProjectConfig.parse('''
images:
  api:
    type: unknown
    package: server
'''),
      throwsA(
        isA<DockerConfigException>().having(
          (error) => error.message,
          'message',
          contains('images.api.type must be one of'),
        ),
      ),
    );
  });

  test('reads image version from configured package pubspec', () async {
    final root = await Directory.systemTemp.createTemp('dart_edge_docker_');
    addTearDown(() => root.delete(recursive: true));
    await Directory('${root.path}/server').create(recursive: true);
    await File('${root.path}/server/pubspec.yaml').writeAsString('''
name: server
version: 1.2.3
''');

    final config = DockerProjectConfig.parse('''
images:
  server:
    type: dart_server
    package: server
    target: bin/main.dart
''', projectRoot: root);

    expect(config.images['server']!.version, '1.2.3');
  });
}
