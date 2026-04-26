import 'package:dart_edge_http_server/dart_edge_http_server.dart';

import '../services.dart';

final class HealthRoute extends HttpRouteDefinition<Services, String> {
  @override
  RouteOptions get options =>
      RouteOptions(operationId: 'healthz', success: ResponseSpec.text());

  @override
  String handle(RequestContext<Services> ctx) => 'ok';
}
