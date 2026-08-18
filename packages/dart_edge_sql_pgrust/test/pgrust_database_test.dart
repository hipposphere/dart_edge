import 'dart:async';
import 'dart:io';

import 'package:dart_edge_sql_pgrust/dart_edge_sql_pgrust.dart';
import 'package:test/test.dart';

void main() {
  late Directory fixtureDirectory;
  late String initdbExecutable;
  late String pgrustExecutable;

  setUp(() async {
    fixtureDirectory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_pgrust_test_',
    );
    initdbExecutable = await _writeExecutable(
      fixtureDirectory,
      'fake_initdb.dart',
      _fakeInitdbSource,
    );
    pgrustExecutable = await _writeExecutable(
      fixtureDirectory,
      'fake_pgrust.dart',
      _fakePgrustSource,
    );
  });

  tearDown(() async {
    if (await fixtureDirectory.exists()) {
      await fixtureDirectory.delete(recursive: true);
    }
  });

  test('temporary starts a server and deletes its data directory', () async {
    final database = await PgrustDatabase.temporary(
      executable: pgrustExecutable,
      initdbExecutable: initdbExecutable,
      startupTimeout: const Duration(seconds: 5),
    );
    final storageDirectory = Directory(database.storagePath);

    expect(await storageDirectory.exists(), isTrue);
    expect(
      await File('${storageDirectory.path}/PG_VERSION').readAsString(),
      '18\n',
    );
    expect(database.connectionString, contains(':${database.port}/postgres'));
    expect(database.processId, greaterThan(0));

    await database.close();
    await database.close();

    expect(await storageDirectory.exists(), isFalse);
    expect(await database.exitCode, 0);
  });

  test('open preserves a persistent initialized data directory', () async {
    final dataDirectory = Directory('${fixtureDirectory.path}/database');
    final first = await PgrustDatabase.open(
      dataDirectory.path,
      executable: pgrustExecutable,
      initdbExecutable: initdbExecutable,
      startupTimeout: const Duration(seconds: 5),
    );
    await first.close();

    final marker = File('${dataDirectory.path}/initdb-count');
    expect(await marker.readAsString(), '1');

    final second = await PgrustDatabase.open(
      dataDirectory.path,
      executable: pgrustExecutable,
      initdbExecutable: initdbExecutable,
      startupTimeout: const Duration(seconds: 5),
    );
    await second.close();

    expect(await dataDirectory.exists(), isTrue);
    expect(await marker.readAsString(), '1');
  });

  test('refuses to initialize a non-empty unknown directory', () async {
    final dataDirectory = Directory('${fixtureDirectory.path}/database');
    await dataDirectory.create();
    await File('${dataDirectory.path}/unrelated.txt').writeAsString('keep me');

    await expectLater(
      PgrustDatabase.open(
        dataDirectory.path,
        executable: pgrustExecutable,
        initdbExecutable: initdbExecutable,
      ),
      throwsA(
        isA<PgrustException>().having(
          (error) => error.message,
          'message',
          contains('non-empty data directory'),
        ),
      ),
    );

    expect(
      await File('${dataDirectory.path}/unrelated.txt').readAsString(),
      'keep me',
    );
  });

  test('rejects a data directory from another PostgreSQL major', () async {
    final dataDirectory = Directory('${fixtureDirectory.path}/database');
    await dataDirectory.create();
    await File('${dataDirectory.path}/PG_VERSION').writeAsString('17\n');

    await expectLater(
      PgrustDatabase.open(
        dataDirectory.path,
        executable: pgrustExecutable,
        initdbExecutable: initdbExecutable,
      ),
      throwsA(
        isA<PgrustException>().having(
          (error) => error.message,
          'message',
          allOf(contains('PostgreSQL 18'), contains('PG_VERSION 17')),
        ),
      ),
    );
  });

  test('reports a server that exits before listening', () async {
    final failingExecutable = await _writeExecutable(
      fixtureDirectory,
      'failing_pgrust.dart',
      _failingPgrustSource,
    );

    await expectLater(
      PgrustDatabase.temporary(
        executable: failingExecutable,
        initdbExecutable: initdbExecutable,
        startupTimeout: const Duration(seconds: 5),
      ),
      throwsA(
        isA<PgrustException>().having(
          (error) => error.message,
          'message',
          contains('exited with code 23'),
        ),
      ),
    );
  });
}

Future<String> _writeExecutable(
  Directory directory,
  String name,
  String source,
) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('#!${Platform.resolvedExecutable}\n$source');
  final result = await Process.run('chmod', ['+x', file.path]);
  if (result.exitCode != 0) {
    throw StateError(
      'Could not make ${file.path} executable: ${result.stderr}',
    );
  }
  return file.path;
}

const _fakeInitdbSource = r'''
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final dataIndex = arguments.indexOf('-D');
  if (dataIndex < 0 || dataIndex + 1 >= arguments.length) {
    stderr.writeln('missing -D');
    exitCode = 2;
    return;
  }
  final directory = Directory(arguments[dataIndex + 1]);
  await directory.create(recursive: true);
  await File('${directory.path}/PG_VERSION').writeAsString('18\n');
  final marker = File('${directory.path}/initdb-count');
  final count = await marker.exists()
      ? int.parse(await marker.readAsString())
      : 0;
  await marker.writeAsString('${count + 1}');
}
''';

const _fakePgrustSource = r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final portIndex = arguments.indexOf('-p');
  if (portIndex < 0 || portIndex + 1 >= arguments.length) {
    stderr.writeln('missing -p');
    exit(2);
  }
  final port = int.parse(arguments[portIndex + 1]);
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);

  StreamSubscription<ProcessSignal>? interruptSubscription;
  StreamSubscription<ProcessSignal>? terminateSubscription;
  Future<void> stop(ProcessSignal signal) async {
    await interruptSubscription?.cancel();
    await terminateSubscription?.cancel();
    await server.close();
    exit(0);
  }

  interruptSubscription = ProcessSignal.sigint.watch().listen(stop);
  terminateSubscription = ProcessSignal.sigterm.watch().listen(stop);
  stdout.writeln('fake pgrust listening on $port');
  await Completer<void>().future;
}
''';

const _failingPgrustSource = r'''
import 'dart:io';

void main() {
  stderr.writeln('intentional startup failure');
  exit(23);
}
''';
