import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:ffi/ffi.dart';

import '../webtransport_client.dart';
import 'webtransport_native_bindings.dart' as gen;

const _eventIncomingStream = 1;
const _eventStreamChunkReady = 2;
const _eventStreamFinished = 3;
const _eventOperationReady = 4;
const _eventDatagramReady = 5;
const _expectedNativeAbiVersion = 2;

typedef _NativeTransportEvent = ffi.Void Function(ffi.Int32, ffi.Int64);

/// Native WebTransport client backed by the package Rust native asset.
final class PlatformWebTransportClient implements DartEdgeWebTransportClient {
  const PlatformWebTransportClient({this.allowSelfSignedCertificates = false});

  final bool allowSelfSignedCertificates;

  @override
  Future<DartEdgeWebTransportSession> connect(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) {
    return _NativeWebTransportSession.connect(
      uri,
      headers: headers,
      allowSelfSignedCertificates: allowSelfSignedCertificates,
    );
  }
}

final class _NativeWebTransportSession implements DartEdgeWebTransportSession {
  _NativeWebTransportSession._(this._handle, this._callback) {
    _datagrams = StreamController<Uint8List>(
      onListen: _drainDatagrams,
      onResume: _drainDatagrams,
    );
    _unidirectional = StreamController<WebTransportReceiveStream>();
    _bidirectional = StreamController<WebTransportBidirectionalStream>();
  }

  static Future<_NativeWebTransportSession> connect(
    Uri uri, {
    required Map<String, String> headers,
    required bool allowSelfSignedCertificates,
  }) async {
    final nativeAbiVersion = gen.dart_edge_webtransport_native_abi_version();
    if (nativeAbiVersion != _expectedNativeAbiVersion) {
      throw DartEdgeWebTransportException(
        'Unsupported dart_edge_webtransport native ABI $nativeAbiVersion; '
        'expected $_expectedNativeAbiVersion.',
      );
    }
    final earlyEvents = <(int, int)>[];
    _NativeWebTransportSession? session;
    late final ffi.NativeCallable<_NativeTransportEvent> callback;

    void handleEvent(int kind, int id) {
      final active = session;
      if (active == null) {
        earlyEvents.add((kind, id));
      } else {
        active._handleEvent(kind, id);
      }
    }

    callback = ffi.NativeCallable<_NativeTransportEvent>.listener(handleEvent);
    try {
      final callbackAddress = callback.nativeFunction.address;
      final handle = await Isolate.run(
        () => _nativeConnect((
          uri: uri.toString(),
          headers: headers,
          allowSelfSignedCertificates: allowSelfSignedCertificates,
          callbackAddress: callbackAddress,
        )),
      );
      final active = _NativeWebTransportSession._(handle, callback);
      session = active;
      for (final (kind, id) in earlyEvents) {
        active._handleEvent(kind, id);
      }
      return active;
    } catch (_) {
      callback.close();
      rethrow;
    }
  }

  final int _handle;
  final ffi.NativeCallable<_NativeTransportEvent> _callback;
  late final StreamController<Uint8List> _datagrams;
  late final StreamController<WebTransportReceiveStream> _unidirectional;
  late final StreamController<WebTransportBidirectionalStream> _bidirectional;
  final Map<int, _NativePersistentStream> _persistentStreams =
      <int, _NativePersistentStream>{};
  final Map<int, Completer<_NativeOperation>> _pendingOperations =
      <int, Completer<_NativeOperation>>{};
  final Map<int, _NativeOperation> _earlyOperations = <int, _NativeOperation>{};
  final Map<int, _NativeTerminal> _earlyTerminals = <int, _NativeTerminal>{};
  final Set<BinaryPayloadLease> _leases = <BinaryPayloadLease>{};
  bool _closed = false;

  @override
  Stream<Uint8List> get datagrams => _datagrams.stream;

  @override
  IncomingWebTransportReceiveStreams get incomingStreams =>
      IncomingWebTransportReceiveStreams(
        unidirectional: _unidirectional.stream,
        bidirectional: _bidirectional.stream,
      );

  @override
  Stream<Uint8List> get streams =>
      _unidirectional.stream.asyncMap(_collectStream);

