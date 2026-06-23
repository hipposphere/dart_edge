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

  test('renders check constraints inline for new tables', () {
    final statements = CreateSqlTable(
      const SqlTableSchema(
        schema: 'workspace',
        name: 'file_revisions',
        columns: [
          SqlColumnSchema(name: 'id', type: 'UUID', nullable: false),
          SqlColumnSchema(
            name: 'indexation_status',
            type: 'TEXT',
            nullable: false,
            defaultExpression: "'not_indexed'::text",
          ),
        ],
        checks: [
          SqlCheckConstraintSchema(
            name: 'file_revisions_indexation_status_check',
            expression:
                "indexation_status IN ('not_indexed', 'pending', 'indexed')",
          ),
        ],
      ),
    ).toStatements(SqlDialect.postgres).map((statement) => statement.sql);

    expect(statements, [
      'CREATE TABLE "workspace"."file_revisions" ("id" UUID NOT NULL, '
          '"indexation_status" TEXT NOT NULL DEFAULT \'not_indexed\'::text, '
          'CONSTRAINT "file_revisions_indexation_status_check" '
          "CHECK (indexation_status IN ('not_indexed', 'pending', 'indexed')))",
    ]);
  });

  test('renders table constraints and rich partial indexes', () {
    const table = SqlTableSchema(
      schema: 'workspace',
      name: 'file_revisions',
      columns: [
        SqlColumnSchema(
          name: 'id',
          type: 'UUID',
          nullable: false,
          primaryKey: true,
        ),
        SqlColumnSchema(name: 'file_id', type: 'UUID', nullable: false),
        SqlColumnSchema(name: 'workspace_id', type: 'UUID', nullable: false),
        SqlColumnSchema(
          name: 'indexation_status',
          type: 'TEXT',
          nullable: false,
          defaultExpression: "'not_indexed'::text",
        ),
      ],
      checks: [
        SqlTextEnumCheckConstraintSchema(
          name: 'file_revisions_indexation_status_check',
          column: 'indexation_status',
          values: ['not_indexed', 'pending', 'indexed', 'failed'],
        ),
      ],
      uniqueConstraints: [
        SqlUniqueConstraintSchema(
          name: 'file_revisions_workspace_file_id_key',
          columns: ['workspace_id', 'file_id', 'id'],
        ),
      ],
      foreignKeys: [
        SqlForeignKeyConstraintSchema(
          name: 'file_revisions_file_id_fkey',
          columns: ['file_id'],
          referencesSchema: 'workspace',
          referencesTable: 'files',
          referencesColumns: ['id'],
          onDelete: SqlForeignKeyAction.cascade,
        ),
      ],
      indexes: [
        SqlIndexSchema(
          name: 'idx_file_revisions_active_created',
          columns: ['workspace_id', 'created_at'],
          columnOrders: {'created_at': SqlSortOrder.descending},
          columnNullsOrders: {'created_at': SqlNullsOrder.last},
          whereExpression: 'deleted_at is null',
        ),
      ],
    );

    final createTableStatements = CreateSqlTable(
      table,
    ).toStatements(SqlDialect.postgres).map((statement) => statement.sql);
    final createIndexStatements = CreateSqlIndex(
      table: table,
      index: table.indexes.single,
    ).toStatements(SqlDialect.postgres).map((statement) => statement.sql);

    expect(createTableStatements, [
      'CREATE TABLE "workspace"."file_revisions" '
          '("id" UUID NOT NULL PRIMARY KEY, '
          '"file_id" UUID NOT NULL, '
          '"workspace_id" UUID NOT NULL, '
          '"indexation_status" TEXT NOT NULL DEFAULT \'not_indexed\'::text, '
          'CONSTRAINT "file_revisions_indexation_status_check" '
          'CHECK ("indexation_status" in '
          "('not_indexed', 'pending', 'indexed', 'failed')), "
          'CONSTRAINT "file_revisions_workspace_file_id_key" '
          'UNIQUE ("workspace_id", "file_id", "id"), '
          'CONSTRAINT "file_revisions_file_id_fkey" '
          'FOREIGN KEY ("file_id") REFERENCES "workspace"."files" ("id") '
          'ON DELETE CASCADE)',
    ]);
    expect(createIndexStatements, [
      'CREATE INDEX "idx_file_revisions_active_created" '
          'ON "workspace"."file_revisions" '
          '("workspace_id", "created_at" DESC NULLS LAST) '
          'WHERE deleted_at is null',
    ]);
  });

  test('requires review when adding check constraints to existing tables', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'workspace',
            name: 'file_revisions',
            columns: [
              SqlColumnSchema(
                name: 'indexation_status',
                type: 'TEXT',
                nullable: false,
              ),
            ],
          ),
        ],
      ),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'workspace',
            name: 'file_revisions',
            columns: [
              SqlColumnSchema(
                name: 'indexation_status',
                type: 'TEXT',
                nullable: false,
              ),
            ],
            checks: [
              SqlCheckConstraintSchema(
                name: 'file_revisions_indexation_status_check',
                expression:
                    "indexation_status IN ('not_indexed', 'pending', "
                    "'indexed')",
              ),
            ],
          ),
        ],
      ),
    );

    expect(diff.operations.single, isA<AddSqlCheckConstraint>());
    expect(
      diff.operations.single.safety,
      SqlSchemaMigrationSafety.requiresReview,
    );
    expect(diff.toMigrationPlan().forDialect(SqlDialect.postgres), isEmpty);
    expect(diff.toMigrationPlan().forDialect(SqlDialect.sqlite), isEmpty);
    expect(
      diff.reviewReport.items.single.target,
      'workspace.file_revisions.file_revisions_indexation_status_check',
    );

    final reviewedPostgresStatements = diff
        .toMigrationPlan(includeReviewedOperations: true)
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();
    final reviewedSqliteStatements = diff
        .toMigrationPlan(includeReviewedOperations: true)
        .forDialect(SqlDialect.sqlite);

    expect(reviewedPostgresStatements, [
      'ALTER TABLE "workspace"."file_revisions" ADD '
          'CONSTRAINT "file_revisions_indexation_status_check" '
          "CHECK (indexation_status IN ('not_indexed', 'pending', 'indexed'))",
    ]);
    expect(reviewedSqliteStatements, isEmpty);
    expect(
      diff.reviewReportForDialect(SqlDialect.sqlite).items.single.details,
      contains('SQLite requires a table rebuild to add table constraints.'),
    );
  });

  test('requires review when adding unique and foreign key constraints', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [SqlTableSchema(schema: 'workspace', name: 'file_revisions')],
      ),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'workspace',
            name: 'file_revisions',
            uniqueConstraints: [
              SqlUniqueConstraintSchema(
                name: 'file_revisions_workspace_file_id_key',
                columns: ['workspace_id', 'file_id', 'id'],
              ),
            ],
            foreignKeys: [
              SqlForeignKeyConstraintSchema(
                name: 'file_revisions_file_id_fkey',
                columns: ['file_id'],
                referencesSchema: 'workspace',
                referencesTable: 'files',
                referencesColumns: ['id'],
                onDelete: SqlForeignKeyAction.cascade,
              ),
            ],
          ),
        ],
      ),
    );

    expect(diff.operations, [
      isA<AddSqlUniqueConstraint>(),
      isA<AddSqlForeignKeyConstraint>(),
    ]);
    expect(
      diff.operations.map((operation) => operation.safety),
      everyElement(SqlSchemaMigrationSafety.requiresReview),
    );
    expect(diff.toMigrationPlan().forDialect(SqlDialect.postgres), isEmpty);

    final reviewedStatements = diff
        .toMigrationPlan(includeReviewedOperations: true)
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();

    expect(reviewedStatements, [
      'ALTER TABLE "workspace"."file_revisions" ADD '
          'CONSTRAINT "file_revisions_workspace_file_id_key" '
          'UNIQUE ("workspace_id", "file_id", "id")',
      'ALTER TABLE "workspace"."file_revisions" ADD '
          'CONSTRAINT "file_revisions_file_id_fkey" '
          'FOREIGN KEY ("file_id") REFERENCES "workspace"."files" ("id") '
          'ON DELETE CASCADE',
    ]);
  });

  test('drops changed or removed check constraints only when destructive', () {
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'workspace',
            name: 'file_revisions',
            checks: [
              SqlCheckConstraintSchema(
                name: 'file_revisions_indexation_status_check',
                expression: "indexation_status IN ('pending', 'indexed')",
              ),
            ],
          ),
        ],
      ),
      desired: const SqlDatabaseSchema(
        tables: [SqlTableSchema(schema: 'workspace', name: 'file_revisions')],
      ),
    );

    expect(diff.operations.single, isA<DropSqlCheckConstraint>());
    expect(diff.toMigrationPlan().forDialect(SqlDialect.postgres), isEmpty);

    final destructiveStatements = diff
        .toMigrationPlan(includeDestructiveOperations: true)
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();

    expect(destructiveStatements, [
      'ALTER TABLE "workspace"."file_revisions" '
          'DROP CONSTRAINT "file_revisions_indexation_status_check"',
    ]);
  });

  test(
    'treats simple IN checks and postgres ANY ARRAY checks as equivalent',
    () {
      final diff = SqlSchemaDiff.between(
        current: const SqlDatabaseSchema(
          tables: [
            SqlTableSchema(
              name: 'file_revisions',
              checks: [
                SqlCheckConstraintSchema(
                  name: 'file_revisions_indexation_status_check',
                  expression:
                      "indexation_status = ANY (ARRAY['not_indexed'::text, "
                      "'pending'::text, 'indexed'::text])",
                ),
              ],
            ),
          ],
        ),
        desired: const SqlDatabaseSchema(
          tables: [
            SqlTableSchema(
              name: 'file_revisions',
              checks: [
                SqlCheckConstraintSchema(
                  name: 'file_revisions_indexation_status_check',
                  expression:
                      "indexation_status in ('not_indexed', 'pending', "
                      "'indexed')",
                ),
              ],
            ),
          ],
        ),
      );

      expect(diff.operations, isEmpty);
    },
  );

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

  test('plans PostgreSQL RPC function creation', () {
    const routine = SqlRoutineSchema(
      schema: 'public',
      name: 'search_users',
      identityArguments: 'query text',
      definition: '''
CREATE OR REPLACE FUNCTION public.search_users(query text)
RETURNS TABLE(id uuid, email text)
LANGUAGE sql
AS \$\$
  SELECT id, email FROM users WHERE email ILIKE '%' || query || '%'
\$\$
''',
    );
    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(tables: []),
      desired: const SqlDatabaseSchema(tables: [], routines: [routine]),
    );

    expect(diff.operations.single, isA<CreateSqlRoutine>());
    expect(diff.toMigrationPlan().forDialect(SqlDialect.sqlite), isEmpty);

    final statements = diff
        .toMigrationPlan()
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();

    expect(statements, [routine.definition.trim()]);
  });

  test('diffs overloaded PostgreSQL RPC functions by identity arguments', () {
    const current = SqlDatabaseSchema(
      tables: [],
      routines: [
        SqlRoutineSchema(
          schema: 'public',
          name: 'search_users',
          identityArguments: 'query text',
          definition: '''
CREATE OR REPLACE FUNCTION public.search_users(query text)
RETURNS SETOF users
LANGUAGE sql
AS \$\$ SELECT * FROM users \$\$
''',
        ),
        SqlRoutineSchema(
          schema: 'public',
          name: 'lookup_user',
          identityArguments: 'id uuid',
          definition: '''
CREATE OR REPLACE FUNCTION public.lookup_user(id uuid)
RETURNS users
LANGUAGE sql
AS \$\$ SELECT * FROM users WHERE users.id = id \$\$
''',
        ),
      ],
    );
    const desired = SqlDatabaseSchema(
      tables: [],
      routines: [
        SqlRoutineSchema(
          schema: 'public',
          name: 'search_users',
          identityArguments: 'query text',
          definition: '''
CREATE OR REPLACE FUNCTION public.search_users(query text)
RETURNS SETOF users
LANGUAGE sql
AS \$\$ SELECT * FROM users WHERE email ILIKE '%' || query || '%' \$\$
''',
        ),
        SqlRoutineSchema(
          schema: 'public',
          name: 'search_users',
          identityArguments: 'tenant_id uuid, query text',
          definition: '''
CREATE OR REPLACE FUNCTION public.search_users(tenant_id uuid, query text)
RETURNS SETOF users
LANGUAGE sql
AS \$\$ SELECT * FROM users WHERE users.tenant_id = tenant_id \$\$
''',
        ),
      ],
    );

    final diff = SqlSchemaDiff.between(current: current, desired: desired);

    expect(diff.operations, [
      isA<ReplaceSqlRoutine>(),
      isA<CreateSqlRoutine>(),
      isA<DropSqlRoutine>(),
    ]);

    final defaultStatements = diff
        .toMigrationPlan()
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();
    expect(defaultStatements, [
      desired.routines[0].definition.trim(),
      desired.routines[1].definition.trim(),
    ]);

    final destructiveStatements = diff
        .toMigrationPlan(includeDestructiveOperations: true)
        .forDialect(SqlDialect.postgres)
        .map((statement) => statement.sql)
        .toList();
    expect(destructiveStatements, [
      desired.routines[0].definition.trim(),
      desired.routines[1].definition.trim(),
      'DROP FUNCTION "public"."lookup_user"(id uuid)',
    ]);
  });
}
