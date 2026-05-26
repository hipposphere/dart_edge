# dart_edge_auth

Better Auth integration for Dart Edge.

This package creates the Better Auth route set in native code and mounts those
routes into a `DartEdge` app. Use it when you want session, sign-in, sign-up,
and account-management endpoints without hand-writing each route.

## Quick Start

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';

Future<void> main() async {
  final app = DartEdge<NoServices>(services: NoServices.new);
  final auth = DartEdgeAuth(
    const DartEdgeAuthConfig(
    workerPoolSize: 4,
      secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
      baseUrl: 'http://localhost:8080',
    ),
  );

  auth.mount(app);
  await app.listen(port: 8080);
}

final class NoServices {
  const NoServices();
}
```

## Main Types

- `DartEdgeAuth` builds and mounts the auth routes
- `DartEdgeAuthConfig` controls the Better Auth instance that backs those
  routes

Call `dispose()` when the auth instance is no longer needed so its native
resources are released.

See [example/basic_auth_server.dart](example/basic_auth_server.dart) for the
same setup in the repository.

## Direct Backend API

You can also call Better Auth routes directly from backend code without going
through your mounted HTTP server:

```dart
final signup = await auth.api.signUpEmail(
  email: 'ada@example.com',
  password: 'password123',
  name: 'Ada Lovelace',
);

final token = signup.token!;
final session = await auth.api.withBearerToken(token).getSession();
final user = session.user;
```

Typed auth table row models are generated from the Better Auth SQL schema and
exported by this package:

```dart
final users = await database.typed
    .from(DartEdgeAuthSchema.users)
    .selectAll()
    .where(DartEdgeAuthUsersTable.email.equals('ada@example.com'))
    .execute();

final typedUser = users.single; // DartEdgeAuthUserRow
```

Regenerate the model files after SQL schema changes:

```sh
cd packages/dart_edge_auth && dart tool/generate_auth_models.dart
dart format packages/dart_edge_auth/lib/src/generated packages/dart_edge_auth/tool/generate_auth_models.dart
```

When you want Better Auth's admin endpoints, enable the upstream admin plugin in
config and use `auth.api.admin`:

```dart
final auth = DartEdgeAuth(
  const DartEdgeAuthConfig(
    workerPoolSize: 4,
    secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
    baseUrl: 'http://localhost:8080',
    admin: DartEdgeAuthAdminConfig(),
  ),
);

final admin = auth.api.withBearerToken(adminToken).admin;
final created = await admin.createUser(
  email: 'grace@example.com',
  password: 'password123',
  name: 'Grace Hopper',
);
```

If `auth.api.admin.*` throws a `StateError` that requires the `admin` Better
Auth plugin, your `DartEdgeAuthConfig` does not have
`admin: DartEdgeAuthAdminConfig()` enabled. The error also includes the
operation ids registered by the native auth route table.

For backend-only code that is already trusted by your application, use the
separate trusted admin API. This does not use request/session authorization and
must not be exposed directly from public routes:

```dart
final created = await auth.trustedAdmin.createUser(
  email: 'grace@example.com',
  password: 'password123',
  name: 'Grace Hopper',
  role: 'member',
);

final users = await auth.trustedAdmin.listUsers(limit: 50);
```

## Shared Native Databases

When your app already uses `dart_edge_sql`, share that same live native database
with Better Auth:

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';

final database = PostgresPool.withUrl(
  'postgresql://postgres:postgres@localhost:5432/dart_edge_http_server',
);

final auth = DartEdgeAuth(
  DartEdgeAuthConfig(
    workerPoolSize: 4,
    secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
    baseUrl: 'http://localhost:8080',
    database: DartEdgeAuthDatabase.fromDatabase(
      database,
      manageMigrations: true,
    ),
  ),
);
```

The same shared-handle path works for SQLite, including `SqliteDatabase.inMemory()`:

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';

final database = SqliteDatabase.open('var/auth.db');

final auth = DartEdgeAuth(
  DartEdgeAuthConfig(
    workerPoolSize: 4,
    secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
    baseUrl: 'http://localhost:8080',
    database: DartEdgeAuthDatabase.fromDatabase(
      database,
      manageMigrations: true,
    ),
  ),
);
```

This path shares the live native `dart_edge_sql` database handle instead of
reopening the database inside `dart_edge_auth`.

If you want `dart_edge_auth` to own a separate backend, keep using the explicit
`DartEdgeAuthDatabase.postgres(...)` or `DartEdgeAuthDatabase.sqlite(...)`
constructors.

Auth-side migration management is disabled by default for shared and dedicated
SQLite database configs. Opt in only when you want `dart_edge_auth` to create
or update the Better Auth tables:

```dart
final auth = DartEdgeAuth(
  DartEdgeAuthConfig(
    workerPoolSize: 4,
    secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
    baseUrl: 'http://localhost:8080',
    database: DartEdgeAuthDatabase.fromDatabase(
      database,
      manageMigrations: true,
    ),
  ),
);
```

Shared PostgreSQL databases can place Better Auth tables in a dedicated schema:

```dart
final auth = DartEdgeAuth(
  DartEdgeAuthConfig(
    workerPoolSize: 4,
    secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
    baseUrl: 'http://localhost:8080',
    database: DartEdgeAuthDatabase.fromDatabase(
      database,
      schema: 'auth',
    ),
  ),
);
```

The migration option is also available on dedicated SQLite configs:

```dart
final auth = DartEdgeAuth(
  const DartEdgeAuthConfig(
    workerPoolSize: 4,
    secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
    baseUrl: 'http://localhost:8080',
    database: DartEdgeAuthDatabase.sqlite(
      path: 'var/auth.db',
      manageMigrations: true,
    ),
  ),
);
```

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_auth.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_auth run ffigen --config tool/ffigen.yaml
```
