import 'package:dart_edge/dart_edge.dart';
import 'package:simple_test/src/auth.dart';
import 'package:simple_test/src/database.dart';

Future<DartEdge<void>> buildServer() async {
  final server = DartEdge<void>();

  final database = buildDatabase();

  // await database.execute(
  //   .new('''
  //   CREATE TABLE IF NOT EXISTS users (
  //     id INTEGER PRIMARY KEY AUTOINCREMENT,
  //     email TEXT NOT NULL UNIQUE,
  //     password TEXT NOT NULL,
  //     name TEXT NOT NULL
  //   );
  // '''),
  // );

  // final result = await database.execute(
  //   .new('''
  //   INSERT INTO users (email, password, name)
  //   VALUES ('test@dicto.org', 'password', 'Max Mustermann')
  // '''),
  // );
  // print('Inserted user with ID: ${result.rows}');

  // await database
  //     .execute(
  //       .new('''
  //   SELECT * FROM users
  // '''),
  //     )
  //     .then((result) {
  //       print('Users in database: ${result.rows}');
  //     });

  server.openApiDocument
    ..title = 'Simple Test API'
    ..version = '1.0.0';

  server.get(
    '/',
    handler: (context) async {
      return 'Welcome to the Simple Test API!';
    },
  );

  server.get(
    '/hello',
    handler: (context) async {
      return 'Hello, World!';
    },
  );

  final auth = buildAuth(database);

  auth.api
      .signUpEmail(
        email: 'test@dicto.org',
        password: 'password',
        name: 'Max Mustermann',
      )
      .then((response) {
        print('User signed up: ${response.jsonBody}');
      })
      .catchError((dynamic error) {
        print('Error signing up user: $error');
      });

  OpenApiHelpers.mountJson(server, path: 'openapi.json');

  OpenApiHelpers.mountSwaggerUi(server, path: 'docs', specPath: 'openapi.json');

  return server;
}
