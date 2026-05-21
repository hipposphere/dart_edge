import 'dart:io';

import 'package:dart_edge_ci/dart_edge_ci.dart';
import 'package:test/test.dart';

void main() {
  test('reads version and derives version tag from pubspec.yaml', () async {
    final root = await Directory.systemTemp.createTemp('dart_edge_ci_');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/pubspec.yaml').writeAsString('''
name: app
version: 1.2.3+45
''');

    final version = await PackageVersionOutput.read(root);

    expect(version.version, '1.2.3+45');
    expect(version.versionTag, 'v1.2.3-45');
    expect(version.toEnv(), 'version=1.2.3+45\nversion_tag=v1.2.3-45\n');
    expect(version.toMap(), {
      'version': '1.2.3+45',
      'version_tag': 'v1.2.3-45',
    });
  });

  test('does not double-prefix version tags that already start with v', () {
    final version = PackageVersionOutput.fromPubspecVersion('v2.0.0');

    expect(version.versionTag, 'v2.0.0');
  });
}
