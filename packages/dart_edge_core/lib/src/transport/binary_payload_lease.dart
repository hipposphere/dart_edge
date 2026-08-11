import 'dart:typed_data';

/// Single-owner access to a binary transport payload.
///
/// Native runtimes can implement this contract with a view over native memory,
/// allowing hot-path consumers to inspect or forward a payload without first
/// allocating Dart-managed bytes. The view is valid only until [close].
abstract interface class BinaryPayloadLease {
  /// Creates a lease backed by existing Dart-managed bytes.
  factory BinaryPayloadLease.fromBytes(Uint8List bytes) =
      DartBinaryPayloadLease;

  int get length;

  bool get isClosed;

  /// Zero-copy view of the payload.
  ///
  /// This view becomes invalid after [close]. Do not retain it independently
  /// of the lease.
  Uint8List get bytesView;

  /// Copies the payload while keeping this lease open.
  Uint8List copyBytes();

  /// Returns safe Dart-managed bytes and closes this lease.
  Uint8List takeBytes();

  /// Releases the payload owner. Calling this more than once is safe.
  void close();
}

/// A [BinaryPayloadLease] whose backing storage is already Dart-managed.
final class DartBinaryPayloadLease implements BinaryPayloadLease {
  DartBinaryPayloadLease(this._bytes);

  Uint8List? _bytes;

  @override
  int get length => _requireBytes().lengthInBytes;

  @override
  bool get isClosed => _bytes == null;

  @override
  Uint8List get bytesView => _requireBytes();

  @override
  Uint8List copyBytes() => Uint8List.fromList(_requireBytes());

  @override
  Uint8List takeBytes() {
    final bytes = _requireBytes();
    _bytes = null;
    return bytes;
  }

  @override
  void close() {
    _bytes = null;
  }

  Uint8List _requireBytes() {
    return _bytes ?? (throw StateError('Binary payload lease is closed.'));
  }
}
