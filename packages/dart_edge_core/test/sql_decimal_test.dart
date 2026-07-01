import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  test('encodes as JSON strings and PostgreSQL text', () {
    final decimal = SqlDecimal('123.4500');

    expect(decimal.toJson(), '123.4500');
    expect(decimal.toPostgresText(), '123.4500');
    expect(decimal.toString(), '123.4500');
  });

  test('decodes JSON strings and numbers', () {
    expect(SqlDecimal.fromJson('123.45'), SqlDecimal('123.45'));
    expect(SqlDecimal.fromJson(12), SqlDecimal('12'));
    expect(SqlDecimal.fromNum(12.5), SqlDecimal('12.5'));
  });

  test('trims valid decimal strings', () {
    expect(SqlDecimal('  -0.125e2  '), SqlDecimal('-0.125e2'));
  });

  test('rejects invalid and non-finite values', () {
    expect(() => SqlDecimal('not-a-decimal'), throwsFormatException);
    expect(() => SqlDecimal.fromNum(double.nan), throwsArgumentError);
  });
}
