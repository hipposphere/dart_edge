import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('uses postgres-specific metadata SQL and rollback statements', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final migrator = DartEdgeSqlMigrator(
      pool: pool,
      tableName: 'schema_migrations',
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

    expect(pool.executed[0].sql, contains('TIMESTAMPTZ'));
    expect(
      pool.executed.any(
        (statement) =>
            statement.sql ==
            'INSERT INTO schema_migrations (version, name) VALUES (\$1, \$2)',
      ),
      isTrue,
    );
    expect(
      pool.executed.any(
        (statement) =>
            statement.sql ==
            'DELETE FROM schema_migrations WHERE version = \$1',
      ),
      isTrue,
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
    if (normalized.startsWith('SELECT VERSION, NAME, APPLIED_AT')) {
      return SqlResult(
        rows: [
          for (final migration in pool._applied)
            SqlRow({
              'version': migration.version,
              'name': migration.name,
              'applied_at': migration.appliedAt,
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
          appliedAt: DateTime.utc(2026, 1, 1, 0, 0, pool._applied.length),
        ),
      );
      return SqlResult(affectedRows: 1);
    }

    if (normalized.startsWith('DELETE FROM')) {
      final version = statement.positionalParameters.single! as String;
      pool._applied.removeWhere((migration) => migration.version == version);
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
