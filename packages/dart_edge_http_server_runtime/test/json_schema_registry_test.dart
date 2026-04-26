import 'dart:convert';

import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_http_server_runtime/src/runtime/compiled_route_table.dart';
import 'package:test/test.dart';

void main() {
  test('stores installed schema registries on the app', () {
    const registry = JsonSchemaRegistry(
      schemas: <JsonSchema>[
        JsonSchema.object(
          ref: JsonSchemaRef<Object?>('UsersInsert'),
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
          ref: JsonSchemaRef<Object?>('UsersInsert'),
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
}

final class _SchemaRoute
    extends HttpRouteDefinition<void, Map<String, Object?>> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'createUser',
    body: RequestBody.json<Object?>(ref: JsonSchemaRef<Object?>('UsersInsert')),
    success: ResponseSpec.json<Object?>(),
  );

  @override
  Map<String, Object?> handle(RequestContext<void> ctx) => const {'ok': true};
}
