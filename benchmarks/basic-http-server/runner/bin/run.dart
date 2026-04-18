import 'dart:io';

import 'package:dart_edge_benchmark_runner/dart_edge_benchmark_runner.dart';

Future<void> main(List<String> args) async {
  BenchmarkOptions options;

  try {
    options = BenchmarkOptions.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln();
    stderr.writeln(BenchmarkOptions.usage);
    exitCode = 64;
    return;
  }

  if (options.showHelp) {
    stdout.writeln(BenchmarkOptions.usage);
    return;
  }

  final report = await BenchmarkHarness(options: options, output: stdout).run();

  if (options.jsonOut case final jsonOut?) {
    final file = File(jsonOut).absolute;
    await file.writeAsString(report.toPrettyJson());
    stdout.writeln('\nWrote JSON report to ${file.path}');
  }
}
