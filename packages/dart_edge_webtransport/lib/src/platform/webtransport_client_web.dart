import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:web/web.dart' as web;

import '../webtransport_client.dart';

/// Browser WebTransport client backed by the platform WebTransport API.
final class PlatformWebTransportClient implements DartEdgeWebTransportClient {
  const PlatformWebTransportClient({bool allowSelfSignedCertificates = false});

  @override
  Future<DartEdgeWebTransportSession> connect(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (!web.window.hasProperty('WebTransport'.toJS).toDart) {
      throw const DartEdgeWebTransportException(
        'The current browser does not expose WebTransport.',
      );
    }

    if (headers.isNotEmpty) {
      throw const DartEdgeWebTransportException(
        'Browser WebTransport does not support custom handshake headers. '
        'Use browser-managed cookies, a short-lived URL credential, or '
        'authenticate over the first reliable stream.',
      );
    }
    final transport = web.WebTransport(uri.toString());

    await transport.ready.toDart;
    return _BrowserWebTransportSession(transport);
  }
}

final class _BrowserWebTransportSession implements DartEdgeWebTransportSession {
  _BrowserWebTransportSession(this._transport) {
    _datagramWriter = _transport.datagrams.writable.getWriter();
    _datagrams = StreamController<Uint8List>(onListen: _startReadingDatagrams);
    _unidirectional = StreamController<WebTransportReceiveStream>(
      onListen: _startReadingUnidirectionalStreams,
    );
    _bidirectional = StreamController<WebTransportBidirectionalStream>(
      onListen: _startReadingBidirectionalStreams,
    );
  }

