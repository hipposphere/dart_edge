import 'dart:io';

/// In-memory Prometheus-compatible metric registry.
final class MetricsRegistry {
  MetricsRegistry({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _startedAt = (clock ?? DateTime.now)();

  final DateTime Function() _clock;
  final DateTime _startedAt;
  final List<Metric> _metrics = <Metric>[];

  Counter counter(
    String name, {
    String help = '',
    List<String> labelNames = const <String>[],
  }) {
    final metric = Counter(name, help: help, labelNames: labelNames);
    _metrics.add(metric);
    return metric;
  }

  Gauge gauge(
    String name, {
    String help = '',
    List<String> labelNames = const <String>[],
  }) {
    final metric = Gauge(name, help: help, labelNames: labelNames);
    _metrics.add(metric);
    return metric;
  }

  Histogram histogram(
    String name, {
    String help = '',
    List<String> labelNames = const <String>[],
    List<double> buckets = const <double>[
      0.005,
      0.01,
      0.025,
      0.05,
      0.1,
      0.25,
      0.5,
      1,
      2.5,
      5,
      10,
    ],
  }) {
    final metric = Histogram(
      name,
      help: help,
      labelNames: labelNames,
      buckets: buckets,
    );
    _metrics.add(metric);
    return metric;
  }

  String scrape() {
    final runtime = _runtimeMetrics();
    return [
      for (final metric in _metrics) metric.scrape(),
      runtime,
    ].where((part) => part.isNotEmpty).join('\n');
  }

  String _runtimeMetrics() {
    final info = ProcessInfo.currentRss;
    final uptimeSeconds = _clock().difference(_startedAt).inMilliseconds / 1000;
    return '''
# HELP process_resident_memory_bytes Resident memory size in bytes.
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes $info
# HELP process_uptime_seconds Process uptime in seconds.
# TYPE process_uptime_seconds gauge
process_uptime_seconds $uptimeSeconds
''';
  }
}

abstract class Metric {
  Metric(this.name, {required this.help, required this.labelNames});

  final String name;
  final String help;
  final List<String> labelNames;

  String scrape();

  String labels(
    Map<String, String> values, {
    Map<String, String> extra = const {},
  }) {
    final all = <String, String>{};
    for (final label in labelNames) {
      if (values[label] case final value?) {
        all[label] = value;
      }
    }
    all.addAll(extra);
    if (all.isEmpty) {
      return '';
    }
    final encoded = all.entries
        .map((entry) => '${entry.key}="${_escapeLabel(entry.value)}"')
        .join(',');
    return '{$encoded}';
  }
}

final class Counter extends Metric {
  Counter(super.name, {required super.help, required super.labelNames});

  final Map<String, double> _values = <String, double>{};
  final Map<String, Map<String, String>> _labels =
      <String, Map<String, String>>{};

  void inc({double value = 1, Map<String, String> labels = const {}}) {
    final key = _labelKey(labels);
    _labels[key] = labels;
    _values[key] = (_values[key] ?? 0) + value;
  }

  @override
  String scrape() {
    final buffer = StringBuffer()
      ..writeln('# HELP $name $help')
      ..writeln('# TYPE $name counter');
    for (final entry in _values.entries) {
      buffer.writeln(
        '$name${labels(_labels[entry.key] ?? const {})} ${entry.value}',
      );
    }
    return buffer.toString();
  }
}

final class Gauge extends Metric {
  Gauge(super.name, {required super.help, required super.labelNames});

  final Map<String, double> _values = <String, double>{};
  final Map<String, Map<String, String>> _labels =
      <String, Map<String, String>>{};

  void set(double value, {Map<String, String> labels = const {}}) {
    final key = _labelKey(labels);
    _labels[key] = labels;
    _values[key] = value;
  }

  void inc({double value = 1, Map<String, String> labels = const {}}) {
    final key = _labelKey(labels);
    _labels[key] = labels;
    _values[key] = (_values[key] ?? 0) + value;
  }

  void dec({double value = 1, Map<String, String> labels = const {}}) {
    inc(value: -value, labels: labels);
  }

  @override
  String scrape() {
    final buffer = StringBuffer()
      ..writeln('# HELP $name $help')
      ..writeln('# TYPE $name gauge');
    for (final entry in _values.entries) {
      buffer.writeln(
        '$name${labels(_labels[entry.key] ?? const {})} ${entry.value}',
      );
    }
    return buffer.toString();
  }
}

final class Histogram extends Metric {
  Histogram(
    super.name, {
    required super.help,
    required super.labelNames,
    required List<double> buckets,
  }) : buckets = List<double>.unmodifiable([...buckets]..sort());

  final List<double> buckets;
  final Map<String, _HistogramValue> _values = <String, _HistogramValue>{};
  final Map<String, Map<String, String>> _labels =
      <String, Map<String, String>>{};

  void observe(double value, {Map<String, String> labels = const {}}) {
    final key = _labelKey(labels);
    _labels[key] = labels;
    final histogram = _values.putIfAbsent(
      key,
      () => _HistogramValue(bucketUpperBounds: buckets),
    );
    histogram.observe(value);
  }

  @override
  String scrape() {
    final buffer = StringBuffer()
      ..writeln('# HELP $name $help')
      ..writeln('# TYPE $name histogram');
    for (final entry in _values.entries) {
      final labelValues = _labels[entry.key] ?? const <String, String>{};
      final value = entry.value;
      for (final bucket in value.bucketCounts.entries) {
        buffer.writeln(
          '${name}_bucket${labels(labelValues, extra: {'le': _formatBucket(bucket.key)})} ${bucket.value}',
        );
      }
      buffer
        ..writeln(
          '${name}_bucket${labels(labelValues, extra: const {'le': '+Inf'})} ${value.count}',
        )
        ..writeln('${name}_sum${labels(labelValues)} ${value.sum}')
        ..writeln('${name}_count${labels(labelValues)} ${value.count}');
    }
    return buffer.toString();
  }
}

final class StandardHttpMetrics {
  StandardHttpMetrics(MetricsRegistry registry)
    : requestCounter = registry.counter(
        'http_server_requests_total',
        help: 'HTTP requests by method, normalized route, and status.',
        labelNames: const <String>['method', 'route', 'status'],
      ),
      errorCounter = registry.counter(
        'http_server_errors_total',
        help:
            'HTTP request errors by method, normalized route, and error name.',
        labelNames: const <String>['method', 'route', 'errorName'],
      ),
      latencyHistogram = registry.histogram(
        'http_server_request_duration_seconds',
        help: 'HTTP request latency in seconds.',
        labelNames: const <String>['method', 'route', 'status'],
      ),
      requestBodySize = registry.histogram(
        'http_server_request_body_bytes',
        help: 'HTTP request body size in bytes when available.',
        labelNames: const <String>['method', 'route'],
      ),
      responseBodySize = registry.histogram(
        'http_server_response_body_bytes',
        help: 'HTTP response body size in bytes when available.',
        labelNames: const <String>['method', 'route', 'status'],
      );

  final Counter requestCounter;
  final Counter errorCounter;
  final Histogram latencyHistogram;
  final Histogram requestBodySize;
  final Histogram responseBodySize;
}

final class _HistogramValue {
  _HistogramValue({required List<double> bucketUpperBounds})
    : bucketCounts = {for (final bucket in bucketUpperBounds) bucket: 0};

  final Map<double, int> bucketCounts;
  double sum = 0;
  int count = 0;

  void observe(double value) {
    sum += value;
    count += 1;
    for (final bucket in bucketCounts.keys) {
      if (value <= bucket) {
        bucketCounts[bucket] = bucketCounts[bucket]! + 1;
      }
    }
  }
}

String _labelKey(Map<String, String> labels) {
  final entries = labels.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return entries.map((entry) => '${entry.key}=${entry.value}').join('\n');
}

String _escapeLabel(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('"', r'\"');
}

String _formatBucket(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return '$value';
}
