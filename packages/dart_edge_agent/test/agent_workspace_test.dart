import 'dart:io';

import 'package:dart_edge_agent/dart_edge_agent.dart';
import 'package:dart_edge_rig/dart_edge_rig.dart';
import 'package:test/test.dart';

void main() {
  test('local workspace reads, writes, lists, and searches files', () async {
    final temp = await Directory.systemTemp.createTemp('dart_edge_agent_test_');
    addTearDown(() => temp.delete(recursive: true));

    final workspace = LocalAgentWorkspace(temp);
    await workspace.writeText('lib/example.txt', 'hello agent');

    expect(await workspace.readText('lib/example.txt'), 'hello agent');
    expect(await workspace.listFiles(), contains('lib/example.txt'));
    expect(await workspace.searchText('agent'), contains('lib/example.txt'));
  });

  test('workspace tools expose typed schemas and callbacks', () async {
    final temp = await Directory.systemTemp.createTemp(
      'dart_edge_agent_tools_',
    );
    addTearDown(() => temp.delete(recursive: true));

    final workspace = LocalAgentWorkspace(temp);
    final tools = WorkspaceRigTools.all(workspace);

    expect(tools.map((tool) => tool.name), contains('write_file'));
    final write = tools.singleWhere((tool) => tool.name == 'write_file');
    await write.call(<String, Object?>{
      'path': 'notes.txt',
      'content': 'tool output',
    });

    final read = tools.singleWhere((tool) => tool.name == 'read_file');
    expect(
      await read.call(<String, Object?>{'path': 'notes.txt'}),
      <String, Object?>{'content': 'tool output'},
    );

    final list = tools.singleWhere((tool) => tool.name == 'list_files');
    final listResult = await list.call(<String, Object?>{}) as Map;
    expect(listResult['files'], contains('notes.txt'));
  });

  test('local workspace rejects paths outside the root', () async {
    final temp = await Directory.systemTemp.createTemp(
      'dart_edge_agent_escape_',
    );
    addTearDown(() => temp.delete(recursive: true));

    final workspace = LocalAgentWorkspace(temp);

    expect(
      workspace.writeText('../outside.txt', 'nope'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('attachment helpers build Rig user content from files', () async {
    final temp = await Directory.systemTemp.createTemp(
      'dart_edge_agent_attachment_',
    );
    addTearDown(() => temp.delete(recursive: true));

    final notes = File('${temp.path}/notes.md');
    await notes.writeAsString('# Notes');
    final image = File('${temp.path}/diagram.png');
    await image.writeAsBytes(<int>[1, 2, 3]);

    final textAttachment = await AgentAttachment.textFile(notes);
    expect(textAttachment, isA<RigDocumentContent>());
    expect(textAttachment.toJson(), {
      'type': 'document',
      'data': {'type': 'string', 'value': '# Notes'},
      'media_type': 'markdown',
    });

    final imageAttachment = await AgentAttachment.imageFile(image);
    expect(imageAttachment, isA<RigImageContent>());
    expect(imageAttachment.toJson(), {
      'type': 'image',
      'data': {'type': 'base64', 'value': 'AQID'},
      'media_type': 'png',
    });
  });
}
