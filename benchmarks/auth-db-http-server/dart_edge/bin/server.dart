import 'dart:io';

import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

Future<void> main(List<String> args) async {
  final port = parseBenchmarkPort(args);
  final database = await _openBenchmarkDatabase();
  final auth = DartEdgeAuth(
    DartEdgeAuthConfig(
      secret: benchmarkAuthSecret,
      baseUrl: benchmarkOriginForPort(port),
      basePath: benchmarkAuthPath,
      database: DartEdgeAuthDatabase.fromDatabase(database),
    ),
  );

  await _seedAuthUsers(auth);

  final app = DartEdge<BenchmarkServices>(
    services: () => BenchmarkServices(auth: auth, database: database),
  );

  auth.mount(app);
  app.register(HealthRoute());
  app.register(RawBenchmarkRoute());
  app.register(DatabaseBenchmarkRoute());

  await app.listen(port: port);
}

Future<SqliteDatabase> _openBenchmarkDatabase() async {
  final directory = Directory('var').absolute;
  await directory.create(recursive: true);
  final file = File('${directory.path}/benchmark.sqlite');
  if (await file.exists()) {
    await file.delete();
  }
  await file.create();

  final database = SqliteDatabase.open(file.path);
  await database.execute(
    sql('''
    CREATE TABLE benchmark_values (
      email TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    '''),
  );
  await database.execute(
    SqlStatement.positional(
      'INSERT INTO benchmark_values (email, value) VALUES (?, ?)',
      [benchmarkUserEmail, benchmarkDatabaseValue],
    ),
  );
  for (var index = 0; index < benchmarkFlowUserCount; index += 1) {
    await database.execute(
      SqlStatement.positional(
        'INSERT INTO benchmark_values (email, value) VALUES (?, ?)',
        [benchmarkFlowUserEmail(index), benchmarkDatabaseValue],
      ),
    );
  }
  return database;
}

Future<void> _seedAuthUsers(DartEdgeAuth auth) async {
  await _signUpWithRetry(
    auth.api.withForwardedFor(_seedForwardedFor(0)),
    email: benchmarkUserEmail,
    password: benchmarkUserPassword,
    name: benchmarkUserName,
  );

  for (var index = 0; index < benchmarkFlowUserCount; index += 1) {
    await _signUpWithRetry(
      auth.api.withForwardedFor(_seedForwardedFor(index + 1)),
      email: benchmarkFlowUserEmail(index),
      password: benchmarkUserPassword,
      name: benchmarkFlowUserName(index),
    );
  }
}

Future<void> _signUpWithRetry(
  DartEdgeAuthApi api, {
  required String email,
  required String password,
  required String name,
}) async {
  for (var attempt = 0; ; attempt += 1) {
    try {
      await api.signUpEmail(
        email: email,
        password: password,
        name: name,
      );
      return;
    } on DartEdgeAuthApiException catch (error) {
      if (error.status != HttpStatus.tooManyRequests || attempt >= 20) {
        rethrow;
      }

      await Future<void>.delayed(
        Duration(milliseconds: 100 * (attempt + 1)),
      );
    }
  }
}

String _seedForwardedFor(int userIndex) {
  final thirdOctet = (userIndex ~/ 254) % 255;
  final fourthOctet = (userIndex % 254) + 1;
  return '203.0.$thirdOctet.$fourthOctet';
}

final class BenchmarkServices {
  const BenchmarkServices({required this.auth, required this.database});

  final DartEdgeAuth auth;
  final SqliteDatabase database;
}

final class HealthRoute extends JsonRouteDefinition<BenchmarkServices, String> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: benchmarkHealthPath,
    operationId: 'healthz',
    responses: ResponseSet(success: ResponseSpec.text()),
  );

  @override
  String handle(RequestContext<BenchmarkServices> ctx) => benchmarkHealthBody;
}

final class RawBenchmarkRoute
    extends JsonRouteDefinition<BenchmarkServices, Object?> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: benchmarkRawPath,
    operationId: 'benchmarkRaw',
    responses: ResponseSet(
      success: ResponseSpec.json<Object?>(),
      errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
    ),
  );

  @override
  Future<Object?> handle(RequestContext<BenchmarkServices> ctx) async {
    final email = await _authenticate(ctx);
    if (email == null) {
      return RawResponse.json(
        status: HttpStatus.unauthorized,
        body: {'error': 'unauthorized'},
      );
    }

    return RawResponse.encoded(
      status: HttpStatus.ok,
      contentType: 'application/json; charset=utf-8',
      body: benchmarkRawResponseJson(email),
    );
  }
}

final class DatabaseBenchmarkRoute
    extends JsonRouteDefinition<BenchmarkServices, Object?> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: benchmarkDatabasePath,
    operationId: 'benchmarkDatabase',
    responses: ResponseSet(
      success: ResponseSpec.json<Object?>(),
      errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
    ),
  );

  @override
  Future<Object?> handle(RequestContext<BenchmarkServices> ctx) async {
    final email = await _authenticate(ctx);
    if (email == null) {
      return RawResponse.json(
        status: HttpStatus.unauthorized,
        body: {'error': 'unauthorized'},
      );
    }

    final result = await ctx.services.database.execute(
      SqlStatement.named(
        'SELECT value FROM benchmark_values WHERE email = :email',
        {'email': email},
      ),
    );
    if (result.single['value'] != benchmarkDatabaseValue) {
      return RawResponse.json(
        status: HttpStatus.internalServerError,
        body: {'error': 'benchmark_row_missing'},
      );
    }

    return RawResponse.encoded(
      status: HttpStatus.ok,
      contentType: 'application/json; charset=utf-8',
      body: benchmarkDatabaseResponseJson(email),
    );
  }
}

String? _authenticate(RequestContext<BenchmarkServices> ctx) {
  final headers = ctx.input.headers<Map<String, String>>();
  final authorization = headers['authorization'];
  final cookie = headers['cookie'];
  if ((authorization == null || !authorization.startsWith('Bearer ')) &&
      cookie == null) {
    return null;
  }

  final response = ctx.services.auth.api.callOperationSync(
    operationId: 'get_session',
    headers: headers,
  );
  final jsonBody = response.jsonBody;
  if (jsonBody is! Map<String, Object?>) {
    return null;
  }

  final user = jsonBody['user'];
  if (user is! Map<String, Object?>) {
    return null;
  }

  final email = user['email'];
  return email is String ? email : null;
}
