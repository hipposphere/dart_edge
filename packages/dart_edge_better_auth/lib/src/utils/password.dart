import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

final _secureRandom = Random.secure();

Future<String> betterAuthHashPassword(String password) async {
  final salt = Uint8List.fromList(
    List<int>.generate(16, (_) => _secureRandom.nextInt(256)),
  );
  final key = _deriveBetterAuthPasswordKey(password, _hex(salt));
  return '${_hex(salt)}:${_hex(key)}';
}

Future<bool> betterAuthVerifyPassword({
  required String password,
  required String hash,
}) async {
  final parts = hash.split(':');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
    throw const FormatException('Invalid password hash.');
  }
  final key = _deriveBetterAuthPasswordKey(password, parts[0]);
  return _constantTimeEquals(_hex(key), parts[1].toLowerCase());
}

Uint8List _deriveBetterAuthPasswordKey(String password, String salt) {
  final derivator = KeyDerivator('scrypt')
    ..init(
      ScryptParameters(16384, 16, 1, 64, Uint8List.fromList(utf8.encode(salt))),
    );
  return derivator.process(Uint8List.fromList(utf8.encode(password)));
}

String _hex(List<int> bytes) {
  const digits = '0123456789abcdef';
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer
      ..write(digits[(byte >> 4) & 0x0f])
      ..write(digits[byte & 0x0f]);
  }
  return buffer.toString();
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i += 1) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
