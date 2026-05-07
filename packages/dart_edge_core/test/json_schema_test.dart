import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  test('reads decoded JSON objects as string-keyed maps', () {
    final value = readJsonObject(<Object?, Object?>{'id': '42'});

    expect(value, {'id': '42'});
    expect(readJsonObject(value), same(value));
  });

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

  test('route option labels use refs, not inline ids, as schema targets', () {
    final inline = RouteOptions(
      operationId: 'inline',
      body: RequestBody.json(schema: const JsonSchema.object(id: 'UserDto')),
      success: ResponseSpec.json(),
    ).toString();
    final referenced = RouteOptions(
      operationId: 'referenced',
      body: RequestBody.json(schema: const JsonSchema.ref('UserDto')),
      success: ResponseSpec.json(),
    ).toString();

    expect(inline, isNot(contains('<UserDto>')));
    expect(referenced, contains('application/json; charset=utf-8<UserDto>'));
  });
}
