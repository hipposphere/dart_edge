import 'package:dart_edge_core/dart_edge_core.dart';
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

  test('reads id from raw schemas', () {
    const schema = JsonSchema.raw({r'$id': 'RawUser', 'type': 'object'});

    expect(schema.id, 'RawUser');
    expect(schema.toJson(), {r'$id': 'RawUser', 'type': 'object'});
  });
}
