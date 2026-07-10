# dart_edge_sql_codegen

Schema introspection and Dart descriptor generation for `dart_edge_sql`.

Use this package when you want to inspect a live PostgreSQL or SQLite database
and emit a structured Dart source tree containing:

- row, insert, and update model classes
- `SqlTable` and `SqlColumn` descriptors
- JSON Schema definitions for those generated model classes

## Typical Flow

### CLI

For a live SQLite database:

```shell
dart run dart_edge_sql_codegen:schema \
  --sqlite app.db \
  --out lib/generated \
  --class AppSchema
```

For PostgreSQL:

```shell
dart run dart_edge_sql_codegen:schema \
  --postgres postgres://localhost/app \
  --schemas public,tenant \
  --out lib/generated \
  --class AppSchema
```

That writes a structured generated tree:

```text
lib/generated/
  app_schema.g.dart
  schemas/
    default/
      schema.g.dart
      tables/
        users.g.dart
      enums/
```

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
    naming: DartSchemaNaming.schemaPrefixed,
  );
  emission.writeToDirectory('lib/generated');

  await database.close();
}
```

That writes the same layout as the CLI:

```text
lib/generated/
  app_schema.g.dart
  schemas/
    default/
      schema.g.dart
      tables/
        users.g.dart
      enums/
```

### build_runner output

For checked-in schema snapshots, add a JSON file ending in `.schema.json` and
run build_runner:

```shell
dart run build_runner build
```

The builder emits Dart libraries beside the snapshot:

```text
lib/app_schema.schema.json
lib/app_schema.g.dart
```

Configure build_runner naming in your package `build.yaml`:

```yaml
targets:
  $default:
    builders:
      dart_edge_sql_codegen:dart_edge_sql:
        options:
          database_class_name: AppSchema
          model_name_style: schema_prefixed
          primary_key_extension_types: true
```

`schema_prefixed` generates table model classes such as `PublicGroupRow`,
`PublicGroupInsert`, `PublicGroupUpdate`, and `PublicGroupTable`, and is the
default style. Use `model_name_style: unprefixed` to keep the historical
`GroupRow` naming. Programmatic generation can use a custom
`DartSchemaNaming(modelNameBuilder: ...)` when a project needs a different
convention.

Primary key extension types are enabled by default. A single-column primary key
such as `notes.id` generates a value object like `NoteId`; the suffix follows
the primary key column, so `api_key.key` generates `ApiKeyKey`. Single-column
foreign keys that reference a primary key use the referenced table's key type. Set
`primary_key_extension_types: false`, pass
`primaryKeyExtensionTypes: false`, or use
`--no-primary-key-extension-types` when a project needs primitive key fields.
When a generated table references a table that you intentionally exclude, map
that referenced key with `external_primary_keys`:

```yaml
external_primary_keys:
  auth.user.id:
    type: AuthUserId
    base_type: String
```

The structured emitter always writes configured external value types to
`external_keys.g.dart` and imports them from tables whose foreign keys use them.
The one-shot CLI accepts the same mapping as
`--external-primary-keys auth.user.id=AuthUserId:String`.

Generated key extension types expose a static `manifest` constant describing
their SQL key. The generated database class aggregates those constants in its
static `sqlKeyManifest` field for single-column primary keys and configured
external primary keys.

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
  ],
  "routines": [
    {
      "name": "find_user",
      "schema": "public",
      "kind": "function",
      "returnDatabaseType": "record",
      "returnDartType": "Object?",
      "returnsSet": true,
      "parameters": [
        {
          "name": "email",
          "databaseType": "text",
          "dartType": "String"
        }
      ]
    }
  ]
}
```

## Main Types

- `SqliteIntrospector` and `PostgresIntrospector` read schema metadata through
  `dart_edge_sql`
- `IntrospectedDatabase`, `IntrospectedTable`, `IntrospectedColumn`, and
  `IntrospectedRoutine` describe the discovered schema
- `emitDartSchema` turns that description into a `DartSchemaEmission`
- `emitDartSchemaLibrary` emits the single-library form used by build_runner
- `DartSchemaEmission.writeToDirectory(...)` replaces stale generated files and
  writes the structured output tree
- `SqlCodegenConfig` is a configuration object you can reuse from your own
  tooling

For PostgreSQL snapshots, introspected functions and procedures are emitted as
schema-scoped routine wrappers. The first pass returns `SqlResult` directly,
while still generating typed Dart parameters and SQL calls for the routine.

The one-shot constructors that accept a SQLite path or PostgreSQL connection
string still exist, but `fromDatabase(...)` lets you introspect an already-open
`SqliteDatabase` or `PostgresPool`.

See [test/dart_schema_emitter_test.dart](test/dart_schema_emitter_test.dart)
for the expected output shape.
