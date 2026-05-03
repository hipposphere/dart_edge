import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql/src/drivers/shared/compiled_sql_statement.dart';
import 'package:test/test.dart';

void main() {
  late SqliteDatabase pool;

  setUp(() {
    pool = SqliteDatabase.inMemory();
  });

  tearDown(() => pool.close());

  test('selects typed rows, raw joined rows, and typed joined rows', () async {
    await _createSchema(pool);
    await _seedData(pool);

    final users = await pool.typed
        .from(UsersTable.table)
        .selectAll()
        .orderBy(UsersTable.id)
        .execute();

    expect(users, hasLength(2));
    expect(users.first.email, 'ada@example.com');

    final rawAllRows = await pool.typed
        .from(UsersTable.table)
        .innerJoin(
          PostsTable.table,
          on: UsersTable.id.equalsColumn(PostsTable.userId),
        )
        .selectAllRaw()
        .orderBy(PostsTable.id)
        .execute();

    expect(rawAllRows, hasLength(3));
    expect(rawAllRows.first.read<String>('users__email'), 'ada@example.com');
    expect(rawAllRows.first.read<String>('posts__title'), 'Analytical Engine');

    final rawRows = await pool.typed
        .from(UsersTable.table)
        .innerJoin(
          PostsTable.table,
          on: UsersTable.id.equalsColumn(PostsTable.userId),
        )
        .select([UsersTable.email, PostsTable.title])
        .orderBy(PostsTable.id)
        .execute();

    expect(rawRows, hasLength(3));
    expect(rawRows.first.read<String>('users__email'), 'ada@example.com');
    expect(rawRows.first.read<String>('posts__title'), 'Analytical Engine');

    final joinedRows = await pool.typed
        .from(UsersTable.table)
        .innerJoin(
          PostsTable.table,
          on: UsersTable.id.equalsColumn(PostsTable.userId),
        )
        .selectTables2(UsersTable.table, PostsTable.table)
        .orderBy(PostsTable.id)
        .execute();

    expect(joinedRows, hasLength(3));
    expect(joinedRows.first.left.email, 'ada@example.com');
    expect(joinedRows.first.right.title, 'Analytical Engine');
  });

  test(
    'inserts and updates with generated-style insert and update classes',
    () async {
      await _createSchema(pool);

      final inserted = await pool.typed
          .insertInto(UsersTable.table)
          .values(
            const UsersInsert(
              email: 'grace@example.com',
              displayName: 'Grace Hopper',
            ),
          )
          .executeReturningFirstOrNull();

      expect(inserted, isNotNull);
      expect(inserted!.id, greaterThan(0));
      expect(inserted.displayName, 'Grace Hopper');

      await pool.typed
          .updateTable(UsersTable.table)
          .set(const UsersUpdate(displayName: SqlValue<String?>(null)))
          .where(UsersTable.id.equals(inserted.id))
          .execute();

      final updated = await pool.typed
          .from(UsersTable.table)
          .selectAll()
          .where(UsersTable.id.equals(inserted.id))
          .executeSingle();

      expect(updated.displayName, isNull);
    },
  );

  test('deletes rows through typed deleteFrom', () async {
    await _createSchema(pool);
    await _seedData(pool);

    await pool.typed
        .deleteFrom(UsersTable.table)
        .where(UsersTable.email.equals('alan@example.com'))
        .execute();

    final remaining = await pool.typed
        .from(UsersTable.table)
        .selectAll()
        .orderBy(UsersTable.id)
        .execute();

    expect(remaining, hasLength(1));
    expect(remaining.single.email, 'ada@example.com');
  });

  test('checks existence through executeExists', () async {
    await _createSchema(pool);
    await _seedData(pool);

    final hasAda = await pool.typed
        .from(UsersTable.table)
        .where(UsersTable.email.equals('ada@example.com'))
        .executeExists();
    final hasGrace = await pool.typed
        .from(UsersTable.table)
        .where(UsersTable.email.equals('grace@example.com'))
        .executeExists();

    expect(hasAda, isTrue);
    expect(hasGrace, isFalse);

    final userCount = await pool.typed.from(UsersTable.table).executeCount();
    final adaCount = await pool.typed
        .from(UsersTable.table)
        .where(UsersTable.email.equals('ada@example.com'))
        .executeCount();

    expect(userCount, 2);
    expect(adaCount, 1);
  });

  test('chains where clauses with AND', () async {
    await _createSchema(pool);
    await _seedData(pool);

    final statement = pool.typed
        .from(UsersTable.table)
        .where(UsersTable.email.equals('ada@example.com'))
        .where(UsersTable.id.greaterThan(0))
        .selectAll()
        .toStatement();
    final rows = await pool.typed
        .from(UsersTable.table)
        .where(UsersTable.email.equals('ada@example.com'))
        .where(UsersTable.id.greaterThan(0))
        .selectAll()
        .execute();

    expect(statement.sql, contains(' AND '));
    expect(rows, hasLength(1));
    expect(rows.single.email, 'ada@example.com');
  });

  test('combines predicate lists with AND and OR', () async {
    await _createSchema(pool);
    await _seedData(pool);

    final activeAda = await pool.typed
        .from(UsersTable.table)
        .where(
          .and([
            UsersTable.email.equals('ada@example.com'),
            UsersTable.id.greaterThan(0),
          ]),
        )
        .selectAll()
        .executeSingle();
    final adaOrAlan = await pool.typed
        .from(UsersTable.table)
        .where(
          .or([
            UsersTable.email.equals('ada@example.com'),
            UsersTable.email.equals('alan@example.com'),
          ]),
        )
        .orderBy(UsersTable.email)
        .selectAll()
        .execute();

    expect(activeAda.email, 'ada@example.com');
    expect(adaOrAlan.map((user) => user.email), [
      'ada@example.com',
      'alan@example.com',
    ]);
  });

  test('supports raw SQL strings, expressions, and predicates', () async {
    await _createSchema(pool);
    await _seedData(pool);

    final raw = pool.raw;
    final rows = await raw
        .from('users', alias: 'u')
        .leftJoin(
          'posts',
          alias: 'p',
          on: raw.eqRef('"p"."user_id"', '"u"."id"'),
        )
        .select([
          '"u"."id" AS "user_id"',
          '"u"."email" AS "email"',
          'lower("u"."email") AS "lower_email"',
        ])
        .distinct()
        .where(raw.eq('"u"."email"', 'ada@example.com'))
        .where(raw.gt('"u"."id"', 0))
        .orderBy('"u"."id"')
        .execute();

    expect(rows, hasLength(1));
    expect(rows.single.read<int>('user_id'), greaterThan(0));
    expect(rows.single.read<String>('email'), 'ada@example.com');
    expect(rows.single.read<String>('lower_email'), 'ada@example.com');

    final grouped = await raw
        .from('users', alias: 'u')
        .leftJoin(
          'posts',
          alias: 'p',
          on: raw.eqRef('"p"."user_id"', '"u"."id"'),
        )
        .select(['"u"."email" AS "email"', 'COUNT("p"."id") AS "post_count"'])
        .groupBy('"u"."email"')
        .having('COUNT("p"."id") > @minimum', parameters: {'minimum': 1})
        .orderBy('"u"."email"')
        .execute();

    expect(grouped, hasLength(1));
    expect(grouped.single.read<String>('email'), 'ada@example.com');
    expect(grouped.single.read<int>('post_count'), 2);

    final rawOrRows = await raw
        .from('users', alias: 'u')
        .select(['"u"."email" AS "email"'])
        .where(
          raw.or([
            raw.eq('"u"."email"', 'ada@example.com'),
            raw.eq('"u"."email"', 'alan@example.com'),
          ]),
        )
        .orderBy('"u"."email"')
        .execute();

    expect(rawOrRows.map((row) => row.read<String>('email')), [
      'ada@example.com',
      'alan@example.com',
    ]);

    final statement = raw
        .from('users', alias: 'u')
        .select(['"u"."id" AS "user_id"'])
        .where(.raw('"u"."id" > @id', parameters: {'id': 0}))
        .toStatement();

    expect(statement.sql, contains('FROM users AS "u"'));
    expect(statement.namedParameters, {'p1': 0});

    final escapedStatement = raw
        .from('users', alias: 'u')
        .select(['"u"."id" AS "user_id"'])
        .where(
          .raw(
            '\'_literal_@id\' = \'_literal_@id\' '
            '/* @ignored */ AND "u"."id" > @id',
            parameters: {'id': 0, 'ignored': 1},
          ),
        )
        .toStatement();

    expect(escapedStatement.sql, contains("'_literal_@id'"));
    expect(escapedStatement.sql, contains('/* @ignored */'));
    expect(escapedStatement.namedParameters, {'p1': 0});
  });

  test('formats SqlValue for debugging', () {
    expect(const SqlValue<int>.absent().toString(), 'SqlValue.absent()');
    expect(const SqlValue<int>(42).toString(), 'SqlValue(42)');
  });

  test(
    'compiles named parameters without treating PostgreSQL casts as names',
    () {
      final statement = compileSqlStatement(
        SqlDialect.postgres,
        SqlStatement.named(
          "SELECT @value::text AS value, ARRAY[]::text[] AS empty_text",
          {'value': 1},
        ),
      );

      expect(
        statement.sql,
        r'SELECT $1::text AS value, ARRAY[]::text[] AS empty_text',
      );
      expect(statement.positionalParameters, [1]);
    },
  );
}

