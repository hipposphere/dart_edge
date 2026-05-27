import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('uses postgres-specific metadata SQL and rollback statements', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql([
            'CREATE TABLE users (id BIGINT PRIMARY KEY)',
          ]),
          down: SqlMigrationPlan.sql(['DROP TABLE users']),
        ),
      ],
    );

    expect(await migrator.migrateToLatest(), 1);
    expect(await migrator.rollback(), 1);

    const schema = DartEdgeSqlMigrator.defaultPostgresTableSchema;
    expect(pool.executed[0].sql, 'CREATE SCHEMA IF NOT EXISTS $schema');
    expect(pool.executed[1].sql, contains('TIMESTAMPTZ'));
    expect(
      pool.executed[1].sql,
      contains('CREATE TABLE IF NOT EXISTS $schema.migrations'),
    );
    expect(
      pool.executed.any(
        (statement) =>
            statement.sql ==
            'INSERT INTO $schema.migrations (version, name, applied_order, checksum) VALUES (\$1, \$2, \$3, \$4)',
      ),
      isTrue,
    );
    expect(
      pool.executed.any(
        (statement) =>
            statement.sql ==
            'DELETE FROM $schema.migrations WHERE version = \$1',
      ),
      isTrue,
    );
  });

  test('uses postgres metadata table schema when configured', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      tableSchema: 'app_meta',
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql(['CREATE TABLE users (id BIGINT)']),
          down: SqlMigrationPlan.sql(['DROP TABLE users']),
        ),
      ],
    );

    expect(await migrator.migrateToLatest(), 1);

    expect(pool.executed.first.sql, 'CREATE SCHEMA IF NOT EXISTS app_meta');
    expect(
      pool.executed[1].sql,
      contains('CREATE TABLE IF NOT EXISTS app_meta.migrations'),
    );
    expect(
      pool.executed.any(
        (statement) =>
            statement.sql ==
            'INSERT INTO app_meta.migrations (version, name, applied_order, checksum) VALUES (\$1, \$2, \$3, \$4)',
      ),
      isTrue,
    );
  });

  test('detects changed migration SQL after it was applied', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final original = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql(['CREATE TABLE users (id BIGINT)']),
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
            'CREATE TABLE users (id BIGINT, email TEXT)',
          ]),
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

  test('baselines applied versions without executing migration SQL', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql(['CREATE TABLE users (id BIGINT)']),
        ),
        SqlMigration(
          version: '0002',
          name: 'create_audit_log',
          up: SqlMigrationPlan.sql(['CREATE TABLE audit_log (id BIGINT)']),
        ),
      ],
    );

    expect(await migrator.baselineAppliedVersions(['0001']), 1);

    final status = await migrator.status();
    expect(status.canBaseline, isFalse);
    expect(status.applied.map((migration) => migration.version), ['0001']);
    expect(status.pending.map((migration) => migration.version), ['0002']);
    expect(
      pool.executed.any(
        (statement) => statement.sql == 'CREATE TABLE users (id BIGINT)',
      ),
      isFalse,
    );
  });

  test('backfills applied order from configured migration order', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final appliedAt = DateTime.utc(2026);
    pool._applied.addAll([
      AppliedSqlMigration(
        version: '0',
        name: 'bootstrap',
        appliedAt: appliedAt,
      ),
      AppliedSqlMigration(version: '1', name: 'setup', appliedAt: appliedAt),
      AppliedSqlMigration(version: '10', name: 'ten', appliedAt: appliedAt),
      AppliedSqlMigration(version: '2', name: 'two', appliedAt: appliedAt),
    ]);
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

    expect(status.applied.map((migration) => migration.version), [
      '0',
      '1',
      '2',
      '10',
    ]);
    expect(pool._appliedOrders, {'0': 1, '1': 2, '10': 4, '2': 3});
  });

  test('rejects non-prefix baseline versions', () {
    final pool = _RecordingPool(SqlDialect.postgres);
    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      migrations: [
        SqlMigration(
          version: '0001',
          name: 'create_users',
          up: SqlMigrationPlan.sql(['CREATE TABLE users (id BIGINT)']),
        ),
        SqlMigration(
          version: '0002',
          name: 'create_audit_log',
          up: SqlMigrationPlan.sql(['CREATE TABLE audit_log (id BIGINT)']),
        ),
      ],
    );

    expect(
      () => migrator.baselineAppliedVersions(['0002']),
      throwsArgumentError,
    );
  });

  test('rejects duplicate migration versions', () {
    final pool = _RecordingPool(SqlDialect.sqlite);

    expect(
      () => DartEdgeSqlMigrator(
        pool: pool,
        migrations: [
          SqlMigration(
            version: '0001',
            name: 'create_users',
            up: SqlMigrationPlan.sql(['CREATE TABLE users (id INTEGER)']),
          ),
          SqlMigration(
            version: '0001',
            name: 'create_profiles',
            up: SqlMigrationPlan.sql(['CREATE TABLE profiles (id INTEGER)']),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}

final class _RecordingPool implements SqlPool {
  _RecordingPool(this.dialect);

  @override
  final SqlDialect dialect;

  final List<SqlStatement> executed = <SqlStatement>[];
  final List<AppliedSqlMigration> _applied = <AppliedSqlMigration>[];
  final Map<String, int?> _appliedOrders = <String, int?>{};

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw UnsupportedError('Use withTransaction in migrator tests.');
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    return action(_RecordingSession(this));
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    return action(_RecordingTransaction(this));
  }

  @override
  Future<void> close() async {}
}

class _RecordingSession implements SqlSession {
  _RecordingSession(this.pool);

  final _RecordingPool pool;

  @override
  SqlDialect get dialect => pool.dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) async {
    pool.executed.add(statement);

    final normalized = statement.sql.trimLeft().toUpperCase();
    if (normalized.startsWith('SELECT COLUMN_NAME') ||
        normalized.startsWith('PRAGMA TABLE_INFO')) {
      return SqlResult(
        rows: [
          SqlRow({'column_name': 'checksum'}),
          SqlRow({'column_name': 'applied_order'}),
        ],
      );
    }

    if (normalized.startsWith('SELECT VERSION, APPLIED_ORDER')) {
      return SqlResult(
        rows: [
          for (final migration in pool._applied)
            SqlRow({
              'version': migration.version,
              'applied_order': pool._appliedOrders[migration.version],
            }),
        ],
      );
    }

    if (normalized.startsWith('SELECT VERSION, NAME, APPLIED_AT')) {
      final applied = pool._applied.toList()
        ..sort((left, right) {
          final leftOrder = pool._appliedOrders[left.version];
          final rightOrder = pool._appliedOrders[right.version];
          if (leftOrder == null && rightOrder == null) {
            return 0;
          }
          if (leftOrder == null) {
            return 1;
          }
          if (rightOrder == null) {
            return -1;
          }
          return leftOrder.compareTo(rightOrder);
        });
      return SqlResult(
        rows: [
          for (final migration in applied)
            SqlRow({
              'version': migration.version,
              'name': migration.name,
              'applied_at': migration.appliedAt,
              'checksum': migration.checksum,
            }),
        ],
      );
    }

    if (normalized.startsWith('INSERT INTO')) {
      final parameters = statement.positionalParameters;
      pool._applied.add(
        AppliedSqlMigration(
          version: parameters[0]! as String,
          name: parameters[1]! as String,
          checksum: parameters[3]! as String,
          appliedAt: DateTime.utc(2026, 1, 1, 0, 0, pool._applied.length),
        ),
      );
      pool._appliedOrders[parameters[0]! as String] = parameters[2]! as int;
      return SqlResult(affectedRows: 1);
    }

    if (normalized.startsWith('UPDATE')) {
      final parameters = statement.positionalParameters;
      pool._appliedOrders[parameters[1]! as String] = parameters[0]! as int;
      return SqlResult(affectedRows: 1);
    }

    if (normalized.startsWith('DELETE FROM')) {
      final version = statement.positionalParameters.single! as String;
      pool._applied.removeWhere((migration) => migration.version == version);
      pool._appliedOrders.remove(version);
      return SqlResult(affectedRows: 1);
    }

    return SqlResult();
  }

  @override
  Future<PreparedSqlStatement> prepare(SqlStatement statement) {
    throw UnsupportedError('Prepared statements are not needed in tests.');
  }
}

final class _RecordingTransaction extends _RecordingSession
    implements SqlTransaction {
  _RecordingTransaction(super.pool);
}
