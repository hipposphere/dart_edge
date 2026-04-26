import 'package:dart_edge_http_server/dart_edge_http_server.dart';

Future<void> main(List<String> args) async {
  final port = _parsePort(args);
  final app = DartEdge<BenchmarkServices>(services: BenchmarkServices.new);

  app.routeGet('/plaintext', PlaintextRoute());
  app.routeGet('/json', JsonRoute());
  app.routeGet('/users/<id>', UserRoute());
  app.routePost('/echo', EchoRoute());

  await app.listen(port: port);
}

final class BenchmarkServices {
  const BenchmarkServices();
}

final class PlaintextRoute
    extends HttpRouteDefinition<BenchmarkServices, String> {
  @override
  RouteOptions get options =>
      RouteOptions(operationId: 'plaintext', success: ResponseSpec.text());

  @override
  String handle(RequestContext<BenchmarkServices> ctx) => 'Hello, World!';
}

final class JsonRoute
    extends HttpRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteOptions get options =>
      RouteOptions(operationId: 'json', success: ResponseSpec.json<Object?>());

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    return {'message': 'Hello, World!'};
  }
}

final class UserRoute
    extends HttpRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'userById',
    success: ResponseSpec.json<Object?>(),
  );

  @override
  Map<String, Object?> handle(RequestContext<BenchmarkServices> ctx) {
    final params = ctx.req.params<Map<String, String>>();
    return {'id': params['id']!, 'name': 'Benchmark User'};
  }
}

final class EchoRoute
    extends HttpRouteDefinition<BenchmarkServices, Map<String, Object?>> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'echo',
    body: RequestBody.jsonValue(),
    success: ResponseSpec.json<Object?>(),
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