  @override
  Future<void> sendDatagram(List<int> bytes) async {
    _ensureOpen('send a datagram');
    _withNativeBytes(bytes, (pointer, length) {
      _throwAndFreeError(
        gen.dart_edge_webtransport_send_datagram(_handle, pointer, length),
      );
    });
  }

  @override
  Future<void> sendStream(List<int> bytes) async {
    final stream = await openUnidirectionalStream();
    await stream.write(bytes);
    await stream.finish();
  }

  @override
  Future<WebTransportSendStream> openUnidirectionalStream({
    int? sendOrder,
  }) async {
    _ensureOpen('open a unidirectional stream');
    _checkSendOrder(sendOrder);
    final operation = await _waitForOperation(
      gen.dart_edge_webtransport_open_unidirectional_stream(
        _handle,
        sendOrder ?? 0,
        sendOrder != null,
      ),
      'unidirectional stream open',
    );
    return _registerStreamFromOperation(operation).send;
  }

  @override
  Future<WebTransportBidirectionalStream> openBidirectionalStream({
    int? sendOrder,
  }) async {
    _ensureOpen('open a bidirectional stream');
    _checkSendOrder(sendOrder);
    final operation = await _waitForOperation(
      gen.dart_edge_webtransport_open_bidirectional_stream(
        _handle,
        sendOrder ?? 0,
        sendOrder != null,
      ),
      'bidirectional stream open',
    );
    final stream = _registerStreamFromOperation(operation);
    _drainStreamChunks(stream.id);
    return WebTransportBidirectionalStream(
      receive: stream.receive,
      send: stream.send,
    );
  }

  @override
  Future<void> close({int code = 0, String reason = ''}) async {
    if (_closed) return;
    _closed = true;
    final closedError = const DartEdgeWebTransportException(
      'WebTransport session closed before the operation completed.',
    );
    for (final completer in _pendingOperations.values) {
      if (!completer.isCompleted) completer.completeError(closedError);
    }
    _pendingOperations.clear();
    _earlyOperations.clear();
    _earlyTerminals.clear();

    try {
      final handle = _handle;
      await Isolate.run(
        () => _nativeClose((handle: handle, code: code, reason: reason)),
      );
    } finally {
      for (final lease in _leases) {
        lease.close();
      }
      _leases.clear();
      if (!_datagrams.isClosed) unawaited(_datagrams.close());
      if (!_unidirectional.isClosed) unawaited(_unidirectional.close());
      if (!_bidirectional.isClosed) unawaited(_bidirectional.close());
      for (final stream in _persistentStreams.values) {
        if (!stream.chunks.isClosed) unawaited(stream.chunks.close());
      }
      _persistentStreams.clear();
      _callback.close();
    }
  }

  void _handleEvent(int kind, int id) {
    if (_closed) return;
    switch (kind) {
      case _eventIncomingStream:
        _handleIncomingStream(id);
      case _eventStreamChunkReady:
        _drainStreamChunks(id);
      case _eventStreamFinished:
        _handleStreamFinished(id);
      case _eventOperationReady:
        _handleOperationReady(id);
      case _eventDatagramReady:
        _drainDatagrams();
    }
  }

  void _handleIncomingStream(int streamId) {
    final info = _takeStreamInfo(streamId);
    if (info == null || info.sessionId != _handle) return;
    final stream = _registerStream(info);
    switch (info.kind) {
      case 1:
        _unidirectional.add(stream.receive);
      case 2:
        _bidirectional.add(
          WebTransportBidirectionalStream(
            receive: stream.receive,
            send: stream.send,
          ),
        );
      default:
        unawaited(stream.chunks.close());
        return;
    }
    _drainStreamChunks(streamId);
  }

  _NativePersistentStream _registerStreamFromOperation(
    _NativeOperation operation,
  ) => _registerStream(
    _NativeStreamInfo(
      sessionId: operation.sessionId,
      streamId: operation.streamId,
      protocolId: operation.protocolId,
      kind: operation.kind == 1 ? 3 : 4,
    ),
  );

