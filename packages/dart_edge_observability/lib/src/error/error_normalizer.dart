/// Stable error fields for logs and traces.
final class NormalizedError {
  const NormalizedError({
    required this.errorName,
    required this.errorMessage,
    this.stackTrace,
  });

  final String errorName;
  final String errorMessage;
  final String? stackTrace;

  Map<String, Object?> toLogFields() => <String, Object?>{
    'errorName': errorName,
    'errorMessage': errorMessage,
    'stackTrace': ?stackTrace,
  };
}

/// Converts thrown Dart errors into stable, payload-free observability fields.
NormalizedError normalizeError(
  Object error, {
  StackTrace? stackTrace,
  bool includeStackTrace = false,
}) {
  return NormalizedError(
    errorName: error.runtimeType.toString(),
    errorMessage: '$error',
    stackTrace: includeStackTrace ? stackTrace?.toString() : null,
  );
}
