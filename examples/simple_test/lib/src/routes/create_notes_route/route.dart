import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:simple_test/generated/app_schema.g.dart';
import 'package:simple_test/src/service.dart';

part 'schema.dart';
part 'route.g.dart';

final class CreateNotesRoute
    extends HttpRouteDefinition<SimpleTestServices, CreateNoteResponse> {
  @override
  RouteOptions get options => _routeOptions;

  @override
  Future<CreateNoteResponse> handle(ctx) async {
    final body = ctx.req.body<CreateNoteBody>();
    final note = await ctx.services.database.typed
        .insertInto(NotesTable.table)
        .values(
          NotesInsert(
            title: body.title,
            body: body.body,
            ownerId: body.ownerId,
          ),
        )
        .executeReturningFirstOrNull();

    if (note == null) {
      throw StateError('Failed to create note.');
    }

    return CreateNoteResponse(notes: note);
  }
}
