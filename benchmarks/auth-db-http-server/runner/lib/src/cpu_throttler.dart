import 'dart:async';
import 'dart:io';

/// Soft CPU cap that keeps one process near a target total CPU percentage.
///
/// On Unix platforms this approximates a single-core limit by periodically
/// sampling process CPU usage and briefly pausing the process when it exceeds
/// the configured budget.
final class CpuThrottler {
  CpuThrottler({
    required this.pid,
    this.targetCpuPercent = 100,
    this.interval = const Duration(milliseconds: 100),
  });

  final int pid;
  final double targetCpuPercent;
  final Duration interval;

  Timer? _timer;
  Timer? _resumeTimer;
  var _paused = false;
  var _disposed = false;

  bool get isSupported => Platform.isMacOS || Platform.isLinux;

  Future<void> start() async {
    if (!isSupported || _disposed) {
      return;
    }

    await _tick();
    _timer = Timer.periodic(interval, (_) {
      unawaited(_tick());
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    if (_paused) {
      _send(ProcessSignal.sigcont);
      _paused = false;
    }
  }

  Future<void> _tick() async {
    if (_disposed || _paused) {
      return;
    }

    final cpuPercent = await _readCpuPercent();
    if (cpuPercent == null || cpuPercent <= targetCpuPercent) {
      return;
    }

    final pauseFraction = 1 - (targetCpuPercent / cpuPercent);
    final pauseMs = (interval.inMilliseconds * pauseFraction)
        .clamp(1, (interval.inMilliseconds * 0.9).round())
        .round();

    if (!_send(ProcessSignal.sigstop)) {
      return;
    }
    _paused = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(Duration(milliseconds: pauseMs), () {
      if (_disposed) {
        return;
      }
      _send(ProcessSignal.sigcont);
      _paused = false;
    });
  }

  Future<double?> _readCpuPercent() async {
    try {
      final result = await Process.run('ps', ['-o', '%cpu=', '-p', '$pid']);
      if (result.exitCode != 0) {
        return null;
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return null;
      }

      return double.tryParse(output);
    } on ProcessException {
      return null;
    }
  }

  bool _send(ProcessSignal signal) {
    try {
      return Process.killPid(pid, signal);
    } on ProcessException {
      return false;
    }
  }
}
