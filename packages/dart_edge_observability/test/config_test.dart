import 'package:dart_edge_observability/dart_edge_observability.dart';
import 'package:test/test.dart';

void main() {
  test('reads shared environment config', () {
    final config = ObservabilityConfig.fromEnvironment(
      environment: const <String, String>{
        'SERVICE_NAME': 'example',
        'SERVICE_VERSION': '1.2.3',
        'ENVIRONMENT': 'test',
        'LOG_LEVEL': 'debug',
        'MONITORING_PORT': '9090',
        'REQUEST_LOGGING_ENABLED': 'false',
      },
    );

    expect(config.serviceName, 'example');
    expect(config.serviceVersion, '1.2.3');
    expect(config.environment, 'test');
    expect(config.logLevel, LogLevel.debug);
    expect(config.monitoringPort, 9090);
    expect(config.requestLoggingEnabled, isFalse);
  });
}
