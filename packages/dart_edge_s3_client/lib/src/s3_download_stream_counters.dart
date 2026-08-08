/// Process-wide lifecycle counters for native S3 download streams.
final class S3DownloadStreamCounters {
  const S3DownloadStreamCounters({
    required this.active,
    required this.started,
    required this.completed,
    required this.canceled,
    required this.failed,
  });

  /// Streams that currently own a native response body.
  final int active;

  /// Streams successfully opened since process start.
  final int started;

  /// Streams that reached the end of their response body.
  final int completed;

  /// Streams explicitly canceled or closed with their client.
  final int canceled;

  /// Streams terminated by an S3 body read failure.
  final int failed;
}
