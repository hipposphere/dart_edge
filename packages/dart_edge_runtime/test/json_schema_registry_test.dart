import 'dart:convert';

import 'package:dart_edge_runtime/dart_edge_runtime.dart';
import 'package:dart_edge_runtime/src/runtime/compiled_route_table.dart';
import 'package:test/test.dart';

void main() {
  test('stores installed schema registries on the app', () {
    const registry = JsonSchemaRegistry(
      definitions: <JsonSchemaDefinition>[
        JsonSchemaDefinition(
          ref: JsonSchemaRef<Object?>('UsersInsert'),
          schema: <String, Object?>{r'$id': 'UsersInsert', 'type': 'object'},
        ),
      ],
    );

    final app = DartEdge<void>(services: () {});
    app.installSchemaRegistry(registry);

    expect(app.schemaRegistry, same(registry));
    expect(app.schemaRegistry?.definitionFor('UsersInsert')?.schema, {
      r'$id': 'UsersInsert',
      'type': 'object',
    });
  });

  test('includes installed schemas in the native manifest', () {
    const registry = JsonSchemaRegistry(
      definitions: <JsonSchemaDefinition>[
        JsonSchemaDefinition(
          ref: JsonSchemaRef<Object?>('UsersInsert'),
          schema: <String, Object?>{
            r'$id': 'UsersInsert',
            'type': 'object',
            'properties': <String, Object?>{
              'email': <String, Object?>{'type': 'string'},
            },
          },
        ),
      ],
    );

    final app = DartEdge<void>(services: () {});
    app.register(_SchemaRoute());

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
    extends JsonRouteDefinition<void, Map<String, Object?>> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.post,
    path: '/users',
    operationId: 'createUser',
    body: RequestBody.json<Object?>(ref: JsonSchemaRef<Object?>('UsersInsert')),
    responses: ResponseSet(success: ResponseSpec.json<Object?>()),
  );

  @override
  Map<String, Object?> handle(RequestContext<void> ctx) => const {'ok': true};
}
