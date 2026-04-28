import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:simple_test/generated/app_schema.g.dart';

part 'schema.dart';
part 'schema.g.dart';

final class CreateNotesRoute
    extends HttpRouteDefinition<SqliteDatabase, CreateNoteResponse> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'createNote',
    summary: 'Create a note.',
    body: CreateNoteBody.requestBody,
    success: CreateNoteResponse.response(status: 201),
  );

  @override
  Future<CreateNoteResponse> handle(ctx) async {
    final body = ctx.req.body<CreateNoteBody>();
    final note = await ctx.services.builder
        .insertInto(NotesTable.table)
        .values(
          NotesInsert(
            title: body.title,
            body: body.body,
            ownerId: body.ownerId,
          ),
        )
        .executeReturningFirstTable();

    if (note == null) {
      throw StateError('Failed to create note.');
    }

    return CreateNoteResponse(
      id: note.id,
      title: note.title,
      body: note.body,
      ownerId: note.ownerId,
      createdAt: note.createdAt,
    );
  }
}
