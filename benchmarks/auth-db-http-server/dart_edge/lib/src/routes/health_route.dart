import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import '../services.dart';

final class HealthRoute extends JsonRouteDefinition<Services, String> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: benchmarkHealthPath,
    operationId: 'healthz',
    responses: ResponseSet(success: ResponseSpec.text()),
  );

  @override
  String handle(RequestContext<Services> ctx) => benchmarkHealthBody;
}
