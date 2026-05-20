import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:simple_test_db_models/simple_test_db_models.dart';
import 'package:simple_test_server/src/routes/create_notes_route/response.dart';
import 'package:simple_test_server/src/service.dart';

part 'schema.dart';

final class CreateNotesRoute
    extends HttpRouteDefinition<SimpleTestServices, CreateNoteResponse> {
  @override
  RouteOptions get options => _routeOptions;

  @override
  Future<CreateNoteResponse> handle(ctx) async {
    final body = ctx.req.body<PublicNotesInsert>();
    final note = await ctx.services.database.typed
        .insertInto(PublicNotesTable.table)
        .values(body)
        .executeReturningFirstOrNull();

    if (note == null) {
      throw StateError('Failed to create note.');
    }

    return CreateNoteResponse(notes: note);
  }
}
