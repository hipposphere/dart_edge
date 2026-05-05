/// Result from a command executed by [DartEdgeWifi].
final class WifiCommandResult {
  const WifiCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
