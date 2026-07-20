import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_docs/src/codegen/docs_content_manifest_generator.dart';
import 'package:test/test.dart';

void main() {
  test('emits preferred quotes and round-trips arbitrary content', () async {
    final root = await Directory.systemTemp.createTemp(
      'dart_edge_docs_manifest_generator_',
    );
    addTearDown(() => root.delete(recursive: true));

    final input = Directory('${root.path}/content/docs');
    await input.create(recursive: true);
    const entries = <String, String>{
      'index.mdx': r'''# "Callo"
Use $clinic at C:\docs.
''',
      "patients/doctor's-guide.mdx": r'''The doctor's note says "follow up".
Charge $5.
''',
    };
    for (final MapEntry(key: path, value: content) in entries.entries) {
      final file = File('${input.path}/$path');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    final output = File('${root.path}/generated/docs_content_manifest.dart');
    await const DartEdgeDocsContentManifestGenerator().writeManifest(
      inputDirectory: input,
      outputFile: output,
      constantName: 'docsContentManifest',
    );

    final source = await output.readAsString();
    expect(source, contains("'index.mdx':"));
    expect(source, contains('"patients/doctor\'s-guide.mdx":'));
    expect(source, contains(r'\$clinic'));
    expect(source, contains(r'\$5'));
    expect(source, contains(r'C:\\docs'));

    final probe = File('${root.path}/probe.dart');
    await probe.writeAsString(_probeSource(entries));
    final result = await Process.run(Platform.resolvedExecutable, [probe.path]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}

String _probeSource(Map<String, String> entries) {
  final encodedEntries = entries.entries
      .map((entry) {
        final key = base64Encode(utf8.encode(entry.key));
        final value = base64Encode(utf8.encode(entry.value));
        return "  ('$key', '$value'),";
      })
      .join('\n');

  return '''
import 'dart:convert';

import 'generated/docs_content_manifest.dart';

void main() {
  const entries = <(String, String)>[
$encodedEntries
  ];
  for (final (encodedKey, encodedValue) in entries) {
    final key = utf8.decode(base64Decode(encodedKey));
    final value = utf8.decode(base64Decode(encodedValue));
    if (docsContentManifest[key] != value) {
      throw StateError('Manifest value did not round-trip for \$key.');
    }
  }
}
''';
}