  _NativePersistentStream _registerStream(_NativeStreamInfo info) {
    final existing = _persistentStreams[info.streamId];
    if (existing != null) return existing;
    late final _NativePersistentStream stream;
    final chunks = StreamController<BinaryPayloadLease>(
      onListen: () => _drainStreamChunks(info.streamId),
      onResume: () => _drainStreamChunks(info.streamId),
    );
    final receive = WebTransportReceiveStream(
      id: info.streamId,
      protocolId: info.protocolId,
      leases: chunks.stream,
      stop: ([errorCode = 0]) async {
        _checkErrorCode(errorCode);
        await _waitForOperation(
          gen.dart_edge_webtransport_stream_stop(info.streamId, errorCode),
          'stream stop',
        );
      },
    );
    final send = WebTransportSendStream(
      id: info.streamId,
      protocolId: info.protocolId,
      write: (value) => stream.enqueueSend(() async {
        final operationId = _withNativeBytes(
          value,
          (pointer, length) => gen.dart_edge_webtransport_stream_write(
            info.streamId,
            pointer,
            length,
          ),
        );
        await _waitForOperation(operationId, 'stream write');
      }),
      writeLease: (lease) => stream.enqueueSend(() async {
        try {
          final operationId = switch (lease) {
            _NativeWebTransportPayloadLease() =>
              gen.dart_edge_webtransport_stream_write(
                info.streamId,
                lease.bytesPointer,
                lease.length,
              ),
            _ => _withNativeBytes(
              lease.bytesView,
              (pointer, length) => gen.dart_edge_webtransport_stream_write(
                info.streamId,
                pointer,
                length,
              ),
            ),
          };
          await _waitForOperation(operationId, 'stream write');
        } finally {
          lease.close();
        }
      }),
      finish: () => stream.enqueueTerminal(() async {
        await _waitForOperation(
          gen.dart_edge_webtransport_stream_finish(info.streamId),
          'stream finish',
        );
      }),
      reset: ([errorCode = 0]) => stream.enqueueTerminal(() async {
        _checkErrorCode(errorCode);
        await _waitForOperation(
          gen.dart_edge_webtransport_stream_reset(info.streamId, errorCode),
          'stream reset',
        );
      }),
    );
    stream = _NativePersistentStream(
      id: info.streamId,
      chunks: chunks,
      receive: receive,
      send: send,
    );
    stream.terminal = _earlyTerminals.remove(info.streamId);
    _persistentStreams[info.streamId] = stream;
    return stream;
  }

  void _drainStreamChunks(int streamId) {
    final stream = _persistentStreams[streamId];
    if (stream == null ||
        stream.chunks.isClosed ||
        !stream.chunks.hasListener ||
        stream.chunks.isPaused) {
      return;
    }
    while (true) {
      final result = gen.dart_edge_webtransport_take_stream_chunk(streamId);
      if (result == ffi.nullptr) {
        _finishReceiveStream(stream);
        return;
      }
      final value = result.ref;
      final lease = _NativeWebTransportPayloadLease(
        bytesPointer: value.bytes,
        length: value.length,
        releaseCallback: () =>
            gen.dart_edge_webtransport_free_stream_chunk(result),
      );
      _trackLease(lease);
      stream.chunks.add(lease);
      if (stream.chunks.isPaused) return;
    }
  }

  void _handleStreamFinished(int streamId) {
    final terminal = _takeStreamTerminal(streamId);
    if (terminal == null) return;
    final stream = _persistentStreams[streamId];
    if (stream == null) {
      _earlyTerminals[streamId] = terminal;
      return;
    }
    stream.terminal = terminal;
    _drainStreamChunks(streamId);
  }

  void _finishReceiveStream(_NativePersistentStream stream) {
    final terminal = stream.terminal;
    if (terminal == null || stream.chunks.isClosed) return;
    stream.terminal = null;
    if (terminal.error.isNotEmpty &&
        terminal.error != 'receive stopped locally') {
      stream.chunks.addError(
        DartEdgeWebTransportException(
          'Stream ${stream.id} ended${terminal.errorCode == null ? '' : ' with code ${terminal.errorCode}'}: '
          '${terminal.error}',
        ),
      );
    }
    if (!stream.chunks.isClosed) unawaited(stream.chunks.close());
  }

  void _handleOperationReady(int operationId) {
    final operation = _takeOperation(operationId);
    if (operation == null) return;
    final completer = _pendingOperations.remove(operationId);
    if (completer != null) {
      completer.complete(operation);
    } else {
      _earlyOperations[operationId] = operation;
    }
  }

