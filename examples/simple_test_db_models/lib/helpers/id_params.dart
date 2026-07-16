import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';

part 'id_params.g.dart';

const idParamsJsonSchema = JsonSchema.object(
  id: 'IdParams',
  title: 'IdParams',
  properties: {
    'id': JsonSchema.string(dartType: DartSchemaType.parameter('T')),
  },
  required: ['id'],
  additionalProperties: false,
);

@FromSchema(idParamsJsonSchema)
typedef IdParams<T extends String> = _$IdParams<T>;
