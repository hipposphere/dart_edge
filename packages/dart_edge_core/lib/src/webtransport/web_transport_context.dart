import 'dart:typed_data';

import '../context/request_context.dart';
import '../context/request_input.dart';
import '../context/request_telemetry.dart';
import 'incoming_web_transport_datagrams.dart';
import 'incoming_web_transport_streams.dart';

typedef WebTransportDatagramSender = Future<void> Function(List<int> value);
typedef WebTransportStreamSender = Future<void> Function(List<int> value);
typedef WebTransportCloser = Future<void> Function([int? code, String? reason]);

/// Context passed to a WebTransport route when a client connects.
final class WebTransportContext<TServices> {
  WebTransportContext({
    required this.services,
    this.req = RequestInput.empty,
    this.datagrams = const IncomingWebTransportDatagrams(),
    this.streams = const IncomingWebTransportStreams(),
    this.telemetry = const RequestTelemetry(),
    WebTransportDatagramSender? sendDatagram,
    WebTransportStreamSender? sendStream,
    WebTransportCloser? close,
  }) : _requestContext = RequestContext<TServices>(
         services: services,
         req: req,
         telemetry: telemetry,
       ),
       _sendDatagram = sendDatagram,
       _sendStream = sendStream,
       _close = close;

  WebTransportContext.fromRequest({
    required RequestContext<TServices> request,
    this.datagrams = const IncomingWebTransportDatagrams(),
    this.streams = const IncomingWebTransportStreams(),
    WebTransportDatagramSender? sendDatagram,
    WebTransportStreamSender? sendStream,
    WebTransportCloser? close,
  }) : services = request.services,
       req = request.req,
       telemetry = request.telemetry,
       _requestContext = request,
       _sendDatagram = sendDatagram,
       _sendStream = sendStream,
       _close = close;

  /// Fresh services instance for the WebTransport session.
  final TServices services;

  /// Decoded request params, query, and headers for the CONNECT request.
  final RequestInput req;

  /// Incoming unreliable datagrams.
  final IncomingWebTransportDatagrams datagrams;

  /// Incoming reliable stream payloads.
  final IncomingWebTransportStreams streams;

  /// Telemetry hook associated with the session lifecycle.
  final RequestTelemetry telemetry;

  final RequestContext<TServices> _requestContext;
  final WebTransportDatagramSender? _sendDatagram;
  final WebTransportStreamSender? _sendStream;
  final WebTransportCloser? _close;

  /// Shared request-scoped context used during guard evaluation.
  RequestContext<TServices> get request => _requestContext;

  /// Reads a required request-scoped extension of type [T].
  T require<T>() => _requestContext.require<T>();

  /// Reads an optional request-scoped extension of type [T].
  T? maybe<T>() => _requestContext.maybe<T>();

  /// Stores a request-scoped extension by its runtime type.
  void put<T>(T value) {
    _requestContext.put<T>(value);
  }

  /// Sends one unreliable datagram to the client.
  Future<void> sendDatagram(List<int> value) async {
    final sendDatagram = _sendDatagram;
    if (sendDatagram == null) {
      return;
    }
    await sendDatagram(Uint8List.fromList(value));
  }

  /// Sends one reliable payload on a new unidirectional WebTransport stream.
  Future<void> sendStream(List<int> value) async {
    final sendStream = _sendStream;
    if (sendStream == null) {
      return;
    }
    await sendStream(Uint8List.fromList(value));
  }

  /// Closes the WebTransport session.
  Future<void> close([int? code, String? reason]) async {
    final close = _close;
    if (close == null) {
      return;
    }
    await close(code, reason);
  }
}
