# dart_edge_sql_codegen

Schema introspection and Dart descriptor generation for `dart_edge_sql`.

Use this package when you want to inspect a live PostgreSQL or SQLite database
and emit Dart code containing:

- row, insert, and update model classes
- `SqlTable` and `SqlColumn` descriptors
- JSON Schema definitions for those generated model classes

## Typical Flow

```dart
import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';

Future<void> main() async {
  final database = SqliteDatabase.open('app.db');
  final schema = await SqliteIntrospector.fromDatabase(database).introspect();
  final source = emitDartSchema(
    schema,
    libraryName: 'app_schema',
    databaseClassName: 'AppSchema',
  );

  await File('lib/app_schema.dart').writeAsString(source);
  await database.close();
}
```

## Main Types

- `SqliteIntrospector` and `PostgresIntrospector` read schema metadata through
  `dart_edge_sql`
- `IntrospectedDatabase`, `IntrospectedTable`, and `IntrospectedColumn`
  describe the discovered schema
- `emitDartSchema` turns that description into Dart source
- `SqlCodegenConfig` is a configuration object you can reuse from your own
  tooling

The one-shot constructors that accept a SQLite path or PostgreSQL connection
string still exist, but `fromDatabase(...)` lets you introspect an already-open
`SqliteDatabase` or `PostgresPool`.

See [test/dart_schema_emitter_test.dart](test/dart_schema_emitter_test.dart)
for the expected output shape.
