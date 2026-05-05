/// Error raised when a Wi-Fi operation fails.
final class WifiException implements Exception {
  const WifiException(this.message, {this.exitCode, this.stderr});

  final String message;
  final int? exitCode;
  final String? stderr;

  @override
  String toString() {
    final buffer = StringBuffer('WifiException: $message');
    if (exitCode != null) {
      buffer.write(' (exit code $exitCode)');
    }
    if (stderr case final stderr? when stderr.isNotEmpty) {
      buffer.write(': $stderr');
    }
    return buffer.toString();
  }
}
