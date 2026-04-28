part of 'route.dart';

const createNoteResponseSchema = JsonSchema.object(
  id: 'CreateNoteResponse',
  properties: <String, JsonSchema>{'notes': NotesRow.schemaRef},
  required: <String>['notes'],
  additionalProperties: false,
);

const createNotesRouteSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[...AppSchema.schemas, createNoteResponseSchema],
);

@FromSchema(NotesInsert.schemaRef, registry: createNotesRouteSchemas)
typedef CreateNoteBody = _$CreateNoteBody;

@FromSchema(
  createNoteResponseSchema,
  registry: createNotesRouteSchemas,
  refs: [SchemaRefModel(NotesRow)],
)
typedef CreateNoteResponse = _$CreateNoteResponse;
