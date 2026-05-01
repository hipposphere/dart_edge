import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:test/test.dart';

void main() {
  test('exports schema annotations from the app-facing package', () {
    const schema = JsonSchema.object(id: 'ExportedAnnotationModel');
    const annotation = FromSchema(
      schema,
      refs: <SchemaRefModel>[SchemaRefModel(_ReferencedModel)],
    );

    expect(annotation.schema, same(schema));
    expect(annotation.refs.single.type, _ReferencedModel);
  });
}

final class _ReferencedModel {}
