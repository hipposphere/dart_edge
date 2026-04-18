import 'dart:async';
import 'dart:io';

/// Aggregate CPU and memory statistics sampled from a server process.
final class ResourceUsageSummary {
  const ResourceUsageSummary({
    required this.averageCpuPercent,
    required this.peakCpuPercent,
    required this.averageMemoryMb,
    required this.peakMemoryMb,
    required this.sampleCount,
  });

  const ResourceUsageSummary.empty()
    : averageCpuPercent = 0,
      peakCpuPercent = 0,
      averageMemoryMb = 0,
      peakMemoryMb = 0,
      sampleCount = 0;

  final double averageCpuPercent;
  final double peakCpuPercent;
  final double averageMemoryMb;
  final double peakMemoryMb;
  final int sampleCount;
}

/// Periodically samples CPU and RSS for one process id.
final class ResourceSampler {
  ResourceSampler({
    required this.pid,
    this.interval = const Duration(milliseconds: 200),
  });

  final int pid;
  final Duration interval;

  final _samples = <_ResourceSample>[];
  Timer? _timer;
  var _sampling = false;

  Future<void> start() async {
    await _captureSample();
    _timer = Timer.periodic(interval, (_) {
      unawaited(_captureSample());
    });
  }

  Future<ResourceUsageSummary> stop() async {
    _timer?.cancel();
    _timer = null;
    await _captureSample();

    if (_samples.isEmpty) {
      return const ResourceUsageSummary.empty();
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
      sampleCount: _samples.length,
    );
  }

  Future<void> _captureSample() async {
    if (_sampling) {
      return;
    }
    _sampling = true;

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

      final line = (result.stdout as String).trim();
      if (line.isEmpty) {
        return;
      }

      final values = line.split(RegExp(r'\s+'));
      if (values.length < 2) {
        return;
      }

      final cpuPercent = double.tryParse(values[0]);
      final rssKb = int.tryParse(values[1]);
      if (cpuPercent == null || rssKb == null) {
        return;
      }

      _samples.add(_ResourceSample(cpuPercent: cpuPercent, rssKb: rssKb));
    } finally {
      _sampling = false;
    }
  }
}

final class _ResourceSample {
  const _ResourceSample({required this.cpuPercent, required this.rssKb});

  final double cpuPercent;
  final int rssKb;
}
