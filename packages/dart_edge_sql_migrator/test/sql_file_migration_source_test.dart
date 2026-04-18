import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('loads file-based migrations with flyway sorting', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_migrator_flyway_',
    );
    addTearDown(() => directory.delete(recursive: true));

    await _writeSql(directory, 'V10__seed_users.sql', '''
      INSERT INTO users (email) VALUES ('seed@example.com');
    ''');
    await _writeSql(directory, 'V2__create_profiles.sqlite.sql', '''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL
      );
    ''');
    await _writeSql(directory, 'V2__create_profiles.postgres.sql', '''
      CREATE TABLE profiles (
        id BIGINT PRIMARY KEY,
        user_id BIGINT NOT NULL
      );
    ''');
    await _writeSql(directory, 'V2__create_profiles.down.sql', '''
      DROP TABLE profiles;
    ''');
    await _writeSql(directory, 'V1__create_users.sql', '''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL
      );
    ''');

    final migrations = await SqlFileMigrationSource(
      folder: directory.path,
      sorting: const SqlMigrationFileSorting.flyway(),
    ).load();

    expect(migrations.map((migration) => migration.version), ['1', '2', '10']);
    expect(migrations.map((migration) => migration.name), [
      'create_users',
      'create_profiles',
      'seed_users',
    ]);
    expect(
      migrations[1].up.byDialect.keys,
      containsAll([SqlDialect.sqlite, SqlDialect.postgres]),
    );
    expect(
      migrations[1].down.shared.single.sql,
      contains('DROP TABLE profiles'),
    );
  });

  test('loads file-based migrations with lexicographic sorting', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_migrator_lexicographic_',
    );
    addTearDown(() => directory.delete(recursive: true));

    await _writeSql(directory, '10_seed.sql', "SELECT 'seed';");
    await _writeSql(directory, '2_create.sql', "SELECT 'create';");

    final migrations = await SqlFileMigrationSource(
      folder: directory.path,
      sorting: const SqlMigrationFileSorting.lexicographic(),
    ).load();

    expect(migrations.map((migration) => migration.version), [
      '10_seed',
      '2_create',
    ]);
  });

  test('migrates sqlite from a folder and supports rollback', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_migrator_folder_',
    );
    addTearDown(() => directory.delete(recursive: true));

    await _writeSql(directory, '0001_create_users.sql', '''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL
      );
      CREATE INDEX users_email_idx ON users (email);
    ''');
    await _writeSql(directory, '0001_create_users.down.sql', '''
      DROP TABLE users;
    ''');
    await _writeSql(directory, '0002_seed_users.sql', '''
      INSERT INTO users (email) VALUES ('ada@example.com');
    ''');
    await _writeSql(directory, '0002_seed_users.down.sql', '''
      DELETE FROM users WHERE email = 'ada@example.com';
    ''');

    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    final migrator = await DartEdgeSqlMigrator.fromFolder(
      pool: pool,
      folder: directory.path,
      sorting: const SqlMigrationFileSorting.lexicographic(),
    );

    expect(await migrator.migrateToLatest(), 2);

    final index = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['index', 'users_email_idx'],
      ),
    );
    final rows = await pool.execute(sql('SELECT email FROM users ORDER BY id'));
    expect(index.single['name'], 'users_email_idx');
    expect(rows.single['email'], 'ada@example.com');

    expect(await migrator.rollback(), 1);
    final afterRollback = await pool.execute(sql('SELECT email FROM users'));
    expect(afterRollback.isEmpty, isTrue);
  });
}

Future<void> _writeSql(Directory directory, String name, String contents) {
  return File('${directory.path}/$name').writeAsString(contents);
}
