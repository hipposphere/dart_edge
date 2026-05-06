import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:simple_test_db_models/simple_test_db_models.dart';

Future<void> seedSimpleTestDatabase(PostgresPool database) async {
  final owner = await database.typed
      .insertInto(PeopleTable.table)
      .values(
        const PeopleInsert(name: 'Ada Lovelace', email: 'ada@example.com'),
      )
      .executeReturningFirstOrNull();

  final result = await database.typed
      .insertInto(NotesTable.table)
      .values(
        NotesInsert(
          title: 'First note',
          body: 'This is the body of the first note.',
          ownerId: owner!.id,
        ),
      )
      .executeReturningFirstOrNull();

  final results = await database.typed
      .from(NotesTable.table)
      .innerJoin(
        PeopleTable.table,
        on: NotesTable.ownerId.equalsColumn(PeopleTable.id),
      )
      .select([NotesTable.title, PeopleTable.id])
      .execute();
  print('Seeded note with ID: ${result?.id}');
  print('Seeded notes in database: $results');
}
