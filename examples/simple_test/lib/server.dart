import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:simple_test/generated/app_schema.g.dart';
import 'package:simple_test/src/auth.dart';
import 'package:simple_test/src/database.dart';
import 'package:simple_test/src/routes/create_notes_route/route.dart';
import 'package:simple_test/src/routes/guarded_route.dart';
import 'package:simple_test/src/service.dart';

final class SimpleTestServerConfig {
  const SimpleTestServerConfig({
    this.authBaseUrl = 'http://localhost:3100',
    this.migrationsFolder = 'migrations',
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

  installSimpleTestRoutes(server, services: services);

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
  final migrator = await DartEdgeSqlMigrator.fromFolder(
    pool: database,
    folder: folder,
  );
  await migrator.migrateToLatest();
}

void installSimpleTestRoutes(
  DartEdge<SimpleTestServices> server, {
  required SimpleTestServices services,
}) {
  server.installSchemaRegistry(
    JsonSchemaRegistry(
      schemas: [
        ...createNotesRouteSchemas.schemas,
        ...DartEdgeAuthSchema.schemas,
      ],
    ),
  );
  services.auth.mount(server);

  server.get(
    '/',
    handler: (context) async {
      return 'Welcome to the Simple Test API!';
    },
  );

  server.get(
    '/upload',
    handler: (ctx) async {
      final multipart = await ctx.req.multipart();
      final file = await multipart.files.first;
      file.body.nativeBytes;
      return RawResponse.text(status: HttpStatus.noContent);
    },
  );

  server.get(
    '/hello',
    handler: (context) async {
      return 'Hello, World!';
    },
  );

  server.routePost('/notes', CreateNotesRoute());

  server.routeGet(
    '/guarded',
    GuardedRoute(),
    guards: [DartEdgeAuthGuard<SimpleTestServices>(auth: services.auth)],
  );
}

Future<void> seedSimpleTestDatabase(PostgresPool database) async {
  final owner = await database.typed
      .insertInto(PeopleTable.table)
      .values(
        const PeopleInsert(name: 'Ada Lovelace', email: 'ada@example.com'),
      )
      .executeReturningFirstOrNull();

  final result = await database.typed
      .insertInto(NotesTable.table)
      .values(
        NotesInsert(
          title: 'First note',
          body: 'This is the body of the first note.',
          ownerId: owner!.id,
        ),
      )
      .executeReturningFirstOrNull();

  final results = await database.typed
      .from(NotesTable.table)
      .innerJoin(
        PeopleTable.table,
        on: NotesTable.ownerId.equalsColumn(PeopleTable.id),
      )
      .select([NotesTable.title, PeopleTable.id])
      .execute();
  print('Seeded note with ID: ${result?.id}');
  print('Seeded notes in database: $results');
}
