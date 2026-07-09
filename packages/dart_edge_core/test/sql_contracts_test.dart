import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  test('SqlRow reads typed values', () {
    final row = SqlRow({'id': 1, 'name': 'Ada', 'nickname': null});

    expect(row.read<int>('id'), 1);
    expect(row.readNullable<String>('nickname'), isNull);
    expect(row.asMap(), {'id': 1, 'name': 'Ada', 'nickname': null});
  });

  test('SqlRow reads values by typed column projection alias', () {
    final row = SqlRow({'public_users__id': 1, 'public_users__nickname': null});

    expect(row.containsColumn(_UsersTable.id), isTrue);
    expect(row.readColumn(_UsersTable.id), 1);
    expect(row.readNullableColumn(_UsersTable.nickname), isNull);
    expect(() => row.readColumn(_UsersTable.email), throwsStateError);
  });

  test('SqlValue distinguishes absent from present null', () {
    expect(const SqlValue<int>.absent().isPresent, isFalse);
    expect(const SqlValue<int?>(null).isPresent, isTrue);
  });

  test('SqlTable and SqlColumn describe table shape', () {
    expect(_UsersTable.table.qualifiedName, 'public.users');
    expect(_UsersTable.id.qualifiedName, 'public.users.id');
    expect(_UsersTable.id.name, 'id');
    expect(_UsersTable.id.databaseType, 'uuid');

    const tenantUsers = _UsersTable.withSchema('tenant_auth');
    final tenantId = tenantUsers.column<int>('id', databaseType: 'uuid');
    expect(tenantUsers.qualifiedName, 'tenant_auth.users');
    expect(tenantId.qualifiedName, 'tenant_auth.users.id');
  });

  test('SqlKeyManifestEntry describes generated SQL key value types', () {
    const entry = SqlKeyManifestEntry(
      dartType: 'PublicUserId',
      baseDartType: 'int',
      schema: 'public',
      table: 'users',
      column: 'id',
    );

    expect(entry.dartType, 'PublicUserId');
    expect(entry.baseDartType, 'int');
    expect(entry.schema, 'public');
    expect(entry.table, 'users');
    expect(entry.column, 'id');
    expect(entry.nullable, isFalse);
    expect(entry.external, isFalse);
  });
}

final class _UsersTable
    extends SqlTable<SqlRow, Map<String, Object?>, Map<String, Object?>> {
  const _UsersTable._() : schema = 'public';
  const _UsersTable.withSchema(this.schema);

  static const table = _UsersTable._();
  static const id = SqlColumn<int>(
    table: table,
    name: 'id',
    databaseType: 'uuid',
  );
  static const email = SqlColumn<String>(table: table, name: 'email');
  static const nickname = SqlColumn<String?>(
    table: table,
    name: 'nickname',
    nullable: true,
  );

  @override
  String get name => 'users';

  @override
  final String? schema;

  @override
  List<SqlColumnBase> get columns => <SqlColumnBase>[id, email, nickname];

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;

  @override
  Map<String, Object?> encodeInsert(Map<String, Object?> value) => value;

  @override
  Map<String, Object?> encodeUpdate(Map<String, Object?> value) => value;
}
