# simple_test

Small end-to-end Dart Edge app with HTTP routes, auth, SQL migrations, and
generated SQL descriptors.

## Package shape

`bin/main.dart` only starts the app. The server package is built in layers:

- `lib/server.dart` wires services, migrations, routes, auth, and OpenAPI.
- `lib/src/service.dart` defines the request service boundary.
- `lib/src/routes/` contains route modules with `route.dart`, `schema.dart`,
  and generated `route.g.dart`.
- `lib/generated/` contains checked-in SQL descriptors generated from the
  migrations.

## Regenerate SQL descriptors

The SQL example introspects the migrated PGlite database and writes the
generated Dart library directly:

```shell
dart run tool/generate_db_schema.dart
```

The output is checked in:

```text
lib/generated/app_schema.g.dart
lib/generated/schemas/public/schema.g.dart
lib/generated/schemas/public/tables/*.g.dart
```

Application code imports the generated `.g.dart` file directly.

For apps that already have a migrated PostgreSQL database, the package CLI can
do the same introspection step:

```shell
dart run dart_edge_sql_codegen:schema --postgres postgres://localhost/app --out lib/generated --class AppSchema
```
