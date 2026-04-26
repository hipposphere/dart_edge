import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:http/http.dart' as http;
import 'package:simple_test/generated/app_schema.g.dart';
import 'package:simple_test/src/auth.dart';
import 'package:simple_test/src/database.dart';
import 'package:simple_test/src/routes/guarded_route.dart';

Future<DartEdge<void>> buildServer() async {
  final server = DartEdge<void>(
    openApiDocument: OpenApiDocument(
      title: 'Simple Test API',
      version: '1.0.0',
    ),
  );

  final database = buildDatabase();

  final migrator = await DartEdgeSqlMigrator.fromFolder(
    pool: database,
    folder: 'migrations',
  );
  await migrator.migrateToLatest();

  final owner = await database.builder
      .insertInto(PeopleTable.table)
      .values(
        const PeopleInsert(name: 'Ada Lovelace', email: 'ada@example.com'),
      )
      .executeReturningFirstTable();

  final result = await database.builder
      .insertInto(NotesTable.table)
      .values(
        NotesInsert(
          title: 'First note',
          body: 'This is the body of the first note.',
          ownerId: owner!.id!,
        ),
      )
      .executeReturningFirstTable();

  print('Inserted note with ID: ${result?.id}');

  final results = await database.builder
      .selectFrom(NotesTable.table)
      .innerJoin(
        PeopleTable.table,
        on: NotesTable.ownerId.equalsColumn(PeopleTable.id),
      )
      .select([NotesTable.title, PeopleTable.id])
      .execute();
  print('Notes in database: $results');

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
    },
  );

  server.get(
    '/hello',
    handler: (context) async {
      return 'Hello, World!';
    },
  );
  final auth = buildAuth(database);

  server.register(GuardedRoute(), guards: [DartEdgeAuthGuard(auth: auth)]);

  final email = 'test@dicto.org';
  final password = 'password';
  auth.api
      .signUpEmail(email: email, password: password, name: 'Max Mustermann')
      .then((response) async {
        print('User signed up: ${response.jsonBody}');

        final signedIn = await auth.api
            .signInEmail(email: email, password: password)
            .catchError((dynamic error) {
              print('Error signing up user: $error');
              throw error is Object
                  ? error
                  : StateError('Sign-in failed: $error');
            });

        final session = signedIn.jsonBody as Map<String, dynamic>;
        final token = session['token'] as String;

        final guardedResponse = await http.get(
          Uri.parse('http://0.0.0.0:3100/guarded'),
          headers: {'Authorization': 'Bearer $token'},
        );
        print('Response: ${guardedResponse.body}');
      });

  OpenApiHelpers.mountJson(server, path: 'openapi.json');

  OpenApiHelpers.mountSwaggerUi(server, path: 'docs', specPath: 'openapi.json');

  return server;
}