  void _drainDatagrams() {
    if (_datagrams.isClosed || !_datagrams.hasListener || _datagrams.isPaused) {
      return;
    }
    while (true) {
      final datagram = _takeDatagram(_handle);
      if (datagram == null) return;
      _datagrams.add(datagram);
      if (_datagrams.isPaused) return;
    }
  }

  Future<_NativeOperation> _waitForOperation(
    int operationId,
    String action,
  ) async {
    if (operationId == 0) {
      throw DartEdgeWebTransportException(
        'Failed to submit WebTransport $action.',
      );
    }
    final early = _earlyOperations.remove(operationId);
    final operation =
        early ??
        await (_pendingOperations[operationId] = Completer<_NativeOperation>())
            .future;
    if (!operation.succeeded) {
      throw DartEdgeWebTransportException(
        'WebTransport $action failed${operation.error.isEmpty ? '.' : ': ${operation.error}'}',
      );
    }
    return operation;
  }

  void _trackLease(BinaryPayloadLease lease) {
    _leases.removeWhere((value) => value.isClosed);
    _leases.add(lease);
  }

  void _ensureOpen(String action) {
    if (_closed) {
      throw DartEdgeWebTransportException(
        'Cannot $action on a closed WebTransport session.',
      );
    }
  }
}

final class _NativePersistentStream {
  _NativePersistentStream({
    required this.id,
    required this.chunks,
    required this.receive,
    required this.send,
  });

  final int id;
  final StreamController<BinaryPayloadLease> chunks;
  final WebTransportReceiveStream receive;
  final WebTransportSendStream send;
  _NativeTerminal? terminal;
  Future<void> _sendTail = Future<void>.value();
  bool _terminalQueued = false;

  Future<void> enqueueSend(Future<void> Function() action) {
    if (_terminalQueued) {
      return Future<void>.error(
        StateError('WebTransport send stream $id is already closed.'),
      );
    }
    return _enqueue(action);
  }

