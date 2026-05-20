part of 'route.dart';

const createNotesRouteSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[...AppSchema.schemas, CreateNoteResponse.jsonSchema],
);

const _routeOptions = RouteOptions(
  operationId: 'createNote',
  summary: 'Create a note.',
  body: RequestBody.json(
    schema: PublicNotesInsert.schemaRef,
    decoder: _decodeCreateNoteBody,
  ),
  success: ResponseSpec.json(schema: CreateNoteResponse.schemaRef),
);

Object? _decodeCreateNoteBody(Object? value) {
  return PublicNotesInsert.fromJson(Map<String, Object?>.from(value! as Map));
}
