import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:json_schema/json_schema.dart';
import 'package:simple_test_db_migrator/simple_test_db_migrator.dart';
import 'package:simple_test_server/src/auth.dart';
import 'package:simple_test_server/src/database.dart';
import 'package:simple_test_server/src/routes/create_notes_route/route.dart';
import 'package:simple_test_server/src/routes/guarded_route.dart';
import 'package:simple_test_server/src/seed.dart';
import 'package:simple_test_server/src/service.dart';

final class SimpleTestServerConfig {
  const SimpleTestServerConfig({
    this.authBaseUrl = 'http://localhost:3100',
    this.migrationsFolder = simpleTestMigrationsFolder,
    this.seedDatabase = true,
    this.mountOpenApi = true,
  });

  final String authBaseUrl;
  final String migrationsFolder;
  final bool seedDatabase;
  final bool mountOpenApi;
}

Future<DartEdge<SimpleTestServices>> buildServer({
  SimpleTestServerConfig config = const SimpleTestServerConfig(),
}) async {
  final services = await buildSimpleTestServices(config);
  final server = DartEdge<SimpleTestServices>(
    services: () => services,
    openApiDocument: OpenApiDocument(
      title: 'Simple Test API',
      version: '1.0.0',
    ),
  );

  installSimpleTestRoutes(server, auth: services.auth);

  if (config.mountOpenApi) {
    OpenApiHelpers.mountJson(server, path: 'openapi.json');
    OpenApiHelpers.mountSwaggerUi(
      server,
      path: 'docs',
      specPath: 'openapi.json',
    );
  }

  return server;
}

Future<SimpleTestServices> buildSimpleTestServices(
  SimpleTestServerConfig config,
) async {
  final database = buildDatabase();
  final auth = buildAuth(database, baseUrl: config.authBaseUrl);

  await runMigrations(database, folder: config.migrationsFolder);

  if (config.seedDatabase) {
    await seedSimpleTestDatabase(database);
  }

  return SimpleTestServices(database: database, auth: auth);
}

Future<void> runMigrations(
  PostgresPool database, {
  required String folder,
}) async {
  await migrateSimpleTestDatabase(database, folder: folder);
}

void installSimpleTestRoutes(
  DartEdge<SimpleTestServices> server, {
  DartEdgeAuth? auth,
}) {
  server.installSchemaRegistry(
    JsonSchemaRegistry(
      schemas: [
        ...createNotesRouteSchemas.schemas,
        ...DartEdgeAuthSchema.schemas,
      ],
    ),
  );
  auth?.mount(server);

  server.get(
    '/',
    options: const RouteOptions(
      operationId: 'getRoot',
      success: ResponseSpec.text(),
    ),
    handler: (context) async {
      return 'Welcome to the Simple Test API!';
    },
  );

  server.get(
    '/upload',
    options: const RouteOptions(
      operationId: 'upload',
      success: ResponseSpec.text(status: HttpStatus.noContent),
    ),
    handler: (ctx) async {
      final multipart = await ctx.req.multipart();
      final file = multipart.files.first;
      file.body.nativeBytes;
      return RawResponse.text(status: HttpStatus.noContent);
    },
  );

  server.get(
    '/hello',
    options: const RouteOptions(
      operationId: 'getHello',
      success: ResponseSpec.text(),
    ),
    handler: (context) async {
      return 'Hello, World!';
    },
  );

  server.routePost('/notes', CreateNotesRoute());

  server.routeGet(
    '/guarded',
    GuardedRoute(),
    guards: [
      if (auth case final auth?)
        DartEdgeAuthGuard<SimpleTestServices>(auth: auth),
    ],
  );
}
