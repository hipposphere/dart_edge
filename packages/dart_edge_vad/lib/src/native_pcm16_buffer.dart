import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Native-memory PCM16 buffer for zero-copy VAD FFI input.
///
/// Ordinary Dart [Int16List] values cannot be passed to C as stable raw
/// pointers, so the compatibility APIs copy them into native memory before
/// calling FFI. Use this buffer when audio is produced or staged directly in
/// native memory and VAD should read it without that wrapper copy.
final class NativePcm16Buffer {
  NativePcm16Buffer(int sampleLength)
    : _sampleLength = RangeError.checkNotNegative(sampleLength, 'sampleLength'),
      _samplesPtr = sampleLength == 0 ? nullptr : calloc<Int16>(sampleLength);

  final int _sampleLength;
  final Pointer<Int16> _samplesPtr;
  var _closed = false;

  int get sampleLength => _sampleLength;

  int get byteLength => _sampleLength * sizeOf<Int16>();

  Pointer<Int16> get samplesPtr {
    _checkOpen();
    return _samplesPtr;
  }

  Pointer<Uint8> get bytesPtr {
    _checkOpen();
    return _samplesPtr.cast<Uint8>();
  }

  /// View over the native memory. The view is invalid after [close].
  Int16List get samples {
    _checkOpen();
    if (_sampleLength == 0) {
      return Int16List(0);
    }
    return _samplesPtr.asTypedList(_sampleLength);
  }

  void setAll(int index, Iterable<int> values) {
    samples.setAll(index, values);
  }

  void close() {
    if (_closed) {
      return;
    }
    if (_samplesPtr != nullptr) {
      calloc.free(_samplesPtr);
    }
    _closed = true;
  }

  void _checkOpen() {
    if (_closed) {
      throw StateError('Native PCM16 buffer is closed.');
    }
  }
}
