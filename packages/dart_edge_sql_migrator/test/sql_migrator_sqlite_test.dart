import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('applies sqlite migrations and reports status', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            '''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT NOT NULL
            )
            ''',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE users']),
        ),
        SqlMigration(
          version: '0002',
          name: 'create_audit_log',
          up: SqlMigrationPlan.sql([
            '''
            CREATE TABLE audit_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event TEXT NOT NULL
            )
            ''',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE audit_log']),
        ),
      ],
    );

    expect(await migrator.migrateToLatest(), 2);

    final usersTable = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', 'users'],
      ),
    );
    final auditLogTable = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', 'audit_log'],
      ),
    );
    final status = await migrator.status();

    expect(usersTable.single['name'], 'users');
    expect(auditLogTable.single['name'], 'audit_log');
    expect(status.applied.map((migration) => migration.version), [
      '0001',
      '0002',
    ]);
    expect(status.pending, isEmpty);
    expect(status.isUpToDate, isTrue);

    final metadata = await pool.execute(
      sql('SELECT checksum FROM migrations WHERE version = \'0001\''),
    );
    expect(metadata.single['checksum'], isA<String>());
    expect(metadata.single['checksum'] as String, hasLength(64));
  });

  test('detects changed sqlite migration SQL after it was applied', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    final original = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE users']),
        ),
      ],
    );

    await original.migrateToLatest();

    final changed = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL, name TEXT)',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE users']),
        ),
      ],
    );

    expect(
      changed.status,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('checksum does not match'),
        ),
      ),
    );
  });

  test('baselines sqlite migrations without executing their SQL', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            'CREATE TABLE users (id INTEGER PRIMARY KEY)',
          ]),
        ),
        SqlMigration(
          version: '0002',
          name: 'create_audit_log',
          up: SqlMigrationPlan.sql([
            'CREATE TABLE audit_log (id INTEGER PRIMARY KEY)',
          ]),
        ),
      ],
    );

    final before = await migrator.status();
    expect(before.canBaseline, isTrue);
    expect(await migrator.baselineToVersion('0001'), 1);

    final usersTable = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', 'users'],
      ),
    );
    final status = await migrator.status();

    expect(usersTable.isEmpty, isTrue);
    expect(status.canBaseline, isFalse);
    expect(status.hasAppliedMigrations, isTrue);
    expect(status.hasPendingMigrations, isTrue);
    expect(status.applied.map((migration) => migration.version), ['0001']);
    expect(status.pending.map((migration) => migration.version), ['0002']);

    expect(await migrator.migrateToLatest(), 1);
    final auditLogTable = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', 'audit_log'],
      ),
    );
    expect(auditLogTable.single['name'], 'audit_log');
  });

  test('rejects sqlite baseline when metadata already exists', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            'CREATE TABLE users (id INTEGER PRIMARY KEY)',
          ]),
        ),
      ],
    );

    expect(await migrator.baselineToLatest(), 1);

    expect(
      migrator.baselineToLatest,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('already contains applied migrations'),
        ),
      ),
    );
  });

  test('rolls back sqlite migrations through down plans', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            '''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT NOT NULL
            )
            ''',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE users']),
        ),
        SqlMigration(
          version: '0002',
          name: 'create_audit_log',
          up: SqlMigrationPlan.sql([
            '''
            CREATE TABLE audit_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event TEXT NOT NULL
            )
            ''',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE audit_log']),
        ),
      ],
    );

    await migrator.migrateToLatest();
    expect(await migrator.rollback(), 1);

    final usersTable = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', 'users'],
      ),
    );
    final auditLogTable = await pool.execute(
      SqlStatement.positional(
        'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', 'audit_log'],
      ),
    );
    final status = await migrator.status();

    expect(usersTable.single['name'], 'users');
    expect(auditLogTable.isEmpty, isTrue);
    expect(status.applied.map((migration) => migration.version), ['0001']);
    expect(status.pending.map((migration) => migration.version), ['0002']);
  });

  test('backfills sqlite applied order for legacy metadata table', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
      CREATE TABLE migrations (
        version TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        checksum TEXT,
        applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
      '''),
    );
    const appliedAt = '2026-05-27T07:12:49.088292Z';
    for (final (version, name) in [
      ('0', 'bootstrap'),
      ('1', 'setup'),
      ('10', 'ten'),
      ('2', 'two'),
    ]) {
      await pool.execute(
        SqlStatement.positional(
          'INSERT INTO migrations (version, name, applied_at) VALUES (?, ?, ?)',
          [version, name, appliedAt],
        ),
      );
    }

    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0',
          name: 'bootstrap',
          up: SqlMigrationPlan.sql(['SELECT 0']),
        ),
        SqlMigration(
          version: '1',
          name: 'setup',
          up: SqlMigrationPlan.sql(['SELECT 1']),
        ),
        SqlMigration(
          version: '2',
          name: 'two',
          up: SqlMigrationPlan.sql(['SELECT 2']),
        ),
        SqlMigration(
          version: '10',
          name: 'ten',
          up: SqlMigrationPlan.sql(['SELECT 10']),
        ),
      ],
    );

    final status = await migrator.status();
    final metadata = await pool.execute(
      sql(
        'SELECT version, applied_order FROM migrations ORDER BY applied_order',
      ),
    );

    expect(status.applied.map((migration) => migration.version), [
      '0',
      '1',
      '2',
      '10',
    ]);
    expect(
      [
        for (final row in metadata.rows)
          (row.read<String>('version'), row.read<int>('applied_order')),
      ],
      [('0', 1), ('1', 2), ('2', 3), ('10', 4)],
    );
  });
}
