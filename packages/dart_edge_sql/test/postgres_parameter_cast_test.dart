import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql/src/drivers/shared/compiled_sql_statement.dart';
import 'package:test/test.dart';

void main() {
  test('casts generated integer alias values in postgres inserts', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(PhoneCallsTable.table)
        .values(const PhoneCallInsert(durationSeconds: '35'))
        .execute();

    expect(db.statement.sql, contains('@p1::int4'));
  });

  test('casts generated special type values in postgres inserts', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(DocumentsTable.table)
        .values(
          const DocumentsInsert(
            id: '5a33f896-175c-4c21-81c7-89b73729ec73',
            status: 'draft',
            publishTime: '10:30:00',
          ),
        )
        .execute();

    expect(db.statement.sql, contains('@p1::uuid'));
    expect(db.statement.sql, contains('@p2::"public"."document_status"'));
    expect(db.statement.sql, contains('@p3::time'));
  });

  test(
    'casts generated special type values in postgres updates and filters',
    () async {
      final db = _RecordingExecutor(SqlDialect.postgres);

      await db.typed
          .updateTable(DocumentsTable.table)
          .set(const DocumentsUpdate(status: SqlValue('published')))
          .where(
            DocumentsTable.id.equals('5a33f896-175c-4c21-81c7-89b73729ec73'),
          )
          .execute();

      expect(
        db.statement.sql,
        contains('"status" = @p1::"public"."document_status"'),
      );
      expect(db.statement.sql, contains('"id" = @p2::uuid'));
    },
  );

  test('encodes generated jsonb column parameters as JSON text', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);
    final definition = <String, Object?>{
      'name': 'seeded',
      'steps': [
        {'kind': 'extract', 'required': true},
      ],
    };

    await db.typed
        .insertInto(BlueprintsTable.table)
        .values(BlueprintInsert(definition: definition))
        .execute();

    expect(db.statement.sql, contains('@p1::jsonb'));
    expect(db.statement.namedParameters, {
      'p1': '{"name":"seeded","steps":[{"kind":"extract","required":true}]}',
    });
  });

  test('encodes explicitly cast raw jsonb parameters as JSON text', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('SELECT @definition::jsonb', {
        'definition': {
          'name': 'seeded',
          'steps': [
            {'kind': 'extract', 'required': true},
          ],
        },
      }),
    );

    expect(statement.sql, r'SELECT $1::jsonb');
    expect(statement.positionalParameters, [
      '{"name":"seeded","steps":[{"kind":"extract","required":true}]}',
    ]);
  });
}

final class _RecordingExecutor implements SqlExecutor {
  _RecordingExecutor(this.dialect);

  @override
  final SqlDialect dialect;

  late SqlStatement statement;

  @override
  Future<SqlResult> execute(SqlStatement statement) async {
    this.statement = statement;
    return SqlResult();
  }
}

final class PhoneCallInsert {
  const PhoneCallInsert({required this.durationSeconds});

  final Object? durationSeconds;

  Map<String, Object?> toColumns() => <String, Object?>{
    'duration_seconds': durationSeconds,
  };
}

final class PhoneCallUpdate {
  const PhoneCallUpdate({this.durationSeconds = const SqlValue.absent()});

  final SqlValue<Object?> durationSeconds;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (durationSeconds.isPresent) 'duration_seconds': durationSeconds.value,
  };
}

final class PhoneCallsTable
    extends SqlTable<SqlRow, PhoneCallInsert, PhoneCallUpdate> {
  const PhoneCallsTable._();

  static const table = PhoneCallsTable._();

  static const durationSeconds = SqlColumn<Object?>(
    table: table,
    name: 'duration_seconds',
    databaseType: 'integer',
  );

  @override
  String get name => 'phone_calls';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    durationSeconds.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(PhoneCallInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(PhoneCallUpdate value) => value.toColumns();

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;
}

final class DocumentsInsert {
  const DocumentsInsert({
    required this.id,
    required this.status,
    required this.publishTime,
  });

  final String id;
  final String status;
  final String publishTime;

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'status': status,
    'publish_time': publishTime,
  };
}

final class DocumentsUpdate {
  const DocumentsUpdate({
    this.id = const SqlValue.absent(),
    this.status = const SqlValue.absent(),
    this.publishTime = const SqlValue.absent(),
  });

  final SqlValue<String> id;
  final SqlValue<String> status;
  final SqlValue<String> publishTime;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (status.isPresent) 'status': status.value,
    if (publishTime.isPresent) 'publish_time': publishTime.value,
  };
}

final class DocumentsTable
    extends SqlTable<SqlRow, DocumentsInsert, DocumentsUpdate> {
  const DocumentsTable._();

  static const table = DocumentsTable._();

  static const id = SqlColumn<String>(
    table: table,
    name: 'id',
    databaseType: 'uuid',
  );

  static const status = SqlColumn<String>(
    table: table,
    name: 'status',
    databaseType: 'public.document_status',
  );

  static const publishTime = SqlColumn<String>(
    table: table,
    name: 'publish_time',
    databaseType: 'time',
  );

  @override
  String get name => 'documents';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
    status.asObjectColumn,
    publishTime.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(DocumentsInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DocumentsUpdate value) => value.toColumns();

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;
}

final class BlueprintInsert {
  const BlueprintInsert({required this.definition});

  final Map<String, Object?> definition;

  Map<String, Object?> toColumns() => <String, Object?>{
    'definition': definition,
  };
}

final class BlueprintUpdate {
  const BlueprintUpdate({this.definition = const SqlValue.absent()});

  final SqlValue<Map<String, Object?>> definition;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (definition.isPresent) 'definition': definition.value,
  };
}

final class BlueprintsTable
    extends SqlTable<SqlRow, BlueprintInsert, BlueprintUpdate> {
  const BlueprintsTable._();

  static const table = BlueprintsTable._();

  static const definition = SqlColumn<Map<String, Object?>>(
    table: table,
    name: 'definition',
    databaseType: 'jsonb',
  );

  @override
  String get name => 'blueprints';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    definition.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(BlueprintInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(BlueprintUpdate value) => value.toColumns();

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;
}
