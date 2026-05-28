part of '../database.dart';

BetterAuthUser _userFromRow(SqlRow row) {
  return BetterAuthUser(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    email: row.read<String>('email'),
    emailVerified: _readBool(row['emailVerified']),
    image: row.readNullable<String>('image'),
    createdAt: _readDate(row['createdAt']),
    updatedAt: _readDate(row['updatedAt']),
    role: row.readNullable<String>('role'),
    banned: _readNullableBool(row['banned']),
    banReason: row.readNullable<String>('banReason'),
    banExpires: _readNullableDate(row['banExpires']),
    phoneNumber: row.readNullable<String>('phoneNumber'),
    phoneNumberVerified: _readNullableBool(row['phoneNumberVerified']),
  );
}

BetterAuthUser _userFromGeneratedRow(BetterAuthUserRow row) {
  return BetterAuthUser(
    id: row.id,
    name: row.name,
    email: row.email,
    emailVerified: row.emailVerified,
    image: row.image,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    role: row.role,
    banned: row.banned,
    banReason: row.banReason,
    banExpires: row.banExpires,
    phoneNumber: row.phoneNumber,
    phoneNumberVerified: row.phoneNumberVerified,
  );
}

BetterAuthUser _userFromPrefixedRow(SqlRow row) {
  return BetterAuthUser(
    id: row.read<String>('user_id'),
    name: row.read<String>('user_name'),
    email: row.read<String>('user_email'),
    emailVerified: _readBool(row['user_email_verified']),
    image: row.readNullable<String>('user_image'),
    createdAt: _readDate(row['user_created_at']),
    updatedAt: _readDate(row['user_updated_at']),
    role: row.readNullable<String>('user_role'),
    banned: _readNullableBool(row['user_banned']),
    banReason: row.readNullable<String>('user_ban_reason'),
    banExpires: _readNullableDate(row['user_ban_expires']),
    phoneNumber: row.readNullable<String>('user_phone_number'),
    phoneNumberVerified: _readNullableBool(row['user_phone_number_verified']),
  );
}

BetterAuthSession _sessionFromRow(SqlRow row) {
  return BetterAuthSession(
    id: row.read<String>('id'),
    expiresAt: _readDate(row['expiresAt']),
    token: row.read<String>('token'),
    createdAt: _readDate(row['createdAt']),
    updatedAt: _readDate(row['updatedAt']),
    ipAddress: row.readNullable<String>('ipAddress'),
    userAgent: row.readNullable<String>('userAgent'),
    userId: row.read<String>('userId'),
    impersonatedBy: row.readNullable<String>('impersonatedBy'),
  );
}

BetterAuthSession _sessionFromGeneratedRow(BetterAuthSessionRow row) {
  return BetterAuthSession(
    id: row.id,
    expiresAt: row.expiresAt,
    token: row.token,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    ipAddress: row.ipAddress,
    userAgent: row.userAgent,
    userId: row.userId,
    impersonatedBy: row.impersonatedBy,
  );
}

String _normalizeEmail(String email) => email.trim().toLowerCase();

DateTime _readDate(Object? value) => switch (value) {
  final DateTime date => date.toUtc(),
  final String text => DateTime.parse(text).toUtc(),
  final int millis => DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
  _ => throw StateError('Expected SQL date value, got $value.'),
};

DateTime? _readNullableDate(Object? value) =>
    value == null ? null : _readDate(value);

bool _readBool(Object? value) => switch (value) {
  final bool boolean => boolean,
  final int integer => integer != 0,
  _ => throw StateError('Expected SQL bool value, got $value.'),
};

bool? _readNullableBool(Object? value) =>
    value == null ? null : _readBool(value);

String _generateId() => _randomBase64Url(32);

String _generateToken(String secret) {
  final raw = _randomBase64Url(32);
  final signature = Hmac(
    sha256,
    secret.codeUnits,
  ).convert(raw.codeUnits).toString().substring(0, 16);
  return '$raw.$signature';
}

String _randomBase64Url(int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
  final random = Random.secure();
  return String.fromCharCodes(
    List<int>.generate(
      length,
      (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ),
  );
}
