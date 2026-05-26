import 'dart:async';
import 'dart:io';

String shellCommand(Iterable<String> command) {
  return command.map(_shellQuote).join(' ');
}

String _shellQuote(String value) {
  if (value.isEmpty) {
    return "''";
  }
  if (!RegExp(r'''[\s'"$`\\]''').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", "'\\''")}'";
}

final class CommandProcessRunner {
  const CommandProcessRunner();

  Future<int> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  Future<ProcessResult> runBuffered(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}

Future<void> writeGithubSummary(String markdown) async {
  final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryPath == null || summaryPath.isEmpty) {
    return;
  }
  await File(summaryPath).writeAsString(markdown, mode: FileMode.append);
}
