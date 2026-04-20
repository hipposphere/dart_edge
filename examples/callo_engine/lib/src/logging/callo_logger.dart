typedef CalloLogSink = void Function(String message);

void _discardLog(String message) {}

final class CalloLogger {
  const CalloLogger({required this.info, required this.error});

  static final silent = CalloLogger(info: _discardLog, error: _discardLog);

  final CalloLogSink info;
  final CalloLogSink error;
}
