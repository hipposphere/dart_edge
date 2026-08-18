import 'dart:ffi';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void main() {
  test('exposes native bytes and releases its owner once', () {
    final bytes = calloc<Uint8>(3);
    bytes.asTypedList(3).setAll(0, [1, 2, 3]);
    var releaseCount = 0;
    final lease = NativeBinaryPayloadLease.fromPointer(
      bytesPtr: bytes,
      length: 3,
      release: () {
        releaseCount += 1;
        calloc.free(bytes);
      },
    );

    expect(lease.bytesPtr, bytes);
    expect(lease.bytesView, [1, 2, 3]);
    expect(lease.copyBytes(), [1, 2, 3]);
    expect(releaseCount, 0);

    expect(lease.takeBytes(), [1, 2, 3]);
    expect(releaseCount, 1);
    expect(lease.isClosed, isTrue);
    lease.close();
    expect(releaseCount, 1);
    expect(() => lease.bytesPtr, throwsStateError);
    expect(() => lease.bytesView, throwsStateError);
  });

  test('accepts an empty payload with a null pointer', () {
    var released = false;
    final lease = NativeBinaryPayloadLease.fromPointer(
      bytesPtr: nullptr,
      length: 0,
      release: () => released = true,
    );

    expect(lease.bytesView, isEmpty);
    lease.close();
    expect(released, isTrue);
  });

  test('rejects a null pointer for a non-empty payload', () {
    expect(
      () => NativeBinaryPayloadLease.fromPointer(
        bytesPtr: nullptr,
        length: 1,
        release: () {},
      ),
      throwsArgumentError,
    );
  });
}
