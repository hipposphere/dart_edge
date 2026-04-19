import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'generated_bindings.dart';

typedef NativeStringPair = ({String key, String value});

Uint8List? maybeCopyNativeBytes(NativeBytes value) {
  if (value.len == 0 || value.ptr == nullptr) {
    return null;
  }

  return Uint8List.fromList(value.ptr.asTypedList(value.len));
}

Uint8List copyNativeOwnedBytes(NativeOwnedBytes value) {
  if (value.len == 0 || value.ptr == nullptr) {
    return Uint8List(0);
  }

  return Uint8List.fromList(value.ptr.asTypedList(value.len));
}

String decodeNativeUtf8(NativeBytes value, {bool allowMalformed = true}) {
  final bytes = maybeCopyNativeBytes(value);
  if (bytes == null || bytes.isEmpty) {
    return '';
  }

  return utf8.decode(bytes, allowMalformed: allowMalformed);
}

List<NativeStringPair> copyNativePairs(
  Pointer<NativePair> pairs,
  int count, {
  bool allowMalformed = true,
}) {
  if (count == 0 || pairs == nullptr) {
    return const <NativeStringPair>[];
  }

  return [
    for (var index = 0; index < count; index += 1)
      (
        key: decodeNativeUtf8(
          (pairs + index).ref.key,
          allowMalformed: allowMalformed,
        ),
        value: decodeNativeUtf8(
          (pairs + index).ref.value,
          allowMalformed: allowMalformed,
        ),
      ),
  ];
}
