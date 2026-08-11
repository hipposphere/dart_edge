import 'dart:ffi';

import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_http_server_runtime/src/native/generated_bindings.dart'
    as gen;
import 'package:dart_edge_http_server_runtime/src/native/native_transport_web_transport.dart';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void main() {
  test('native lease exposes a view and releases its owner once', () {
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
    expect(() => lease.bytesView, throwsStateError);
  });

  test('WebTransport datagrams retain their native message handle', () {
    final bytes = calloc<Uint8>(3);
    bytes.asTypedList(3).setAll(0, [4, 5, 6]);
    final native = calloc<gen.NativeWebTransportDatagram>();
    native.ref
      ..session_id = 42
      ..body.ptr = bytes
      ..body.len = 3;
    var releaseCount = 0;

    final datagram = decodeNativeWebTransportDatagram(
      native,
      release: () {
        releaseCount += 1;
        calloc.free(bytes);
        calloc.free(native);
      },
    );

    expect(datagram.sessionId, 42);
    expect(datagram.bodyLease.bytesPtr, bytes);
    expect(datagram.bodyLease.bytesView, [4, 5, 6]);
    expect(releaseCount, 0);
    datagram.bodyLease.close();
    expect(releaseCount, 1);
  });

  test('WebTransport streams retain their native message handle', () {
    final bytes = calloc<Uint8>(2);
    bytes.asTypedList(2).setAll(0, [7, 8]);
    final native = calloc<gen.NativeWebTransportStream>();
    native.ref
      ..session_id = 43
      ..body.ptr = bytes
      ..body.len = 2;
    var releaseCount = 0;

    final stream = decodeNativeWebTransportStream(
      native,
      release: () {
        releaseCount += 1;
        calloc.free(bytes);
        calloc.free(native);
      },
    );

    expect(stream.sessionId, 43);
    expect(stream.bodyLease.bytesPtr, bytes);
    expect(stream.bodyLease.bytesView, [7, 8]);
    expect(releaseCount, 0);
    stream.bodyLease.close();
    expect(releaseCount, 1);
  });
}
