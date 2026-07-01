import 'dart:convert';

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

  test('casts generated nullable boolean values in postgres inserts', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(AgentsTable.table)
        .values(const AgentInsert(includeThinkingSummaries: null))
        .execute();

    expect(db.statement.sql, contains('@p1::bool'));
    expect(db.statement.namedParameters, {'p1': null});
  });

  test('casts generated nullable scalar values in postgres inserts', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(ScalarSamplesTable.table)
        .values(const ScalarSampleInsert())
        .execute();

    expect(db.statement.sql, contains('@p1::float4'));
    expect(db.statement.sql, contains('@p2::float8'));
    expect(db.statement.sql, contains('@p3::numeric'));
    expect(db.statement.sql, contains('@p4::money'));
    expect(db.statement.sql, contains('@p5::bytea'));
    expect(db.statement.namedParameters, {
      'p1': null,
      'p2': null,
      'p3': null,
      'p4': null,
      'p5': null,
    });
  });

  test('unwraps present sql values in generated postgres inserts', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(PhoneCallsTable.table)
        .values(const PhoneCallInsert(durationSeconds: SqlValue(35)))
        .execute();

    expect(db.statement.namedParameters, {'p1': 35});
  });

  test('unwraps present sql values in compiled statements', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('SELECT @value', {
        'value': const SqlValue('responses'),
      }),
    );

    expect(statement.positionalParameters.single, 'responses');
  });

  test('unwraps present sql values in positional statements', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.positional('SELECT \$1', [const SqlValue('responses')]),
    );

    expect(statement.positionalParameters.single, 'responses');
  });

  test('rejects absent sql values in compiled statements', () {
    expect(
      () => compileSqlStatement(
        SqlDialect.postgres,
        SqlStatement.named('SELECT @value', {
          'value': const SqlValue<Object?>.absent(),
        }),
      ),
      throwsArgumentError,
    );
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

  test('encodes jsonb map parameters with loose runtime types', () {
    final value = jsonDecode(
      '{"type":"object","properties":{"name":{"type":"string"}}}',
    );

    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('insert into t (payload) values (@payload::jsonb)', {
        'payload': value,
      }),
    );

    expect(statement.positionalParameters.single, isA<String>());
    expect(
      statement.positionalParameters.single,
      '{"type":"object","properties":{"name":{"type":"string"}}}',
    );
  });

  test('keeps jsonb string parameters as provided', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('SELECT @definition::jsonb', {
        'definition': '{"name":"seeded"}',
      }),
    );

    expect(statement.positionalParameters.single, '{"name":"seeded"}');
  });

  test('encodes explicitly cast text array parameters as array literals', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('SELECT @roles::text[]', {
        'roles': ['admin', 'member'],
      }),
    );

    expect(statement.sql, r'SELECT $1::text[]');
    expect(statement.positionalParameters, ['{"admin","member"}']);
  });

  test('encodes explicitly cast vector parameters as pgvector text', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('SELECT @embedding::vector(3)', {
        'embedding': SqlVector([1, 2, 3]),
      }),
    );

    expect(statement.sql, r'SELECT $1::vector(3)');
    expect(statement.positionalParameters, ['[1.0,2.0,3.0]']);
  });

  test('encodes explicitly cast decimal parameters as decimal text', () {
    final statement = compileSqlStatement(
      SqlDialect.postgres,
      SqlStatement.named('SELECT @amount::numeric(12,2)', {
        'amount': SqlDecimal('123.45'),
      }),
    );

    expect(statement.sql, r'SELECT $1::numeric(12,2)');
    expect(statement.positionalParameters, ['123.45']);
  });

  test('casts generated decimal column parameters', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(ScalarSamplesTable.table)
        .values(
          ScalarSampleInsert(
            numericValue: SqlDecimal('123.45'),
            moneyValue: SqlDecimal('9.99'),
          ),
        )
        .execute();

    expect(db.statement.sql, contains('@p3::numeric'));
    expect(db.statement.sql, contains('@p4::money'));
    expect(db.statement.namedParameters, {
      'p1': null,
      'p2': null,
      'p3': '123.45',
      'p4': '9.99',
      'p5': null,
    });
  });

  test('casts generated vector column parameters', () async {
    final db = _RecordingExecutor(SqlDialect.postgres);

    await db.typed
        .insertInto(EmbeddingsTable.table)
        .values(EmbeddingInsert(embedding: SqlVector([1, 2, 3])))
        .execute();

    expect(db.statement.sql, contains('@p1::vector(3)'));
    expect(db.statement.namedParameters, {'p1': '[1.0,2.0,3.0]'});
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

final class AgentInsert {
  const AgentInsert({required this.includeThinkingSummaries});

  final bool? includeThinkingSummaries;

  Map<String, Object?> toColumns() => <String, Object?>{
    'include_thinking_summaries': includeThinkingSummaries,
  };
}

final class AgentUpdate {
  const AgentUpdate({this.includeThinkingSummaries = const SqlValue.absent()});

  final SqlValue<bool?> includeThinkingSummaries;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (includeThinkingSummaries.isPresent)
      'include_thinking_summaries': includeThinkingSummaries.value,
  };
}

final class AgentsTable extends SqlTable<SqlRow, AgentInsert, AgentUpdate> {
  const AgentsTable._();

  static const table = AgentsTable._();

  static const includeThinkingSummaries = SqlColumn<bool>(
    table: table,
    name: 'include_thinking_summaries',
    nullable: true,
    databaseType: 'bool',
  );

  @override
  String get name => 'agent';

  @override
  String? get schema => 'agento';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    includeThinkingSummaries.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(AgentInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(AgentUpdate value) => value.toColumns();

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;
}

final class ScalarSampleInsert {
  const ScalarSampleInsert({
    this.realValue,
    this.doubleValue,
    this.numericValue,
    this.moneyValue,
    this.bytesValue,
  });

  final double? realValue;
  final double? doubleValue;
  final SqlDecimal? numericValue;
  final SqlDecimal? moneyValue;
  final List<int>? bytesValue;

  Map<String, Object?> toColumns() => <String, Object?>{
    'real_value': realValue,
    'double_value': doubleValue,
    'numeric_value': numericValue,
    'money_value': moneyValue,
    'bytes_value': bytesValue,
  };
}

final class ScalarSampleUpdate {
  const ScalarSampleUpdate();

  Map<String, Object?> toColumns() => const <String, Object?>{};
}

final class ScalarSamplesTable
    extends SqlTable<SqlRow, ScalarSampleInsert, ScalarSampleUpdate> {
  const ScalarSamplesTable._();

  static const table = ScalarSamplesTable._();

  static const realValue = SqlColumn<double>(
    table: table,
    name: 'real_value',
    nullable: true,
    databaseType: 'float4',
  );

  static const doubleValue = SqlColumn<double>(
    table: table,
    name: 'double_value',
    nullable: true,
    databaseType: 'float8',
  );

  static const numericValue = SqlColumn<SqlDecimal>(
    table: table,
    name: 'numeric_value',
    nullable: true,
    databaseType: 'numeric',
  );

  static const moneyValue = SqlColumn<SqlDecimal>(
    table: table,
    name: 'money_value',
    nullable: true,
    databaseType: 'money',
  );

  static const bytesValue = SqlColumn<List<int>>(
    table: table,
    name: 'bytes_value',
    nullable: true,
    databaseType: 'bytea',
  );

  @override
  String get name => 'scalar_samples';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    realValue.asObjectColumn,
    doubleValue.asObjectColumn,
    numericValue.asObjectColumn,
    moneyValue.asObjectColumn,
    bytesValue.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(ScalarSampleInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(ScalarSampleUpdate value) =>
      value.toColumns();

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;
}

final class EmbeddingInsert {
  const EmbeddingInsert({required this.embedding});

  final SqlVector embedding;

  Map<String, Object?> toColumns() => <String, Object?>{'embedding': embedding};
}

final class EmbeddingUpdate {
  const EmbeddingUpdate({this.embedding = const SqlValue.absent()});

  final SqlValue<SqlVector> embedding;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (embedding.isPresent) 'embedding': embedding.value,
  };
}

final class EmbeddingsTable
    extends SqlTable<SqlRow, EmbeddingInsert, EmbeddingUpdate> {
  const EmbeddingsTable._();

  static const table = EmbeddingsTable._();

  static final embedding = SqlColumn<SqlVector>(
    table: table,
    name: 'embedding',
    databaseType: 'vector(3)',
  );

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    embedding.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(EmbeddingInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(EmbeddingUpdate value) => value.toColumns();

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;

  @override
  String get name => 'embeddings';

  @override
  String? get schema => null;
}
