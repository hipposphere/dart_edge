import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:simple_test_db_models/simple_test_db_models.dart';

Future<void> seedSimpleTestDatabase(PostgresPool database) async {
  final owner = await database.typed
      .insertInto(PublicPeopleTable.table)
      .values(
        const PublicPeopleInsert(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
        ),
      )
      .executeReturningFirstOrNull();

  final result = await database.typed
      .insertInto(PublicNotesTable.table)
      .values(
        PublicNotesInsert(
          title: 'First note',
          body: 'This is the body of the first note.',
          ownerId: owner!.id,
        ),
      )
      .executeReturningFirstOrNull();

  final results = await database.typed
      .from(PublicNotesTable.table)
      .innerJoin(
        PublicPeopleTable.table,
        on: PublicNotesTable.ownerId.equalsColumn(PublicPeopleTable.id),
      )
      .select([PublicNotesTable.title, PublicPeopleTable.id])
      .execute();
  print('Seeded note with ID: ${result?.id}');
  print('Seeded notes in database: $results');
}
