import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  test('route and websocket options default to all generated surfaces', () {
    final routeOptions = RouteOptions(
      operationId: 'getHealth',
      success: ResponseSpec.text(),
    ).normalized();
    final webSocketOptions = const WebSocketOptions(
      operationId: 'connectEvents',
    ).normalized();

    expect(routeOptions.exposure, RouteExposure.all);
    expect(webSocketOptions.exposure, RouteExposure.all);
  });

  test('router exposure is inherited restrictively', () {
    final app = Router<void>(exposure: RouteExposure.clientOnly);
    final internal = app.router(
      '/internal',
      exposure: RouteExposure.openApiOnly,
    );
    internal.get('/health', handler: (_) => const {'ok': true});

    final registration = app.routeRegistry.registrations.single;
    expect(registration.prefix, '/internal');
    expect(registration.exposure, RouteExposure.none);
  });

  test('mounted router exposure is inherited restrictively', () {
    final app = Router<void>(exposure: RouteExposure.openApiOnly);
    final feature = Router<void>(exposure: RouteExposure.clientOnly);
    feature.get('/health', handler: (_) => const {'ok': true});

    app.mountRouter('/feature', feature);

    final registration = app.routeRegistry.registrations.single;
    expect(registration.prefix, '/feature');
    expect(registration.exposure, RouteExposure.none);
  });
}
