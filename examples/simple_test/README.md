# simple_test

Small end-to-end Dart Edge app with HTTP routes, auth, SQL migrations, and
generated SQL descriptors.

## Regenerate SQL descriptors

The SQL example introspects the migrated SQLite database and writes the
generated Dart library directly:

```shell
dart run scripts/generate_db_schema.dart
```

The output is checked in:

```text
lib/generated/app_schema.g.dart
lib/generated/schemas/default/schema.g.dart
lib/generated/schemas/default/tables/*.g.dart
lib/generated/schemas/default/enums/
```

Application code imports the generated `.g.dart` file directly.

For apps that already have a migrated database file, the package CLI can do the
same introspection step:

```shell
dart run dart_edge_sql_codegen:schema --sqlite sqlite.db --out lib/generated --class AppSchema
```
