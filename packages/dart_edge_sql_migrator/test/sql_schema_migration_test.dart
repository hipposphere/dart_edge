import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('plans table and index creation from an empty schema', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(tables: []),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'id',
                type: 'BIGINT',
                nullable: false,
                primaryKey: true,
              ),
              SqlColumnSchema(name: 'email', type: 'TEXT', nullable: false),
              SqlColumnSchema(
                name: 'created_at',
                type: 'TIMESTAMPTZ',
                nullable: false,
                defaultExpression: 'CURRENT_TIMESTAMP',
              ),
            ],
            indexes: [
              SqlIndexSchema(
                name: 'users_email_key',
                columns: ['email'],
                unique: true,
              ),
            ],
          ),
        ],
      ),
    );

    expect(diff.operations, hasLength(2));
    expect(diff.operations.map((operation) => operation.safety), [
      SqlSchemaMigrationSafety.safe,
      SqlSchemaMigrationSafety.safe,
    ]);

    final statements = diff
        .toMigrationPlan()
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();

    expect(statements, [
      'CREATE TABLE "users" ("id" BIGINT NOT NULL PRIMARY KEY, '
          '"email" TEXT NOT NULL, '
          '"created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP)',
      'CREATE UNIQUE INDEX "users_email_key" ON "users" ("email")',
    ]);
  });

  test('plans safe additive columns by default', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'id',
                type: 'INTEGER',
                nullable: false,
                primaryKey: true,
              ),
            ],
          ),
        ],
      ),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'id',
                type: 'INTEGER',
                nullable: false,
                primaryKey: true,
              ),
              SqlColumnSchema(name: 'nickname', type: 'TEXT'),
              SqlColumnSchema(
                name: 'created_at',
                type: 'TEXT',
                nullable: false,
                defaultExpression: "'1970-01-01T00:00:00Z'",
              ),
            ],
          ),
        ],
      ),
    );

    final statements = diff
        .toMigrationPlan()
        .forDialect(SqlDialect.sqlite)
        .map((statement) => statement.sql)
        .toList();

    expect(statements, [
      'ALTER TABLE "users" ADD COLUMN "nickname" TEXT',
      'ALTER TABLE "users" ADD COLUMN "created_at" TEXT NOT NULL '
          "DEFAULT '1970-01-01T00:00:00Z'",
    ]);
  });

  test('keeps review and destructive operations out of default plans', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'id',
                type: 'INTEGER',
                nullable: false,
                primaryKey: true,
              ),
              SqlColumnSchema(name: 'legacy_name', type: 'TEXT'),
            ],
          ),
        ],
      ),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'id',
                type: 'INTEGER',
                nullable: false,
                primaryKey: true,
              ),
              SqlColumnSchema(name: 'email', type: 'TEXT', nullable: false),
            ],
          ),
        ],
      ),
    );

    expect(diff.operations.map((operation) => operation.safety), [
      SqlSchemaMigrationSafety.requiresReview,
      SqlSchemaMigrationSafety.destructive,
    ]);
    expect(diff.toMigrationPlan().forDialect(SqlDialect.sqlite), isEmpty);

    final destructiveStatements = diff
        .toMigrationPlan(includeDestructiveOperations: true)
        .forDialect(SqlDialect.sqlite)
        .map((statement) => statement.sql);

    expect(destructiveStatements, [
      'ALTER TABLE "users" DROP COLUMN "legacy_name"',
    ]);
  });

  test('reports reviewed column changes with actionable details', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'app',
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'email',
                type: 'TEXT',
                defaultExpression: "'unknown@example.com'",
              ),
            ],
          ),
        ],
      ),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'app',
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'email',
                type: 'VARCHAR(320)',
                nullable: false,
                unique: true,
              ),
            ],
          ),
        ],
      ),
    );

    final report = diff.reviewReport;

    expect(report.isNotEmpty, isTrue);
    expect(report.items.single.target, 'app.users.email');
    expect(report.items.single.summary, 'change column definition');
    expect(
      report.items.single.details,
      containsAll([
        'type: TEXT -> VARCHAR(320); add an explicit cast or data rewrite if '
            'existing values need conversion.',
        'nullable: true -> false; validate or backfill existing NULL values '
            'before enforcing NOT NULL.',
        'unique: false -> true; validate duplicates and choose the constraint '
            'or index name explicitly.',
        "default: 'unknown@example.com' -> none; SQLite requires a table "
            'rebuild.',
      ]),
    );
    expect(report.format(), contains('Manual migration required:'));
    expect(
      report.format(),
      contains('Suggested action: Write a reviewed migration'),
    );
  });

  test('reports non-null column additions that need a backfill', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(tables: [SqlTableSchema(name: 'users')]),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            name: 'users',
            columns: [
              SqlColumnSchema(name: 'email', type: 'TEXT', nullable: false),
            ],
          ),
        ],
      ),
    );

    final report = diff.reviewReport;

    expect(report.items.single.target, 'users.email');
    expect(
      report.items.single.summary,
      'add non-null column without a default',
    );
    expect(report.items.single.details, [
      'type: TEXT',
      'nullable: false',
      'default: none',
    ]);
    expect(
      report.format(),
      contains('Backfill existing rows or add a default'),
    );
  });

  test('renders safe PostgreSQL column alterations by default', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'app',
            name: 'users',
            columns: [
              SqlColumnSchema(
                name: 'nickname',
                type: 'TEXT',
                nullable: false,
                defaultExpression: "'anonymous'",
              ),
            ],
          ),
        ],
      ),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'app',
            name: 'users',
            columns: [SqlColumnSchema(name: 'nickname', type: 'TEXT')],
          ),
        ],
      ),
    );

    final postgresStatements = diff
        .toMigrationPlan()
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();
    final sqliteStatements = diff.toMigrationPlan().forDialect(
      SqlDialect.sqlite,
    );

    expect(postgresStatements, [
      'ALTER TABLE "app"."users" ALTER COLUMN "nickname" DROP NOT NULL',
      'ALTER TABLE "app"."users" ALTER COLUMN "nickname" DROP DEFAULT',
    ]);
    expect(sqliteStatements, isEmpty);
    expect(diff.reviewReportForDialect(SqlDialect.postgres).isEmpty, isTrue);
    expect(
      diff.reviewReportForDialect(SqlDialect.sqlite).items.single.details,
      [
        'nullable: false -> true; SQLite requires a table rebuild.',
        "default: 'anonymous' -> none; SQLite requires a table rebuild.",
      ],
    );
  });

  test('uses PostgreSQL schema qualification when rendering tables', () {
    final table = const SqlTableSchema(
      schema: 'billing',
      name: 'invoices',
      columns: [
        SqlColumnSchema(
          name: 'tenant_id',
          type: 'TEXT',
          nullable: false,
          primaryKey: true,
        ),
        SqlColumnSchema(
          name: 'number',
          type: 'TEXT',
          nullable: false,
          primaryKey: true,
        ),
      ],
    );

    final statements = CreateSqlTable(
      table,
    ).toStatements(SqlDialect.postgres).map((statement) => statement.sql);

    expect(statements, [
      'CREATE TABLE "billing"."invoices" ("tenant_id" TEXT NOT NULL, '
          '"number" TEXT NOT NULL, PRIMARY KEY ("tenant_id", "number"))',
    ]);
  });
}
