import 'dart:convert';

/// Looks up a Better Auth JSON field by canonical or fallback key.
Object? authJsonLookup(Map<String, Object?> json, String key, [String? alt]) {
  if (json.containsKey(key)) {
    return json[key];
  }
  if (alt != null && json.containsKey(alt)) {
    return json[alt];
  }
  return null;
}

String authRequiredString(
  Map<String, Object?> json,
  String key, [
  String? alt,
]) {
  final value = authJsonLookup(json, key, alt);
  if (value is String) {
    return value;
  }
  throw StateError('Auth JSON field "$key" is not a string.');
}

String? authString(Map<String, Object?> json, String key, [String? alt]) {
  final value = authJsonLookup(json, key, alt);
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw StateError('Auth JSON field "$key" is not a string.');
}

bool authBool(
  Map<String, Object?> json,
  String key, {
  String? fallbackKey,
  bool defaultValue = false,
}) {
  final value = authJsonLookup(json, key, fallbackKey);
  return authBoolValue(value, defaultValue: defaultValue);
}

bool authBoolValue(Object? value, {bool defaultValue = false}) {
  return switch (value) {
    null => defaultValue,
    final bool boolValue => boolValue,
    final num number => number != 0,
    final String text => text == '1' || text.toLowerCase() == 'true',
    _ => throw StateError('Auth value "$value" is not a boolean.'),
  };
}

DateTime authRequiredDateTime(
  Map<String, Object?> json,
  String key, {
  String? fallbackKey,
}) {
  final value = authJsonLookup(json, key, fallbackKey);
  return authRequiredDateTimeValue(value);
}

DateTime authRequiredDateTimeValue(Object? value) {
  final parsed = authDateTimeValue(value);
  if (parsed == null) {
    throw StateError('Auth date-time value is missing.');
  }
  return parsed;
}

DateTime? authDateTime(
  Map<String, Object?> json,
  String key, {
  String? fallbackKey,
}) {
  return authDateTimeValue(authJsonLookup(json, key, fallbackKey));
}

DateTime? authDateTimeValue(Object? value) {
  return switch (value) {
    null => null,
    final DateTime dateTime => dateTime,
    final String text when text.isEmpty => null,
    final String text => DateTime.parse(text),
    _ => throw StateError('Auth value "$value" is not a date-time.'),
  };
}

Object? authJsonValue(Object? value) {
  if (value is String) {
    final trimmed = value.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return jsonDecode(value);
    }
  }
  return value;
}
