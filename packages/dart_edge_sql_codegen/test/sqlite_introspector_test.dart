import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:test/test.dart';

void main() {
  test('introspects a live sqlite database through dart_edge_sql', () async {
    final database = SqliteDatabase.inMemory();
    addTearDown(database.close);

    await database.execute(
      sql('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        display_name TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    '''),
    );
    await database.execute(
      sql('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL
      )
    '''),
    );

    final schema = await SqliteIntrospector.fromDatabase(
      database,
      includeTables: {'users', 'audit_log'},
      excludeTables: {'audit_log'},
    ).introspect();

    expect(schema.dialect, SqlCodegenDialect.sqlite);
    expect(schema.tables, hasLength(1));
    expect(schema.tables.single.name, 'users');

    final columnsByName = {
      for (final column in schema.tables.single.columns) column.name: column,
    };
    expect(
      columnsByName.keys,
      containsAll(<String>['id', 'email', 'display_name', 'created_at']),
    );
    expect(columnsByName['id']!.primaryKey, isTrue);
    expect(columnsByName['email']!.nullable, isFalse);
    expect(columnsByName['email']!.dartType, 'String');
    expect(columnsByName['display_name']!.nullable, isTrue);
    expect(columnsByName['created_at']!.hasDefault, isTrue);
    expect(columnsByName['created_at']!.dartType, 'DateTime');

    final stillOpen = await database.execute(
      sql('SELECT COUNT(*) AS count FROM sqlite_master'),
    );
    expect(stillOpen.single.read<int>('count'), greaterThan(0));
  });
}
