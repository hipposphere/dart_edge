import 'package:json_schema/json_schema.dart';
import 'package:json_schema_gen/json_schema_gen.dart';
import 'package:test/test.dart';

void main() {
  test('adapters can map a schema without Dart Edge dependencies', () {
    const adapter = _UuidAdapter();

    expect(
      adapter.map(const JsonSchema.string(format: 'uuid')),
      isA<SchemaDartType>()
          .having((mapping) => mapping.name, 'name', 'Uuid')
          .having(
            (mapping) => mapping.conversion,
            'conversion',
            DartSchemaConversion.value,
          ),
    );
  });
}

final class _UuidAdapter extends SchemaTypeAdapter {
  const _UuidAdapter();

  @override
  SchemaDartType? map(JsonSchema schema) => switch (schema) {
    JsonStringSchema(format: 'uuid') => const SchemaDartType(
      'Uuid',
      conversion: DartSchemaConversion.value,
    ),
    _ => null,
  };
}