  Future<void> enqueueTerminal(Future<void> Function() action) {
    if (_terminalQueued) {
      return Future<void>.error(
        StateError('WebTransport send stream $id is already closed.'),
      );
    }
    _terminalQueued = true;
    return _enqueue(action);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final completer = Completer<void>();
    _sendTail = _sendTail.then(
      (_) async {
        try {
          await action();
          completer.complete();
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
      onError: (_) async {
        try {
          await action();
          completer.complete();
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future;
  }
}

final class _NativeWebTransportPayloadLease implements BinaryPayloadLease {
  _NativeWebTransportPayloadLease({
    required ffi.Pointer<ffi.Uint8> bytesPointer,
    required int length,
    required this.releaseCallback,
  }) : _bytesPointer = bytesPointer,
       _length = RangeError.checkNotNegative(length, 'length') {
    if (length > 0 && bytesPointer == ffi.nullptr) {
      throw ArgumentError.value(
        bytesPointer,
        'bytesPointer',
        'Pointer must not be null for a non-empty payload.',
      );
    }
  }

  ffi.Pointer<ffi.Uint8> _bytesPointer;
  final int _length;
  void Function()? releaseCallback;

  ffi.Pointer<ffi.Uint8> get bytesPointer {
    _ensureOpen();
    return _bytesPointer;
  }

  @override
  int get length {
    _ensureOpen();
    return _length;
  }

  @override
  bool get isClosed => releaseCallback == null;

  @override
  Uint8List get bytesView {
    _ensureOpen();
    return _length == 0 ? Uint8List(0) : _bytesPointer.asTypedList(_length);
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
    final release = releaseCallback;
    if (release == null) return;
    releaseCallback = null;
    _bytesPointer = ffi.nullptr;
    release();
  }

  void _ensureOpen() {
    if (isClosed) {
      throw StateError('Native WebTransport payload lease is closed.');
    }
  }
}

final class _NativeStreamInfo {
  const _NativeStreamInfo({
    required this.sessionId,
    required this.streamId,
    required this.protocolId,
    required this.kind,
  });

  final int sessionId;
  final int streamId;
  final int protocolId;
  final int kind;
}

final class _NativeOperation {
  const _NativeOperation({
    required this.sessionId,
    required this.streamId,
    required this.protocolId,
    required this.kind,
    required this.succeeded,
    required this.error,
  });

  final int sessionId;
  final int streamId;
  final int protocolId;
  final int kind;
  final bool succeeded;
  final String error;
}

final class _NativeTerminal {
  const _NativeTerminal({required this.errorCode, required this.error});

  final int? errorCode;
  final String error;
}

int _nativeConnect(
  ({
    String uri,
    Map<String, String> headers,
    bool allowSelfSignedCertificates,
    int callbackAddress,
  })
  input,
) {
  final config = calloc<gen.NativeWebTransportConnectConfig>();
  final url = input.uri.toNativeUtf8();
  final headersJson = jsonEncode(input.headers).toNativeUtf8();
  try {
    config.ref
      ..url = url.cast()
      ..headers_json = headersJson.cast()
      ..allow_self_signed = input.allowSelfSignedCertificates
      ..callback =
          ffi.Pointer<ffi.NativeFunction<_NativeTransportEvent>>.fromAddress(
            input.callbackAddress,
          );
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

Uint8List? _takeDatagram(int handle) {
  final resultPtr = gen.dart_edge_webtransport_take_datagram(handle);
  if (resultPtr == ffi.nullptr) return null;
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
  final reason = input.reason.toNativeUtf8();
  try {
    _throwAndFreeError(
      gen.dart_edge_webtransport_close(input.handle, input.code, reason.cast()),
    );
  } finally {
    calloc.free(reason);
    gen.dart_edge_webtransport_dispose(input.handle);
  }
}

_NativeStreamInfo? _takeStreamInfo(int streamId) {
  final pointer = gen.dart_edge_webtransport_take_stream_info(streamId);
  if (pointer == ffi.nullptr) return null;
  try {
    final value = pointer.ref;
    return _NativeStreamInfo(
      sessionId: value.session_id,
      streamId: value.stream_id,
      protocolId: value.protocol_id,
      kind: value.kind,
    );
  } finally {
    gen.dart_edge_webtransport_free_stream_info(pointer);
  }
}

_NativeOperation? _takeOperation(int operationId) {
  final pointer = gen.dart_edge_webtransport_take_operation(operationId);
  if (pointer == ffi.nullptr) return null;
  try {
    final value = pointer.ref;
    return _NativeOperation(
      sessionId: value.session_id,
      streamId: value.stream_id,
      protocolId: value.protocol_id,
      kind: value.kind,
      succeeded: value.succeeded,
      error: _readString(value.error),
    );
  } finally {
    gen.dart_edge_webtransport_free_operation(pointer);
  }
}

_NativeTerminal? _takeStreamTerminal(int streamId) {
  final pointer = gen.dart_edge_webtransport_take_stream_terminal(streamId);
  if (pointer == ffi.nullptr) return null;
  try {
    final value = pointer.ref;
    return _NativeTerminal(
      errorCode: value.error_code < 0 ? null : value.error_code,
      error: _readString(value.error),
    );
  } finally {
    gen.dart_edge_webtransport_free_stream_terminal(pointer);
  }
}

T _withNativeBytes<T>(
  List<int> bytes,
  T Function(ffi.Pointer<ffi.Uint8> pointer, int length) run,
) {
  final pointer = bytes.isEmpty ? ffi.nullptr : calloc<ffi.Uint8>(bytes.length);
  try {
    if (pointer != ffi.nullptr) {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
    }
    return run(pointer, bytes.length);
  } finally {
    if (pointer != ffi.nullptr) calloc.free(pointer);
  }
}

Future<Uint8List> _collectStream(WebTransportReceiveStream stream) async {
  final builder = BytesBuilder();
  await for (final lease in stream.leases()) {
    try {
      builder.add(lease.bytesView);
    } finally {
      lease.close();
    }
  }
  return builder.takeBytes();
}

String _readString(ffi.Pointer<ffi.Char> pointer) =>
    pointer == ffi.nullptr ? '' : pointer.cast<Utf8>().toDartString();

void _throwIfError(ffi.Pointer<ffi.Char> errorPtr) {
  if (errorPtr != ffi.nullptr) {
    throw DartEdgeWebTransportException(_readString(errorPtr));
  }
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

void _checkErrorCode(int errorCode) {
  RangeError.checkValueInInterval(errorCode, 0, 0xffffffff, 'errorCode');
}

void _checkSendOrder(int? sendOrder) {
  if (sendOrder != null) {
    RangeError.checkValueInInterval(
      sendOrder,
      -0x80000000,
      0x7fffffff,
      'sendOrder',
    );
  }
}
