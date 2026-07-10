# simple_test_server

Small end-to-end Dart Edge app with HTTP routes, auth, SQL migrations, and
generated SQL descriptors.

## Package shape

`bin/main.dart` only starts the app. The server package is built in layers:

- `lib/server.dart` wires services, migrations, routes, auth, and OpenAPI.
- `lib/src/service.dart` defines the request service boundary.
- `lib/src/routes/` contains route modules with `route.dart`, `schema.dart`,
  and generated `route.g.dart`.
- `../simple_test_db_models/lib/generated/` contains checked-in SQL descriptors
  generated from `../simple_test_db_migrator/migrations/` and shared with
  clients.

## Regenerate SQL descriptors

The SQL example introspects the migrated PGlite database and writes the
generated Dart library directly:

```shell
cd ../simple_test_db_migrator
dart run tool/generate_db_schema.dart
```

The output is checked in:

```text
../simple_test_db_models/lib/generated/app_schema.g.dart
../simple_test_db_models/lib/generated/schemas/public/schema.g.dart
../simple_test_db_models/lib/generated/schemas/public/tables/*.g.dart
```

Application code imports the generated `.g.dart` file directly.

For apps that already have a migrated PostgreSQL database, the package CLI can
do the same introspection step:

```shell
dart run dart_edge_sql_codegen:schema --postgres postgres://localhost/app --out lib/generated --class AppSchema
```

## Regenerate HTTP client

The generated API client is checked in under `../simple_test_client`.

```shell
dart run tool/generate_client.dart
```

The generator reads the registered server routes and writes a client package
that depends on `simple_test_db_models`, not on `simple_test_server`. Use it
with the `package:http` transport and optional auth interceptors:

```dart
import 'package:dart_edge_http_client/dart_edge_http_client.dart';
import 'package:simple_test_client/simple_test_client.dart';

final client = SimpleTestClient(
  baseUri: Uri.parse('http://localhost:3100'),
  transport: DartEdgeHttpClientTransport(
    interceptors: [
      DartEdgeBearerTokenInterceptor(() async => token),
    ],
  ),
);
```
