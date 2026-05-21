import 'package:dart_edge_ci/dart_edge_ci.dart';
import 'package:test/test.dart';

void main() {
  test('formats Docker generate output for GitHub Actions', () {
    const output = DockerGenerateOutput(
      image: 'server',
      dockerfile: '.dart_tool/dart_edge_ci/docker/server/Dockerfile',
      context: '.',
    );

    expect(output.toMap(), {
      'image': 'server',
      'dockerfile': '.dart_tool/dart_edge_ci/docker/server/Dockerfile',
      'context': '.',
    });
    expect(output.toEnv(), '''
image=server
dockerfile=.dart_tool/dart_edge_ci/docker/server/Dockerfile
context=.
''');
  });
}
