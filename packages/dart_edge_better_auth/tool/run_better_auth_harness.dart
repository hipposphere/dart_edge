import 'dart:io';

Future<void> main(List<String> args) async {
  final packageRoot = Directory.current;
  final fixture = Directory('test/node_better_auth_interop');
  if (!fixture.existsSync()) {
    stderr.writeln('Missing Node interop fixture at ${fixture.path}.');
    exitCode = 64;
    return;
  }

  final npmInstall = await _run('npm', ['ci'], workingDirectory: fixture.path);
  if (npmInstall != 0) {
    exitCode = npmInstall;
    return;
  }

  final test = await _run('dart', [
    'test',
    '-r',
    'expanded',
  ], workingDirectory: packageRoot.path);
  exitCode = test;
}

Future<int> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  stdout.writeln([executable, ...arguments].join(' '));
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
