import 'dart:ffi';
import 'dart:typed_data';

import 'binary_payload_lease.dart';

/// Single-owner view over a binary payload retained in native memory.
///
/// [bytesPtr] and [bytesView] remain valid only until [close]. Native consumers
/// can synchronously borrow the pointer without allocating Dart-managed input.
final class NativeBinaryPayloadLease implements BinaryPayloadLease {
  NativeBinaryPayloadLease.fromPointer({
    required Pointer<Uint8> bytesPtr,
    required int length,
    required this._release,
  }) : _bytesPtr = bytesPtr,
       _length = RangeError.checkNotNegative(length, 'length') {
    if (length > 0 && bytesPtr == nullptr) {
      throw ArgumentError.value(
        bytesPtr,
        'bytesPtr',
        'Pointer must not be null for a non-empty payload.',
      );
    }
  }

  Pointer<Uint8> _bytesPtr;
  final int _length;
  final void Function() _release;
  var _closed = false;

  Pointer<Uint8> get bytesPtr {
    _ensureOpen();
    return _bytesPtr;
  }

  @override
  int get length {
    _ensureOpen();
    return _length;
  }

  @override
  bool get isClosed => _closed;

  @override
  Uint8List get bytesView {
    _ensureOpen();
    if (_length == 0) return Uint8List(0);
    return _bytesPtr.asTypedList(_length);
  }

  @override
  Uint8List copyBytes() => Uint8List.fromList(bytesView);

  @override
  Uint8List takeBytes() {
    try {
      return copyBytes();
    } finally {
      close();
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _bytesPtr = nullptr;
    _release();
  }

  void _ensureOpen() {
    if (isClosed) {
      throw StateError('Native binary payload lease is closed.');
    }
  }
}
