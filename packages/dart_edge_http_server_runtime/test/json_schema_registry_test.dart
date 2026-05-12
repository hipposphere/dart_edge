import 'dart:convert';

import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_http_server_runtime/src/runtime/compiled_route_table.dart';
import 'package:test/test.dart';

void main() {
  test('stores installed schema registries on the app', () {
    const registry = JsonSchemaRegistry(
      schemas: <JsonSchema>[
        JsonSchema.object(
          id: 'UsersInsert',
          description: 'Insert payload for users.',
        ),
      ],
    );

    final app = DartEdge<void>(services: () {});
    app.installSchemaRegistry(registry);

    expect(app.schemaRegistry, same(registry));
    expect(
      app.schemaRegistry?.schemaFor('UsersInsert')?.description,
      'Insert payload for users.',
    );
    expect(app.schemaRegistry?.schemaFor('UsersInsert')?.toJson(), {
      r'$id': 'UsersInsert',
      'type': 'object',
      'description': 'Insert payload for users.',
    });
  });

  test('uses immutable OpenAPI document metadata from the constructor', () {
    final servers = [const OpenApiServer(url: 'https://api.example.test')];
    final app = DartEdge<void>(
      services: () {},
      openApiDocument: OpenApiDocument(
        title: 'Example API',
        version: '2026.04.26',
        description: 'Immutable API metadata.',
        servers: servers,
      ),
    );
    servers.add(const OpenApiServer(url: 'https://mutated.example.test'));

    final document = app.buildOpenApiDocumentJson();
    expect(document['info'], {
      'title': 'Example API',
      'version': '2026.04.26',
      'description': 'Immutable API metadata.',
    });
    expect(document['servers'], [
      {'url': 'https://api.example.test'},
    ]);
    expect(
      () => app.openApiDocument.servers.add(
        const OpenApiServer(url: 'https://blocked.example.test'),
      ),
      throwsUnsupportedError,
    );
  });

  test('includes installed schemas in the native manifest', () {
    const registry = JsonSchemaRegistry(
      schemas: <JsonSchema>[
        JsonSchema.object(
          id: 'UsersInsert',
          properties: <String, JsonSchema>{'email': JsonSchema.string()},
        ),
      ],
    );

    final app = DartEdge<void>(services: () {});
    app.routePost('/users', _SchemaRoute());

    final compiledRoutes = CompiledRouteTable.fromRegistrations(
      app.routeRegistry.registrations,
    );
    final manifest =
        jsonDecode(compiledRoutes.nativeManifestJson(schemaRegistry: registry))
            as Map<String, Object?>;

    expect(
      manifest['schemas'],
      containsPair('UsersInsert', {
        r'$id': 'UsersInsert',
        'type': 'object',
        'properties': {
          'email': {'type': 'string'},
        },
      }),
    );
  });

  test('includes component refs without duplicating the schema graph', () {
    const registry = JsonSchemaRegistry(
      schemas: <JsonSchema>[
        JsonSchema.array(
          id: 'ListSort',
          items: JsonSchema.componentRef('ListSortItem'),
        ),
        JsonSchema.object(
          id: 'ListSortItem',
          properties: <String, JsonSchema>{'field': JsonSchema.string()},
          required: <String>['field'],
          additionalProperties: false,
        ),
      ],
    );

    final app = DartEdge<void>(services: () {});
    app.routePost('/users', _SchemaRoute());

    final compiledRoutes = CompiledRouteTable.fromRegistrations(
      app.routeRegistry.registrations,
    );
    final manifest =
        jsonDecode(compiledRoutes.nativeManifestJson(schemaRegistry: registry))
            as Map<String, Object?>;
    final schemas = manifest['schemas']! as Map<String, Object?>;

    expect(schemas['ListSort'], {
      r'$id': 'ListSort',
      'type': 'array',
      'items': {r'$ref': '#/components/schemas/ListSortItem'},
    });
    expect(schemas['ListSortItem'], {
      r'$id': 'ListSortItem',
      'type': 'object',
      'properties': {
        'field': {'type': 'string'},
      },
      'required': ['field'],
      'additionalProperties': false,
    });
  });

  test('does not treat inline route schema ids as native manifest refs', () {
    final app = DartEdge<void>(services: () {});
    app.get(
      '/users/<id>',
      options: RouteOptions(
        params: const JsonSchema.object(
          id: 'UserPath',
          properties: <String, JsonSchema>{'id': JsonSchema.string()},
        ),
        query: const JsonSchema.object(
          id: 'UserQuery',
          properties: <String, JsonSchema>{'search': JsonSchema.string()},
        ),
      ),
      handler: (_) => const {'ok': true},
    );

    final compiledRoutes = CompiledRouteTable.fromRegistrations(
      app.routeRegistry.registrations,
    );
    final manifest =
        jsonDecode(compiledRoutes.nativeManifestJson()) as Map<String, Object?>;
    final routes = manifest['routes']! as List<Object?>;
    final route = routes.single as Map<String, Object?>;

    expect(route['paramsSchemaId'], isNull);
    expect(route['querySchemaId'], isNull);
  });

  test('includes explicit route schema refs in the native manifest', () {
    final app = DartEdge<void>(services: () {});
    app.get(
      '/users/<id>',
      options: const RouteOptions(
        params: JsonSchema.ref('UserPath'),
        query: JsonSchema.ref('UserQuery'),
      ),
      handler: (_) => const {'ok': true},
    );

    final compiledRoutes = CompiledRouteTable.fromRegistrations(
      app.routeRegistry.registrations,
    );
    final manifest =
        jsonDecode(compiledRoutes.nativeManifestJson()) as Map<String, Object?>;
    final routes = manifest['routes']! as List<Object?>;
    final route = routes.single as Map<String, Object?>;

    expect(route['paramsSchemaId'], 'UserPath');
    expect(route['querySchemaId'], 'UserQuery');
  });

  test('includes websocket params schema refs in the native manifest', () {
    final app = DartEdge<void>(services: () {});
    app.websocket(
      '/calls/<id>/live',
      options: const WebSocketOptions(
        operationId: 'connectLiveCall',
        params: JsonSchema.ref('IdParams'),
        query: JsonSchema.ref('LiveCallQuery'),
        queryDecoder: _decodeLiveCallQuery,
      ),
      onConnect: (_) async {},
    );

    final compiledRoutes = CompiledRouteTable.fromRegistrations(
      app.routeRegistry.registrations,
    );
    final manifest =
        jsonDecode(compiledRoutes.nativeManifestJson()) as Map<String, Object?>;
    final routes = manifest['routes']! as List<Object?>;
    final route = routes.single as Map<String, Object?>;
    final compiledRoute = compiledRoutes.webSocketRoutes.single;

    expect(route['kind'], 'webSocket');
    expect(route['paramsSchemaId'], 'IdParams');
    expect(route['querySchemaId'], 'LiveCallQuery');
    expect(compiledRoute.options.queryDecoder, same(_decodeLiveCallQuery));
  });
}

Object? _decodeLiveCallQuery(Map<String, String> values) => values;

final class _SchemaRoute
    extends HttpRouteDefinition<void, Map<String, Object?>> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'createUser',
    body: RequestBody.json(schema: const JsonSchema.ref('UsersInsert')),
    success: ResponseSpec.json(),
  );

  @override
  Map<String, Object?> handle(RequestContext<void> ctx) => const {'ok': true};
}
