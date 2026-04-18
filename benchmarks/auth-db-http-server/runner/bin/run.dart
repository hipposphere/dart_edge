import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_runner/dart_edge_auth_db_benchmark_runner.dart';

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
    await file.parent.create(recursive: true);
    await file.writeAsString(report.toPrettyJson());
    stdout.writeln('\nWrote JSON report to ${file.path}');
  }

  if (options.markdownOut case final markdownOut?) {
    final file = File(markdownOut).absolute;
    await file.parent.create(recursive: true);
    await file.writeAsString(buildMarkdownReport(report));
    stdout.writeln('Wrote markdown report to ${file.path}');
  }
}
