import 'dart:convert';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:test/test.dart';

void main() {
  test('pglite gen_random_uuid returns fresh values', () async {
    final pool = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(pool.close);

    final result = await pool.execute(
      sql('SELECT gen_random_uuid() AS first, gen_random_uuid() AS second'),
    );

    final row = result.single;
    expect(row.read<String>('first'), isNot(row.read<String>('second')));
  });

  test('binds decoded json map into pglite jsonb column twice', () async {
    final pool = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
CREATE TABLE repro_json_model (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)
'''),
    );

    final decodedJson =
        jsonDecode('{"type":"object","properties":{"name":{"type":"string"}}}')
            as Object?;

    await pool.execute(
      SqlStatement.named(
        '''
INSERT INTO repro_json_model (name, payload)
VALUES (@name, @payload) RETURNING *
''',
        {'name': 'raw-native-json-bind-repro', 'payload': decodedJson},
      ),
    );

    final second = await pool.execute(
      SqlStatement.named(
        '''
INSERT INTO repro_json_model (name, payload)
VALUES (@name, @payload) RETURNING *
''',
        {'name': 'second-json-bind-repro', 'payload': decodedJson},
      ),
    );

    expect(second.single.read<Object?>('payload'), decodedJson);

    final typedInserted = await pool.typed
        .insertInto(ReproTable.table)
        .values(
          ReproInsert(name: 'typed-json-bind-repro', payload: decodedJson),
        )
        .executeReturningFirstOrNull();

    expect(typedInserted, isNotNull);
    expect(typedInserted!.payload, decodedJson);
  });

  test('reuses prepared updates across null and typed values', () async {
    final pool = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
CREATE TABLE phone_call_repro (
  id int4 PRIMARY KEY,
  ended_at timestamptz,
  duration_seconds int4
)
'''),
    );
    await pool.execute(sql('INSERT INTO phone_call_repro (id) VALUES (1)'));

    const updateSql = '''
UPDATE phone_call_repro
SET ended_at = @ended_at::timestamptz,
    duration_seconds = @duration_seconds::int4
WHERE id = 1
''';
    await pool.execute(
      SqlStatement.named(updateSql, {
        'ended_at': null,
        'duration_seconds': null,
      }),
    );
    final endedAt = DateTime.utc(2026, 7, 20, 17, 7, 43);
    await pool.execute(
      SqlStatement.named(updateSql, {
        'ended_at': endedAt,
        'duration_seconds': 21,
      }),
    );

    final result = await pool.execute(
      sql('''
SELECT ended_at, duration_seconds
FROM phone_call_repro
WHERE id = 1
'''),
    );
    expect(result.single.read<DateTime>('ended_at'), endedAt);
    expect(result.single.read<int>('duration_seconds'), 21);
  });
}

final class ReproRow {
  const ReproRow({
    required this.id,
    required this.name,
    required this.payload,
    required this.createdAt,
  });

  factory ReproRow.fromSqlRow(SqlRow row, {String prefix = ''}) {
    return ReproRow(
      id: row.read<String>('${prefix}id'),
      name: row.read<String>('${prefix}name'),
      payload: row.read<Object?>('${prefix}payload'),
      createdAt: row.read<DateTime>('${prefix}created_at'),
    );
  }

  final String id;
  final String name;
  final Object? payload;
  final DateTime createdAt;
}

final class ReproInsert {
  const ReproInsert({required this.name, required this.payload});

  final String name;
  final Object? payload;

  Map<String, Object?> toColumns() => <String, Object?>{
    'name': name,
    'payload': payload,
  };
}

final class ReproUpdate {
  const ReproUpdate({this.name, this.payload});

  final String? name;
  final Object? payload;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (name != null) 'name': name,
    if (payload != null) 'payload': payload,
  };
}

final class ReproTable extends SqlTable<ReproRow, ReproInsert, ReproUpdate> {
  const ReproTable();

  static const table = ReproTable();

  static final id = SqlColumn<String>(
    table: table,
    name: 'id',
    databaseType: 'uuid',
  );

  static final modelName = SqlColumn<String>(
    table: table,
    name: 'name',
    databaseType: 'text',
  );

  static final payload = SqlColumn<Object?>(
    table: table,
    name: 'payload',
    databaseType: 'jsonb',
  );

  static final createdAt = SqlColumn<DateTime>(
    table: table,
    name: 'created_at',
    databaseType: 'timestamptz',
  );

  @override
  String get name => 'repro_json_model';

  @override
  String? get schema => null;

  @override
  List<SqlColumnBase> get columns => <SqlColumnBase>[
    id,
    modelName,
    payload,
    createdAt,
  ];

  @override
  ReproRow mapRow(SqlRow row, {String prefix = ''}) {
    return ReproRow.fromSqlRow(row, prefix: prefix);
  }

  @override
  Map<String, Object?> encodeInsert(ReproInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(ReproUpdate value) => value.toColumns();
}
