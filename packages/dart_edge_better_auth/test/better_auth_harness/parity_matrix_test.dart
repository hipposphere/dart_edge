import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('tracks Better Auth upstream parity explicitly', () {
    final file = File('test/better_auth_harness/parity_matrix.json');
    final matrix = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

    expect((matrix['upstream']! as Map<String, Object?>)['version'], '1.6.11');
    expect(
      matrix['enabled'],
      isA<List<Object?>>().having(
        (enabled) => enabled.length,
        'enabled suite count',
        greaterThanOrEqualTo(4),
      ),
    );
    expect(
      matrix['pending'],
      isA<List<Object?>>().having(
        (pending) => pending.length,
        'pending suite count',
        greaterThanOrEqualTo(1),
      ),
    );
  });
}