Future<void> _createSchema(SqlExecutor db) async {
  await db.execute(
    sql('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        display_name TEXT
      )
      '''),
  );

  await db.execute(
    sql('''
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL
      )
      '''),
  );
}

Future<void> _seedData(SqlExecutor db) async {
  final ada = await db.typed
      .insertInto(UsersTable.table)
      .values(
        const UsersInsert(
          email: 'ada@example.com',
          displayName: 'Ada Lovelace',
        ),
      )
      .executeReturningFirstOrNull();
  final alan = await db.typed
      .insertInto(UsersTable.table)
      .values(
        const UsersInsert(
          email: 'alan@example.com',
          displayName: 'Alan Turing',
        ),
      )
      .executeReturningFirstOrNull();

  await db.typed.insertInto(PostsTable.table).valuesAll([
    PostsInsert(userId: ada!.id, title: 'Analytical Engine'),
    PostsInsert(userId: ada.id, title: 'Notes'),
    PostsInsert(userId: alan!.id, title: 'Computing Machinery'),
  ]).execute();
}

final class UsersRow {
  const UsersRow({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory UsersRow.fromSqlRow(SqlRow row, {String prefix = ''}) => UsersRow(
    id: row.read<int>('${prefix}id'),
    email: row.read<String>('${prefix}email'),
    displayName: row.readNullable<String>('${prefix}display_name'),
  );

  final int id;
  final String email;
  final String? displayName;

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'email': email,
    'display_name': displayName,
  };
}

final class UsersInsert {
  const UsersInsert({
    this.id = const SqlValue.absent(),
    required this.email,
    required this.displayName,
  });

  final SqlValue<int> id;
  final String email;
  final String? displayName;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'email': email,
    'display_name': displayName,
  };
}

final class UsersUpdate {
  const UsersUpdate({
    this.id = const SqlValue.absent(),
    this.email = const SqlValue.absent(),
    this.displayName = const SqlValue.absent(),
  });

  final SqlValue<int> id;
  final SqlValue<String> email;
  final SqlValue<String?> displayName;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (email.isPresent) 'email': email.value,
    if (displayName.isPresent) 'display_name': displayName.value,
  };
}

final class UsersTable extends SqlTable<UsersRow, UsersInsert, UsersUpdate> {
  const UsersTable._();

  static const table = UsersTable._();

  static final id = SqlColumn<int>(table: table, name: 'id');
  static final email = SqlColumn<String>(table: table, name: 'email');
  static final displayName = SqlColumn<String?>(
    table: table,
    name: 'display_name',
    nullable: true,
  );

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
    email.asObjectColumn,
    displayName.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(UsersInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(UsersUpdate value) => value.toColumns();

  @override
  UsersRow mapRow(SqlRow row, {String prefix = ''}) =>
      UsersRow.fromSqlRow(row, prefix: prefix);

  @override
  String get name => 'users';

  @override
  String? get schema => null;
}

final class PostsRow {
  const PostsRow({required this.id, required this.userId, required this.title});

  factory PostsRow.fromSqlRow(SqlRow row, {String prefix = ''}) => PostsRow(
    id: row.read<int>('${prefix}id'),
    userId: row.read<int>('${prefix}user_id'),
    title: row.read<String>('${prefix}title'),
  );

  final int id;
  final int userId;
  final String title;

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'title': title,
  };
}

final class PostsInsert {
  const PostsInsert({
    this.id = const SqlValue.absent(),
    required this.userId,
    required this.title,
  });

  final SqlValue<int> id;
  final int userId;
  final String title;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'user_id': userId,
    'title': title,
  };
}

final class PostsUpdate {
  const PostsUpdate({
    this.id = const SqlValue.absent(),
    this.userId = const SqlValue.absent(),
    this.title = const SqlValue.absent(),
  });

  final SqlValue<int> id;
  final SqlValue<int> userId;
  final SqlValue<String> title;

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (userId.isPresent) 'user_id': userId.value,
    if (title.isPresent) 'title': title.value,
  };
}

final class PostsTable extends SqlTable<PostsRow, PostsInsert, PostsUpdate> {
  const PostsTable._();

  static const table = PostsTable._();

  static final id = SqlColumn<int>(table: table, name: 'id');
  static final userId = SqlColumn<int>(table: table, name: 'user_id');
  static final title = SqlColumn<String>(table: table, name: 'title');

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
    userId.asObjectColumn,
    title.asObjectColumn,
  ];

  @override
  Map<String, Object?> encodeInsert(PostsInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(PostsUpdate value) => value.toColumns();

  @override
  PostsRow mapRow(SqlRow row, {String prefix = ''}) =>
      PostsRow.fromSqlRow(row, prefix: prefix);

  @override
  String get name => 'posts';

  @override
  String? get schema => null;
}
