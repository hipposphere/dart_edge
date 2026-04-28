part of 'route.dart';

const createNoteResponseSchema = JsonSchema.object(
  id: 'CreateNoteResponse',
  properties: <String, JsonSchema>{
    'id': JsonSchema.integer(nullable: true),
    'title': JsonSchema.string(),
    'body': JsonSchema.string(),
    'owner_id': JsonSchema.integer(),
    'created_at': JsonSchema.string(),
  },
  required: <String>['id', 'title', 'body', 'owner_id', 'created_at'],
  additionalProperties: false,
);

const createNotesRouteSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[...AppSchema.schemas, createNoteResponseSchema],
);

@FromSchema(NotesInsert.schemaRef, registry: createNotesRouteSchemas)
typedef CreateNoteBody = _$CreateNoteBody;

@FromSchema(createNoteResponseSchema, registry: createNotesRouteSchemas)
typedef CreateNoteResponse = _$CreateNoteResponse;
