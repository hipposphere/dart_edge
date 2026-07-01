import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses pgvector text values', () {
    expect(SqlVector.parse('[1, 2.5, -3]').values, [1.0, 2.5, -3.0]);
  });

  test('encodes as JSON arrays and pgvector text', () {
    final vector = SqlVector([1, 2.5, -3]);

    expect(vector.toJson(), [1.0, 2.5, -3.0]);
    expect(vector.toPostgresText(), '[1.0,2.5,-3.0]');
    expect(vector.toString(), '[1.0,2.5,-3.0]');
  });

  test('decodes JSON arrays and pgvector strings', () {
    expect(SqlVector.fromJson([1, 2.5]), SqlVector([1, 2.5]));
    expect(SqlVector.fromJson('[1,2.5]'), SqlVector([1, 2.5]));
  });

  test('rejects non-finite values', () {
    expect(() => SqlVector([double.nan]), throwsArgumentError);
  });
}
