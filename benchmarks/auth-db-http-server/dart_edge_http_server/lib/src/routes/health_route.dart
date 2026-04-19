import 'package:dart_edge_http_server/dart_edge_http_server.dart';

import '../services.dart';

final class HealthRoute extends JsonRouteDefinition<Services, String> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/healthz',
    options: RouteOptions(operationId: 'healthz', success: ResponseSpec.text()),
  );

  @override
  String handle(RequestContext<Services> ctx) => 'ok';
}
