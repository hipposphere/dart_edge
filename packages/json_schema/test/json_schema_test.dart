import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

void main() {
  test('serializes id as JSON Schema \$id', () {
    expect(
      const JsonSchema.object(
        id: 'UserDto',
        properties: <String, JsonSchema>{'id': JsonSchema.string()},
      ).toJson(),
      {
        r'$id': 'UserDto',
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
        },
      },
    );
  });

  test('keeps JSON Schema \$ref separate from \$id', () {
    expect(
      const JsonSchema.ref(
        '#/components/schemas/UserDto',
        id: 'UserDtoReference',
      ).toJson(),
      {r'$id': 'UserDtoReference', r'$ref': '#/components/schemas/UserDto'},
    );
  });

  test('component refs serialize as JSON Schema component refs', () {
    expect(
      const JsonSchema.componentRef('UserDto', id: 'UserDtoReference').toJson(),
      {r'$id': 'UserDtoReference', r'$ref': '#/components/schemas/UserDto'},
    );
  });

  test('serializes enum as JSON Schema enum keyword', () {
    expect(
      const JsonSchema.string(
        enumValues: <Object?>['draft', 'published', null],
      ).toJson(),
      {
        'enum': ['draft', 'published', null],
        'type': 'string',
      },
    );
  });

  test('serializes inclusive integer bounds', () {
    const schema = JsonSchema.integer(minimum: 0, maximum: 100);

    expect(schema, isA<JsonIntegerSchema>());
    expect((schema as JsonIntegerSchema).minimum, 0);
    expect(schema.maximum, 100);
    expect(schema.toJson(), {'type': 'integer', 'minimum': 0, 'maximum': 100});
  });

  test('serializes inclusive number bounds', () {
    const schema = JsonSchema.number(minimum: -1.5, maximum: 2.75);

    expect(schema, isA<JsonNumberSchema>());
    expect((schema as JsonNumberSchema).minimum, -1.5);
    expect(schema.maximum, 2.75);
    expect(schema.toJson(), {
      'type': 'number',
      'minimum': -1.5,
      'maximum': 2.75,
    });
  });

  test('keeps Dart string type metadata out of JSON Schema output', () {
    const schema = JsonStringSchema(
      format: 'uuid',
      dartType: DartSchemaType.parameter('TId'),
    );

    expect(schema.dartType, isA<DartGenericSchemaType>());
    expect(schema.toJson(), {'type': 'string', 'format': 'uuid'});
  });

  test('supports named Dart string type metadata', () {
    const schema = JsonSchema.string(
      format: 'uuid',
      dartType: DartSchemaType.named('WorkspaceId'),
    );

    expect(schema, isA<JsonStringSchema>());
    expect((schema as JsonStringSchema).dartType, isA<DartNamedSchemaType>());
    expect(schema.toJson(), {'type': 'string', 'format': 'uuid'});
  });

  test('distinguishes Dart value and model conversions', () {
    const valueSchema = JsonSchema.string(
      dartType: DartSchemaType.value('WorkspaceId'),
    );
    const modelSchema = JsonSchema.string(
      dartType: DartSchemaType.model('WorkspaceId'),
    );

    expect(
      (valueSchema as JsonStringSchema).dartType,
      isA<DartNamedSchemaType>().having(
        (type) => type.conversion,
        'conversion',
        DartSchemaConversion.value,
      ),
    );
    expect(
      (modelSchema as JsonStringSchema).dartType,
      isA<DartNamedSchemaType>().having(
        (type) => type.conversion,
        'conversion',
        DartSchemaConversion.model,
      ),
    );
    expect(valueSchema.toJson(), {'type': 'string'});
    expect(modelSchema.toJson(), {'type': 'string'});
  });

  test(
    'serializes anyOf schemas and keeps Dart type metadata out of output',
    () {
      const schema = JsonSchema.anyOf([
        JsonSchema.string(),
        JsonSchema.array(items: JsonSchema.string()),
      ], dartType: DartSchemaType.model('RoleInput'));

      expect(schema, isA<JsonAnyOfSchema>());
      expect(
        (schema as JsonAnyOfSchema).dartType,
        isA<DartNamedSchemaType>().having(
          (type) => type.conversion,
          'conversion',
          DartSchemaConversion.model,
        ),
      );
      expect(schema.toJson(), {
        'anyOf': [
          {'type': 'string'},
          {
            'type': 'array',
            'items': {'type': 'string'},
          },
        ],
      });
    },
  );

  test('reads id from raw schemas', () {
    const schema = JsonSchema.raw({r'$id': 'RawUser', 'type': 'object'});

    expect(schema.id, 'RawUser');
    expect(schema.toJson(), {r'$id': 'RawUser', 'type': 'object'});
  });

  test('reads enum from raw schemas', () {
    const schema = JsonSchema.raw({
      'type': 'string',
      'enum': ['draft', 'published'],
    });

    expect(schema.enumValues, ['draft', 'published']);
    expect(schema.toJson(), {
      'type': 'string',
      'enum': ['draft', 'published'],
    });
  });
}
