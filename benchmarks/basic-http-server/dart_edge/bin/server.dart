import 'package:dart_edge/dart_edge.dart';

Future<void> main(List<String> args) async {
  final port = _parsePort(args);
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
    options: RouteOptions(
      operationId: 'plaintext',
      success: ResponseSpec.text(),
    ),
  );

  @override
  String handle(RequestContext<BenchmarkServices> ctx) => 'Hello, World!';
}

final class JsonRoute
    extends JsonRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/json',
    options: RouteOptions(
      operationId: 'json',
      success: ResponseSpec.json<Object?>(),
    ),
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
    options: RouteOptions(
      operationId: 'userById',
      success: ResponseSpec.json<Object?>(),
    ),
  );

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    final params = ctx.req.params<Map<String, String>>();
    return {'id': params['id']!, 'name': 'Benchmark User'};
  }
}

final class EchoRoute
    extends JsonRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.post,
    path: '/echo',
    options: RouteOptions(
      operationId: 'echo',
      body: RequestBody.jsonValue(),
      success: ResponseSpec.json<Object?>(),
    ),
  );

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    return ctx.req.body<Map<String, Object?>>();
  }
}

int _parsePort(List<String> args, {int defaultPort = 8080}) {
  for (final argument in args) {
    if (argument.startsWith('--port=')) {
      return int.parse(argument.substring('--port='.length));
    }
  }

  return defaultPort;
}
