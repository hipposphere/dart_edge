import 'package:dart_edge_observability/dart_edge_observability.dart';
import 'package:test/test.dart';

void main() {
  test('scrapes prometheus counters and histograms', () {
    final registry = MetricsRegistry();
    final counter = registry.counter(
      'example_total',
      help: 'Example counter.',
      labelNames: const ['route'],
    );
    final histogram = registry.histogram(
      'example_seconds',
      help: 'Example duration.',
      labelNames: const ['route'],
      buckets: const [0.1, 1],
    );

    counter.inc(labels: const {'route': '/api/items'});
    histogram.observe(0.2, labels: const {'route': '/api/items'});

    final output = registry.scrape();
    expect(output, contains('example_total{route="/api/items"} 1.0'));
    expect(
      output,
      contains('example_seconds_bucket{route="/api/items",le="0.1"} 0'),
    );
    expect(
      output,
      contains('example_seconds_bucket{route="/api/items",le="1"} 1'),
    );
    expect(output, contains('process_uptime_seconds'));
  });
}
