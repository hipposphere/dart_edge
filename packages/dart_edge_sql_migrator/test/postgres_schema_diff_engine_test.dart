import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:test/test.dart';

void main() {
  test(
    'canonicalizes defaults, predicates, checks, and routines through PostgreSQL',
    () async {
      final current = PgliteDatabase.temporary().asPostgresPool();
      final scratch = PgliteDatabase.temporary().asPostgresPool();
      addTearDown(current.close);
      addTearDown(scratch.close);

      await current.execute(sql('CREATE SCHEMA "app"'));
      await current.execute(
        sql('''
CREATE TABLE "app"."profile" (
  "id" UUID NOT NULL PRIMARY KEY,
  "status" TEXT NOT NULL DEFAULT 'provisioning'::text,
  "deleted_at" TIMESTAMPTZ,
  CONSTRAINT "profile_status_check"
    CHECK (("status" = ANY (ARRAY['provisioning'::text, 'ready'::text])))
)
'''),
      );
      await current.execute(
        sql('''
CREATE INDEX "profile_active_idx"
ON "app"."profile" ("status")
WHERE ("deleted_at" IS NULL)
'''),
      );
      await current.execute(
        sql('''
CREATE OR REPLACE FUNCTION "app"."profile_visible"(profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS 'SELECT profile_id IS NOT NULL;'
'''),
      );

      const desired = SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'app',
            name: 'profile',
            columns: [
              SqlColumnSchema(
                name: 'id',
                type: 'UUID',
                nullable: false,
                primaryKey: true,
              ),
              SqlColumnSchema(
                name: 'status',
                type: 'TEXT',
                nullable: false,
                defaultExpression: "'provisioning'",
              ),
              SqlColumnSchema(name: 'deleted_at', type: 'TIMESTAMPTZ'),
            ],
            checks: [
              SqlCheckConstraintSchema(
                name: 'profile_status_check',
                expression: "status in ('provisioning', 'ready')",
              ),
            ],
            indexes: [
              SqlIndexSchema(
                name: 'profile_active_idx',
                columns: ['status'],
                whereExpression: 'deleted_at is null',
              ),
            ],
          ),
        ],
        routines: [
          SqlRoutineSchema(
            schema: 'app',
            name: 'profile_visible',
            identityArguments: 'profile_id uuid',
            definition: '''
CREATE OR REPLACE FUNCTION app.profile_visible(profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS \$function\$
  SELECT profile_id IS NOT NULL;
\$function\$;
''',
          ),
        ],
      );

      final result = await const PostgresSchemaDiffEngine(schemas: ['app'])
          .check(
            currentExecutor: current,
            canonicalizationExecutor: scratch,
            desired: desired,
          );

      expect(result.matches, isTrue, reason: result.format());
      expect(result.diff.operations, isEmpty);
      expect(result.format(), 'Schema matches the desired state.');
      expect(result.exitCode, 0);
      expect(result.throwIfDrift, returnsNormally);
    },
  );

  test('check reports managed drift without writing a migration', () async {
    final current = PgliteDatabase.temporary().asPostgresPool();
    final scratch = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(current.close);
    addTearDown(scratch.close);

    await current.execute(sql('CREATE TABLE profile (id UUID PRIMARY KEY)'));

    final result = await const PostgresSchemaDiffEngine(schemas: ['public'])
        .check(
          currentExecutor: current,
          canonicalizationExecutor: scratch,
          desired: const SqlDatabaseSchema(
            tables: [
              SqlTableSchema(
                name: 'profile',
                columns: [
                  SqlColumnSchema(
                    name: 'id',
                    type: 'UUID',
                    nullable: false,
                    primaryKey: true,
                  ),
                  SqlColumnSchema(name: 'display_name', type: 'TEXT'),
                ],
              ),
            ],
          ),
        );

    expect(result.matches, isFalse);
    expect(result.exitCode, 1);
    expect(result.diff.operations.single, isA<AddSqlColumn>());
    expect(result.format(), contains('Schema drift detected (1 operations)'));
    expect(result.throwIfDrift, throwsA(isA<SqlSchemaDriftException>()));

    final unchanged = await const PostgresSchemaIntrospector().introspect(
      current,
    );
    expect(unchanged.tables.single.columns.map((column) => column.name), [
      'id',
    ]);
  });

  test('check rejects using the current database as scratch space', () async {
    final database = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(database.close);

    await expectLater(
      const PostgresSchemaDiffEngine(schemas: ['public']).check(
        currentExecutor: database,
        canonicalizationExecutor: database,
        desired: const SqlDatabaseSchema(tables: []),
      ),
      throwsArgumentError,
    );
  });

  test('canonicalizes unqualified routines in the public schema', () async {
    final current = PgliteDatabase.temporary().asPostgresPool();
    final scratch = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(current.close);
    addTearDown(scratch.close);

    await current.execute(
      sql('''
CREATE OR REPLACE FUNCTION public.answer()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS 'SELECT 42;'
'''),
    );

    final result = await const PostgresSchemaDiffEngine(schemas: ['public'])
        .check(
          currentExecutor: current,
          canonicalizationExecutor: scratch,
          desired: const SqlDatabaseSchema(
            tables: [],
            routines: [
              SqlRoutineSchema(
                name: 'answer',
                definition: '''
CREATE OR REPLACE FUNCTION answer()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS \$\$ SELECT 42; \$\$;
''',
              ),
            ],
          ),
        );

    expect(result.matches, isTrue, reason: result.format());
  });

  test('canonicalization rejects a non-empty scratch database', () async {
    final scratch = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(scratch.close);
    await scratch.execute(sql('CREATE TABLE occupied (id INTEGER)'));

    await expectLater(
      const PostgresSchemaCanonicalizer(schemas: ['public']).canonicalize(
        executor: scratch,
        desired: const SqlDatabaseSchema(tables: []),
      ),
      throwsStateError,
    );
  });

  test(
    'preserves requirements skipped by the scratch extension installer',
    () async {
      final current = PgliteDatabase.temporary().asPostgresPool();
      final scratch = PgliteDatabase.temporary().asPostgresPool();
      addTearDown(current.close);
      addTearDown(scratch.close);

      final result =
          await const PostgresSchemaDiffEngine(
            schemas: ['public'],
            skipExtensionInstallation: {'not_available_in_scratch'},
          ).check(
            currentExecutor: current,
            canonicalizationExecutor: scratch,
            desired: const SqlDatabaseSchema(
              tables: [],
              extensions: [
                SqlExtensionSchema(name: 'not_available_in_scratch'),
              ],
            ),
          );

      expect(result.diff.operations.single, isA<CreateSqlExtension>());
    },
  );
}
