import 'dart:io';

import 'package:dart_edge/dart_edge.dart';
import 'package:test/test.dart';

void main() {
  test('builds inline handler routes with stable defaults', () async {
    final app = DartEdge<TestServices>(services: TestServices.new);
    final api = app.router('/api');

    app.get('/health', handler: (ctx) => const {'status': 'ok'});
    api.put(
      '/users/<id>',
      options: RouteOptions(
        body: RequestBody.jsonValue(),
        success: ResponseSpec.json<Object?>(status: HttpStatus.accepted),
      ),
      handler: (ctx) {
        final params = ctx.input.params<Map<String, String>>();
        final body = ctx.input.body<Map<String, Object?>>();
        return {'id': params['id'], 'body': body};
      },
    );
    api.delete(
      '/users/<id>',
      options: RouteOptions(success: ResponseSpec.text()),
      handler: (ctx) {
        final params = ctx.input.params<Map<String, String>>();
        return 'deleted:${params['id']}';
      },
    );

    final healthRegistration = app.routeRegistry.registrations[0];
    final updateRegistration = app.routeRegistry.registrations[1];
    final deleteRegistration = app.routeRegistry.registrations[2];

    final healthRoute =
        healthRegistration.route as JsonRouteDefinition<TestServices, dynamic>;
    final updateRoute =
        updateRegistration.route as JsonRouteDefinition<TestServices, dynamic>;
    final deleteRoute =
        deleteRegistration.route as JsonRouteDefinition<TestServices, dynamic>;

    final healthContract = healthRoute.contract as RouteContract;
    final updateContract = updateRoute.contract as RouteContract;
    final deleteContract = deleteRoute.contract as RouteContract;

    expect(healthRegistration.prefix, '');
    expect(updateRegistration.prefix, '/api');
    expect(deleteRegistration.prefix, '/api');

    expect(healthContract.method, HttpMethod.get);
    expect(healthContract.operationId, 'getHealth');
    expect(
      healthContract.responses.success.contentType,
      'application/json; charset=utf-8',
    );

    expect(updateContract.method, HttpMethod.put);
    expect(updateContract.operationId, 'putApiUsersById');
    expect(updateContract.body?.contentType, 'application/json; charset=utf-8');
    expect(updateContract.responses.success.status, HttpStatus.accepted);

    expect(deleteContract.method, HttpMethod.delete);
    expect(deleteContract.operationId, 'deleteApiUsersById');
    expect(
      deleteContract.responses.success.contentType,
      'text/plain; charset=utf-8',
    );

    expect(
      healthRoute.handle(
        RequestContext<TestServices>(services: const TestServices()),
      ),
      {'status': 'ok'},
    );
    expect(
      await updateRoute.handle(
        RequestContext<TestServices>(
          services: const TestServices(),
          input: const RequestInput(
            paramsValue: {'id': '42'},
            bodyValue: {'name': 'Ada'},
          ),
        ),
      ),
      {
        'id': '42',
        'body': {'name': 'Ada'},
      },
    );
    expect(
      deleteRoute.handle(
        RequestContext<TestServices>(
          services: const TestServices(),
          input: const RequestInput(paramsValue: {'id': '42'}),
        ),
      ),
      'deleted:42',
    );

    expect(
      healthContract.toString(),
      'RouteContract(GET /health, operationId: getHealth, success: 200 application/json; charset=utf-8)',
    );
    expect(
      healthRoute.toString(),
      'HandlerJsonRouteDefinition<TestServices, Map<String, String>>(GET /health, operationId: getHealth)',
    );
    expect(
      updateRegistration.toString(),
      contains(
        'RouteRegistration(PUT /api/users/<id>, operationId: putApiUsersById, ',
      ),
    );
    expect(
      updateRegistration.toString(),
      contains(
        'route: HandlerJsonRouteDefinition<TestServices, Map<String, Object?>>'
        '(PUT /users/<id>, operationId: putApiUsersById)',
      ),
    );
  });

  test('builds inline handlers for every HTTP verb helper', () {
    final app = DartEdge<void>(services: () {});

    app.get('/get', handler: (_) => const {'method': 'get'});
    app.post('/post', handler: (_) => const {'method': 'post'});
    app.put('/put', handler: (_) => const {'method': 'put'});
    app.patch('/patch', handler: (_) => const {'method': 'patch'});
    app.delete('/delete', handler: (_) => const {'method': 'delete'});
    app.head('/head', handler: (_) => const {'method': 'head'});
    app.options('/options', handler: (_) => const {'method': 'options'});

    final methods = [
      for (final registration in app.routeRegistry.registrations)
        ((registration.route as JsonRouteDefinition<void, dynamic>).contract
                as RouteContract)
            .method,
    ];

    expect(methods, [
      HttpMethod.get,
      HttpMethod.post,
      HttpMethod.put,
      HttpMethod.patch,
      HttpMethod.delete,
      HttpMethod.head,
      HttpMethod.options,
    ]);
  });
}

final class TestServices {
  const TestServices();
}