  final web.WebTransport _transport;
  late final web.WritableStreamDefaultWriter _datagramWriter;
  late final StreamController<Uint8List> _datagrams;
  late final StreamController<WebTransportReceiveStream> _unidirectional;
  late final StreamController<WebTransportBidirectionalStream> _bidirectional;
  web.ReadableStreamDefaultReader? _datagramReader;
  web.ReadableStreamDefaultReader? _unidirectionalReader;
  web.ReadableStreamDefaultReader? _bidirectionalReader;
  bool _readingDatagrams = false;
  bool _readingUnidirectional = false;
  bool _readingBidirectional = false;
  bool _closed = false;
  int _nextStreamId = 1;

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
    await _datagramWriter.write(Uint8List.fromList(bytes).toJS).toDart;
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
    final value = sendOrder == null
        ? await _transport.createUnidirectionalStream().toDart
        : await _transport
              .createUnidirectionalStream(
                web.WebTransportSendStreamOptions(sendOrder: sendOrder),
              )
              .toDart;
    return _wrapSendStream(value as web.WritableStream);
  }

  @override
  Future<WebTransportBidirectionalStream> openBidirectionalStream({
    int? sendOrder,
  }) async {
    _ensureOpen('open a bidirectional stream');
    final value = sendOrder == null
        ? await _transport.createBidirectionalStream().toDart
        : await _transport
              .createBidirectionalStream(
                web.WebTransportSendStreamOptions(sendOrder: sendOrder),
              )
              .toDart;
    return _wrapBidirectionalStream(value);
  }

  @override
  Future<void> close({int code = 0, String reason = ''}) async {
    if (_closed) return;
    _closed = true;
    _datagramReader?.releaseLock();
    _unidirectionalReader?.releaseLock();
    _bidirectionalReader?.releaseLock();
    _datagramWriter.releaseLock();
    _transport.close(
      web.WebTransportCloseInfo(closeCode: code, reason: reason),
    );
    if (!_datagrams.isClosed) unawaited(_datagrams.close());
    if (!_unidirectional.isClosed) unawaited(_unidirectional.close());
    if (!_bidirectional.isClosed) unawaited(_bidirectional.close());
  }

  WebTransportSendStream _wrapSendStream(web.WritableStream writable) {
    final id = _nextStreamId++;
    final state = _BrowserSendStream(id, writable.getWriter());
    return state.publicStream;
  }

  WebTransportReceiveStream _wrapReceiveStream(web.ReadableStream readable) {
    final id = _nextStreamId++;
    return _BrowserReceiveStream(
      id,
      readable.getReader() as web.ReadableStreamDefaultReader,
    ).publicStream;
  }

  WebTransportBidirectionalStream _wrapBidirectionalStream(
    web.WebTransportBidirectionalStream stream,
  ) {
    final id = _nextStreamId++;
    final receive = _BrowserReceiveStream(
      id,
      (stream.readable as web.ReadableStream).getReader()
          as web.ReadableStreamDefaultReader,
    );
    final send = _BrowserSendStream(
      id,
      (stream.writable as web.WritableStream).getWriter(),
    );
    return WebTransportBidirectionalStream(
      receive: receive.publicStream,
      send: send.publicStream,
    );
  }

  Future<void> _startReadingDatagrams() async {
    if (_readingDatagrams || _closed) return;
    _readingDatagrams = true;
    final reader = _datagramReader ??=
        _transport.datagrams.readable.getReader()
            as web.ReadableStreamDefaultReader;
    try {
      while (!_closed) {
        final result = await reader.read().toDart;
        if (result.done) break;
        if (result.value case final value?) {
          _datagrams.add(_bytesFromJs(value));
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) _datagrams.addError(error, stackTrace);
    } finally {
      _readingDatagrams = false;
      if (!_datagrams.isClosed) unawaited(_datagrams.close());
    }
  }

  Future<void> _startReadingUnidirectionalStreams() async {
    if (_readingUnidirectional || _closed) return;
    _readingUnidirectional = true;
    final reader = _unidirectionalReader ??=
        _transport.incomingUnidirectionalStreams.getReader()
            as web.ReadableStreamDefaultReader;
    try {
      while (!_closed) {
        final result = await reader.read().toDart;
        if (result.done) break;
        if (result.value case final value?) {
          _unidirectional.add(_wrapReceiveStream(value as web.ReadableStream));
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) _unidirectional.addError(error, stackTrace);
    } finally {
      _readingUnidirectional = false;
      if (!_unidirectional.isClosed) unawaited(_unidirectional.close());
    }
  }

  Future<void> _startReadingBidirectionalStreams() async {
    if (_readingBidirectional || _closed) return;
    _readingBidirectional = true;
    final reader = _bidirectionalReader ??=
        _transport.incomingBidirectionalStreams.getReader()
            as web.ReadableStreamDefaultReader;
    try {
      while (!_closed) {
        final result = await reader.read().toDart;
        if (result.done) break;
        if (result.value case final value?) {
          _bidirectional.add(
            _wrapBidirectionalStream(
              value as web.WebTransportBidirectionalStream,
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) _bidirectional.addError(error, stackTrace);
    } finally {
      _readingBidirectional = false;
      if (!_bidirectional.isClosed) unawaited(_bidirectional.close());
    }
  }

  void _ensureOpen(String action) {
    if (_closed) {
      throw DartEdgeWebTransportException(
        'Cannot $action on a closed WebTransport session.',
      );
    }
  }
}

final class _BrowserSendStream {
  _BrowserSendStream(this.id, this._writer) {
    publicStream = WebTransportSendStream(
      id: id,
      protocolId: null,
      write: _write,
      writeLease: _writeLease,
      finish: _finish,
      reset: _reset,
    );
  }

  final int id;
  final web.WritableStreamDefaultWriter _writer;
  late final WebTransportSendStream publicStream;
  Future<void> _tail = Future<void>.value();
  bool _terminal = false;

  Future<void> _write(List<int> bytes) => _enqueue(() async {
    await _writer.write(Uint8List.fromList(bytes).toJS).toDart;
  });

  Future<void> _writeLease(BinaryPayloadLease lease) => _enqueue(() async {
    try {
      await _writer.write(lease.bytesView.toJS).toDart;
    } finally {
      lease.close();
    }
  });

  Future<void> _finish() {
    if (_terminal) return _closedError();
    _terminal = true;
    return _append(() async {
      try {
        await _writer.close().toDart;
      } finally {
        _writer.releaseLock();
      }
    });
  }

  Future<void> _reset([int errorCode = 0]) {
    if (_terminal) return _closedError();
    _checkBrowserStreamErrorCode(errorCode);
    _terminal = true;
    return _append(() async {
      try {
        await _writer.abort(_streamError(errorCode)).toDart;
      } finally {
        _writer.releaseLock();
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (_terminal) return _closedError();
    return _append(action);
  }

  Future<void> _append(Future<void> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.catchError((_) {});
    return operation;
  }

  Future<void> _closedError() => Future<void>.error(
    StateError('WebTransport send stream $id is already closed.'),
  );
}

final class _BrowserReceiveStream {
  _BrowserReceiveStream(this.id, this._reader) {
    publicStream = WebTransportReceiveStream(
      id: id,
      protocolId: null,
      leases: _readLeases(),
      stop: _stop,
    );
  }

  final int id;
  final web.ReadableStreamDefaultReader _reader;
  late final WebTransportReceiveStream publicStream;
  bool _terminal = false;

  Stream<BinaryPayloadLease> _readLeases() async* {
    try {
      while (!_terminal) {
        final result = await _reader.read().toDart;
        if (result.done) break;
        if (result.value case final value?) {
          yield BinaryPayloadLease.fromBytes(_bytesFromJs(value));
        }
      }
    } finally {
      _terminal = true;
      _reader.releaseLock();
    }
  }

  Future<void> _stop([int errorCode = 0]) async {
    if (_terminal) return;
    _checkBrowserStreamErrorCode(errorCode);
    _terminal = true;
    try {
      await _reader.cancel(_streamError(errorCode)).toDart;
    } finally {
      _reader.releaseLock();
    }
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

web.WebTransportError _streamError(int errorCode) => web.WebTransportError(
  'WebTransport stream closed locally.',
  web.WebTransportErrorOptions(source: 'stream', streamErrorCode: errorCode),
);

void _checkBrowserStreamErrorCode(int errorCode) {
  RangeError.checkValueInInterval(errorCode, 0, 255, 'errorCode');
}

Uint8List _bytesFromJs(JSAny value) {
  if (value.isA<JSUint8Array>()) {
    return (value as JSUint8Array).toDart;
  }
  if (value.isA<JSArrayBuffer>()) {
    return (value as JSArrayBuffer).toDart.asUint8List();
  }
  throw DartEdgeWebTransportException(
    'Unsupported WebTransport payload: ${value.runtimeType}.',
  );
}
