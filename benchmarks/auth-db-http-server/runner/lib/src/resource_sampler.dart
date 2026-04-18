import 'dart:async';
import 'dart:io';

/// Aggregate CPU and memory statistics sampled from a server process.
final class ResourceUsageSummary {
  const ResourceUsageSummary({
    required this.averageCpuPercent,
    required this.peakCpuPercent,
    required this.averageMemoryMb,
    required this.peakMemoryMb,
  });

  final double averageCpuPercent;
  final double peakCpuPercent;
  final double averageMemoryMb;
  final double peakMemoryMb;
}

/// Periodically samples CPU and RSS for one process id.
final class ResourceSampler {
  ResourceSampler({
    required this.pid,
    this.interval = const Duration(milliseconds: 250),
  });

  final int pid;
  final Duration interval;
  final List<_ResourceSample> _samples = <_ResourceSample>[];
  Timer? _timer;

  Future<void> start() async {
    await _sampleOnce();
    _timer = Timer.periodic(interval, (_) {
      unawaited(_sampleOnce());
    });
  }

  Future<ResourceUsageSummary> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sampleOnce();

    if (_samples.isEmpty) {
      return const ResourceUsageSummary(
        averageCpuPercent: 0,
        peakCpuPercent: 0,
        averageMemoryMb: 0,
        peakMemoryMb: 0,
      );
    }

    var totalCpu = 0.0;
    var peakCpu = 0.0;
    var totalMemoryMb = 0.0;
    var peakMemoryMb = 0.0;

    for (final sample in _samples) {
      totalCpu += sample.cpuPercent;
      if (sample.cpuPercent > peakCpu) {
        peakCpu = sample.cpuPercent;
      }

      final memoryMb = sample.rssKb / 1024;
      totalMemoryMb += memoryMb;
      if (memoryMb > peakMemoryMb) {
        peakMemoryMb = memoryMb;
      }
    }

    return ResourceUsageSummary(
      averageCpuPercent: totalCpu / _samples.length,
      peakCpuPercent: peakCpu,
      averageMemoryMb: totalMemoryMb / _samples.length,
      peakMemoryMb: peakMemoryMb,
    );
  }

  Future<void> _sampleOnce() async {
    try {
      final result = await Process.run('ps', [
        '-o',
        '%cpu=',
        '-o',
        'rss=',
        '-p',
        '$pid',
      ]);

      if (result.exitCode != 0) {
        return;
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return;
      }

      final values = output.split(RegExp(r'\s+'));
      if (values.length < 2) {
        return;
      }

      final cpuPercent = double.tryParse(values[0]);
      final rssKb = double.tryParse(values[1]);
      if (cpuPercent == null || rssKb == null) {
        return;
      }

      _samples.add(_ResourceSample(cpuPercent: cpuPercent, rssKb: rssKb));
    } on ProcessException {
      // Ignore late samples during shutdown.
    }
  }
}

final class _ResourceSample {
  const _ResourceSample({required this.cpuPercent, required this.rssKb});

  final double cpuPercent;
  final double rssKb;
}
