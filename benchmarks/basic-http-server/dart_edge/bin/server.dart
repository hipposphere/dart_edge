import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_benchmark_shared/dart_edge_benchmark_shared.dart';

Future<void> main(List<String> args) async {
  final port = parseBenchmarkPort(args);
  final app = DartEdge<BenchmarkServices>(services: BenchmarkServices.new);

  app.register(PlaintextRoute());
  app.register(JsonRoute());
  app.register(UserRoute());
  app.register(EchoRoute());

  await app.listen(port: port);
}

final class BenchmarkServices {
  const BenchmarkServices();
}

final class PlaintextRoute
    extends JsonRouteDefinition<BenchmarkServices, String> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/plaintext',
    operationId: 'plaintext',
    responses: ResponseSet(success: ResponseSpec.text()),
  );

  @override
  String handle(RequestContext<BenchmarkServices> ctx) =>
      benchmarkPlaintextBody;
}

final class JsonRoute
    extends JsonRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/json',
    operationId: 'json',
    responses: ResponseSet(success: ResponseSpec.json<Object?>()),
  );

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    return {'message': 'Hello, World!'};
  }
}

final class UserRoute
    extends JsonRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/users/<id>',
    operationId: 'userById',
    responses: ResponseSet(success: ResponseSpec.json<Object?>()),
  );

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    final params = ctx.input.params<Map<String, String>>();
    return {'id': params['id'], 'name': 'Benchmark User'};
  }
}

final class EchoRoute
    extends JsonRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.post,
    path: '/echo',
    operationId: 'echo',
    body: RequestBody.jsonValue(),
    responses: ResponseSet(success: ResponseSpec.json<Object?>()),
  );

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    return ctx.input.body<Map<String, Object?>>();
  }
}
