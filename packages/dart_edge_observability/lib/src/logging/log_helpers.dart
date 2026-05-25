import '../error/error_normalizer.dart';
import 'json_logger.dart';

void logOperationStarted(
  JsonLogger logger, {
  required String name,
  Map<String, Object?> attributes = const <String, Object?>{},
}) {
  logger.info(
    'operation.started',
    fields: <String, Object?>{'operation': name, ...attributes},
  );
}

void logOperationCompleted(
  JsonLogger logger, {
  required String name,
  required Duration duration,
  Map<String, Object?> attributes = const <String, Object?>{},
}) {
  logger.info(
    'operation.completed',
    fields: <String, Object?>{
      'operation': name,
      'durationMs': duration.inMicroseconds / 1000,
      ...attributes,
    },
  );
}

void logOperationFailed(
  JsonLogger logger, {
  required String name,
  required Duration duration,
  required Object error,
  StackTrace? stackTrace,
  bool includeStackTrace = false,
  Map<String, Object?> attributes = const <String, Object?>{},
}) {
  logger.error(
    'operation.failed',
    fields: <String, Object?>{
      'operation': name,
      'durationMs': duration.inMicroseconds / 1000,
      ...normalizeError(
        error,
        stackTrace: stackTrace,
        includeStackTrace: includeStackTrace,
      ).toLogFields(),
      ...attributes,
    },
  );
}
