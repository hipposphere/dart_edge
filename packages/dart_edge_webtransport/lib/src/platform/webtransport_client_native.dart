import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../webtransport_client.dart';
import 'webtransport_native_bindings.dart' as gen;

/// Native WebTransport client backed by the package Rust native asset.
final class PlatformWebTransportClient implements DartEdgeWebTransportClient {
  const PlatformWebTransportClient({this.allowSelfSignedCertificates = false});

  final bool allowSelfSignedCertificates;

  @override
  Future<DartEdgeWebTransportSession> connect(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final handle = await Isolate.run(
      () => _nativeConnect((
        uri: uri.toString(),
        headers: headers,
        allowSelfSignedCertificates: allowSelfSignedCertificates,
      )),
    );
    return _NativeWebTransportSession(handle);
  }
}

final class _NativeWebTransportSession implements DartEdgeWebTransportSession {
  _NativeWebTransportSession(this._handle);

  final int _handle;
  bool _closed = false;

  @override
  Stream<Uint8List> get datagrams => _readDatagrams();

  @override
  Stream<Uint8List> get streams => _readStreams();

  @override
  Future<void> sendDatagram(List<int> bytes) async {
    if (_closed) {
      throw const DartEdgeWebTransportException(
        'Cannot send a datagram on a closed WebTransport session.',
      );
    }

    final handle = _handle;
    await Isolate.run(
      () => _nativeSendDatagram((
        handle: handle,
        bytes: Uint8List.fromList(bytes),
      )),
    );
  }

  @override
  Future<void> sendStream(List<int> bytes) async {
    if (_closed) {
      throw const DartEdgeWebTransportException(
        'Cannot send a stream on a closed WebTransport session.',
      );
    }

    final handle = _handle;
    await Isolate.run(
      () =>
          _nativeSendStream((handle: handle, bytes: Uint8List.fromList(bytes))),
    );
  }

  @override
  Future<void> close({int code = 0, String reason = ''}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    final handle = _handle;
    try {
      await Isolate.run(
        () => _nativeClose((handle: handle, code: code, reason: reason)),
      );
    } finally {}
  }

  Stream<Uint8List> _readDatagrams() async* {
    final handle = _handle;
    while (!_closed) {
      yield await Isolate.run(() => _nativeReceiveDatagram(handle));
    }
  }

  Stream<Uint8List> _readStreams() async* {
    final handle = _handle;
    while (!_closed) {
      yield await Isolate.run(() => _nativeReceiveStream(handle));
    }
  }
}

int _nativeConnect(
  ({String uri, Map<String, String> headers, bool allowSelfSignedCertificates})
  input,
) {
  final config = calloc<gen.NativeWebTransportConnectConfig>();
  final url = input.uri.toNativeUtf8();
  final headersJson = jsonEncode(input.headers).toNativeUtf8();

  try {
    config.ref
      ..url = url
      ..headers_json = headersJson
      ..allow_self_signed = input.allowSelfSignedCertificates;

    final resultPtr = gen.dart_edge_webtransport_connect(config);
    if (resultPtr == ffi.nullptr) {
      throw const DartEdgeWebTransportException(
        'dart_edge_webtransport connect returned null.',
      );
    }

    try {
      final result = resultPtr.ref;
      _throwIfError(result.error);
      if (result.handle <= 0) {
        throw const DartEdgeWebTransportException(
          'dart_edge_webtransport connect returned no handle.',
        );
      }
      return result.handle;
    } finally {
      gen.dart_edge_webtransport_free_connect_result(resultPtr);
    }
  } finally {
    calloc.free(config);
    calloc.free(url);
    calloc.free(headersJson);
  }
}

void _nativeSendDatagram(({int handle, Uint8List bytes}) input) {
  _nativeSendBytes(input, gen.dart_edge_webtransport_send_datagram);
}

void _nativeSendStream(({int handle, Uint8List bytes}) input) {
  _nativeSendBytes(input, gen.dart_edge_webtransport_send_stream);
}

void _nativeSendBytes(
  ({int handle, Uint8List bytes}) input,
  ffi.Pointer<ffi.Char> Function(int, ffi.Pointer<ffi.Uint8>, int) send,
) {
  final bytesPtr = input.bytes.isEmpty
      ? ffi.nullptr
      : calloc<ffi.Uint8>(input.bytes.length);
  try {
    if (bytesPtr != ffi.nullptr) {
      bytesPtr.asTypedList(input.bytes.length).setAll(0, input.bytes);
    }
    final errorPtr = send(input.handle, bytesPtr, input.bytes.length);
    _throwAndFreeError(errorPtr);
  } finally {
    if (bytesPtr != ffi.nullptr) {
      calloc.free(bytesPtr);
    }
  }
}

Uint8List _nativeReceiveDatagram(int handle) {
  return _nativeReceiveBytes(
    handle,
    gen.dart_edge_webtransport_receive_datagram,
    'receive_datagram',
  );
}

Uint8List _nativeReceiveStream(int handle) {
  return _nativeReceiveBytes(
    handle,
    gen.dart_edge_webtransport_receive_stream,
    'receive_stream',
  );
}

Uint8List _nativeReceiveBytes(
  int handle,
  ffi.Pointer<gen.NativeWebTransportBytesResult> Function(int) receive,
  String name,
) {
  final resultPtr = receive(handle);
  if (resultPtr == ffi.nullptr) {
    throw DartEdgeWebTransportException(
      'dart_edge_webtransport $name returned null.',
    );
  }

  try {
    final result = resultPtr.ref;
    _throwIfError(result.error);
    return result.length == 0
        ? Uint8List(0)
        : Uint8List.fromList(result.bytes.asTypedList(result.length));
  } finally {
    gen.dart_edge_webtransport_free_bytes_result(resultPtr);
  }
}

void _nativeClose(({int handle, int code, String reason}) input) {
  final reasonPtr = input.reason.toNativeUtf8();
  try {
    final errorPtr = gen.dart_edge_webtransport_close(
      input.handle,
      input.code,
      reasonPtr,
    );
    _throwAndFreeError(errorPtr);
  } finally {
    calloc.free(reasonPtr);
    gen.dart_edge_webtransport_dispose(input.handle);
  }
}

void _throwIfError(ffi.Pointer<ffi.Char> errorPtr) {
  if (errorPtr == ffi.nullptr) {
    return;
  }
  throw DartEdgeWebTransportException(errorPtr.cast<Utf8>().toDartString());
}

void _throwAndFreeError(ffi.Pointer<ffi.Char> errorPtr) {
  try {
    _throwIfError(errorPtr);
  } finally {
    if (errorPtr != ffi.nullptr) {
      gen.dart_edge_webtransport_free_string(errorPtr);
    }
  }
}
