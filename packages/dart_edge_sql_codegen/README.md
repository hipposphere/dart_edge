# dart_edge_sql_codegen

Schema introspection and Dart descriptor generation for `dart_edge_sql`.

Use this package when you want to inspect a live PostgreSQL or SQLite database
and emit a structured Dart source tree containing:

- row, insert, and update model classes
- `SqlTable` and `SqlColumn` descriptors
- JSON Schema definitions for those generated model classes

## Typical Flow

### Programmatic structured output

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';

Future<void> main() async {
  final database = SqliteDatabase.open('app.db');
  final schema = await SqliteIntrospector.fromDatabase(database).introspect();
  final emission = emitDartSchema(
    schema,
    databaseClassName: 'AppSchema',
  );
  emission.writeToDirectory('lib/generated');

  await database.close();
}
```

That writes a layout like:

```text
lib/generated/
  app_schema.dart
  schemas/
    default/
      schema.dart
      tables/
        users.dart
      enums/
```

### build_runner output

For checked-in schema snapshots, add a JSON file ending in
`.dart_edge_sql.json` and run build_runner:

```shell
dart run build_runner build
```

The builder emits a single Dart library beside the snapshot:

```text
lib/schema.dart_edge_sql.json
lib/schema.dart_edge_sql.g.dart
```

Snapshot JSON uses the same shape as `IntrospectedDatabase.toJson()`:

```json
{
  "databaseClassName": "AppSchema",
  "dialect": "sqlite",
  "tables": [
    {
      "name": "users",
      "columns": [
        {
          "name": "id",
          "databaseType": "INTEGER",
          "dartType": "int",
          "primaryKey": true
        }
      ]
    }
  ]
}
```

## Main Types

- `SqliteIntrospector` and `PostgresIntrospector` read schema metadata through
  `dart_edge_sql`
- `IntrospectedDatabase`, `IntrospectedTable`, and `IntrospectedColumn`
  describe the discovered schema
- `emitDartSchema` turns that description into a `DartSchemaEmission`
- `emitDartSchemaLibrary` emits the single-library form used by build_runner
- `DartSchemaEmission.writeToDirectory(...)` replaces stale generated files and
  writes the structured output tree
- `SqlCodegenConfig` is a configuration object you can reuse from your own
  tooling

The one-shot constructors that accept a SQLite path or PostgreSQL connection
string still exist, but `fromDatabase(...)` lets you introspect an already-open
`SqliteDatabase` or `PostgresPool`.

See [test/dart_schema_emitter_test.dart](test/dart_schema_emitter_test.dart)
for the expected output shape.
