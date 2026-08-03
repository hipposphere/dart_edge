/// Failure while initializing, starting, or stopping a managed pgrust server.
final class PgrustException implements Exception {
  /// Creates a pgrust lifecycle failure.
  const PgrustException(this.message, {this.command, this.logs = const []});

  /// Human-readable description of the failure.
  final String message;

  /// Command associated with the failure, when available.
  final String? command;

  /// Most recent captured pgrust output lines.
  final List<String> logs;

  @override
  String toString() {
    final commandText = command == null ? '' : '\nCommand: $command';
    final logText = logs.isEmpty
        ? ''
        : '\nRecent pgrust output:\n${logs.join('\n')}';
    return 'PgrustException: $message$commandText$logText';
  }
}
