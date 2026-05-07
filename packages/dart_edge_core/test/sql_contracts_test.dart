import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  test('SqlRow reads typed values', () {
    final row = SqlRow({'id': 1, 'name': 'Ada', 'nickname': null});

    expect(row.read<int>('id'), 1);
    expect(row.readNullable<String>('nickname'), isNull);
    expect(row.asMap(), {'id': 1, 'name': 'Ada', 'nickname': null});
  });

  test('SqlValue distinguishes absent from present null', () {
    expect(const SqlValue<int>.absent().isPresent, isFalse);
    expect(const SqlValue<int?>(null).isPresent, isTrue);
  });

  test('SqlTable and SqlColumn describe table shape', () {
    expect(_UsersTable.table.qualifiedName, 'public.users');
    expect(_UsersTable.id.qualifiedName, 'public.users.id');
    expect(_UsersTable.id.asObjectColumn.name, 'id');
    expect(_UsersTable.id.databaseType, 'uuid');
  });
}

final class _UsersTable
    extends SqlTable<SqlRow, Map<String, Object?>, Map<String, Object?>> {
  const _UsersTable._();

  static const table = _UsersTable._();
  static const id = SqlColumn<int>(
    table: table,
    name: 'id',
    databaseType: 'uuid',
  );

  @override
  String get name => 'users';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
  ];

  @override
  SqlRow mapRow(SqlRow row, {String prefix = ''}) => row;

  @override
  Map<String, Object?> encodeInsert(Map<String, Object?> value) => value;

  @override
  Map<String, Object?> encodeUpdate(Map<String, Object?> value) => value;
}
