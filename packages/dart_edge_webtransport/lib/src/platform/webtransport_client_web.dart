import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

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

    final transport = headers.isEmpty
        ? web.WebTransport(uri.toString())
        : web.WebTransport(
            uri.toString(),
            <String, Object?>{'headers': headers}.jsify()
                as web.WebTransportOptions,
          );

    await transport.ready.toDart;
    return _BrowserWebTransportSession(transport);
  }
}

final class _BrowserWebTransportSession implements DartEdgeWebTransportSession {
  _BrowserWebTransportSession(this._transport) {
    _writer = _transport.datagrams.writable.getWriter();
    _controller = StreamController<Uint8List>.broadcast(
      onListen: _startReadingDatagrams,
      onCancel: () {
        if (!_controller.hasListener) {
          _reader?.releaseLock();
          _reader = null;
        }
      },
    );
  }

  final web.WebTransport _transport;
  late final web.WritableStreamDefaultWriter _writer;
  late final StreamController<Uint8List> _controller;
  web.ReadableStreamDefaultReader? _reader;
  bool _reading = false;
  bool _closed = false;

  @override
  Stream<Uint8List> get datagrams => _controller.stream;

  @override
  Stream<Uint8List> get streams => const Stream<Uint8List>.empty();

  @override
  Future<void> sendDatagram(List<int> bytes) async {
    if (_closed) {
      throw const DartEdgeWebTransportException(
        'Cannot send a datagram on a closed WebTransport session.',
      );
    }
    await _writer.write(Uint8List.fromList(bytes).toJS).toDart;
  }

  @override
  Future<void> sendStream(List<int> bytes) {
    throw const DartEdgeWebTransportException(
      'Browser WebTransport reliable stream support is not wired yet.',
    );
  }

  @override
  Future<void> close({int code = 0, String reason = ''}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    _reader?.releaseLock();
    _writer.releaseLock();
    _transport.close(
      web.WebTransportCloseInfo(closeCode: code, reason: reason),
    );
    await _controller.close();
  }

  Future<void> _startReadingDatagrams() async {
    if (_reading || _closed) {
      return;
    }
    _reading = true;
    final web.ReadableStreamDefaultReader reader = _reader ??=
        _transport.datagrams.readable.getReader()
            as web.ReadableStreamDefaultReader;

    try {
      while (!_closed) {
        final result = await reader.read().toDart;
        if (result.done) {
          break;
        }
        final value = result.value;
        if (value == null) {
          continue;
        }
        _controller.add(_bytesFromJs(value));
      }
    } catch (error, stackTrace) {
      if (!_closed) {
        _controller.addError(error, stackTrace);
      }
    } finally {
      _reading = false;
      if (!_controller.isClosed) {
        await _controller.close();
      }
    }
  }
}

Uint8List _bytesFromJs(JSAny value) {
  if (value.isA<JSUint8Array>()) {
    return Uint8List.fromList((value as JSUint8Array).toDart);
  }
  if (value.isA<JSArrayBuffer>()) {
    return Uint8List.fromList((value as JSArrayBuffer).toDart.asUint8List());
  }
  throw DartEdgeWebTransportException(
    'Unsupported WebTransport datagram payload: ${value.runtimeType}.',
  );
}
