import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:simple_test/src/auth.dart';
import 'package:simple_test/src/database.dart';
import 'package:simple_test/src/routes/guarded_route.dart';
import 'package:http/http.dart' as http;

Future<DartEdge<void>> buildServer() async {
  final server = DartEdge<void>();

  final database = buildDatabase();

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

  server
      .router('', guards: [DartEdgeAuthGuard(auth: auth)])
      .register(GuardedRoute());

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
