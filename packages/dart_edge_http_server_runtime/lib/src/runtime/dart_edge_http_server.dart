import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_edge_core/dart_edge_core.dart';

import '../native/dart_edge_native.dart';
import '../native/native_transport_web_socket.dart';
import 'compiled_route_table.dart';
import 'dart_edge_codec.dart';
import 'dart_edge_server.dart';
import 'json_schema_route_id.dart';
import 'open_api_document.dart';
import 'request_decoder.dart';
import 'response_writer.dart';
import 'rust_middleware.dart';
import 'transport_request.dart';

const _transportEventRequestReady = 1;
const _transportEventWebSocketOpened = 2;
const _transportEventWebSocketMessageReady = 3;
const _transportEventWebSocketClosed = 4;

/// Main application object for a Dart Edge server.
///
/// A [DartEdge] instance owns the route registry, service factory, optional
/// JSON Schema registry, and native middleware configuration for one server.
class DartEdge<TServices> extends Router<TServices> {
  /// Creates a new application instance.
  DartEdge({
    this.services,
    OpenApiDocument? openApiDocument,
    List<RustMiddleware>? middlewares,
    DartEdgeCodecRegistry codecs = DartEdgeCodecRegistry.empty,
  }) : middlewares = List.unmodifiable(middlewares ?? const <RustMiddleware>[]),
       openApiDocument = openApiDocument ?? OpenApiDocument(),
       _codecRegistry = codecs;

  /// Factory used to build request-scoped services.
  final TServices Function()? services;

  /// Native middleware configuration applied before requests reach Dart.
  final List<RustMiddleware> middlewares;

  /// Application-level OpenAPI metadata attached to the app.
  final OpenApiDocument openApiDocument;
  JsonSchemaRegistry? _schemaRegistry;
  DartEdgeCodecRegistry _codecRegistry;
  _RustTransportSession? _session;
  final Map<int, RequestContext<TServices>> _pendingWebSocketContexts =
      <int, RequestContext<TServices>>{};
  final Map<int, _ActiveWebSocketSession> _activeWebSocketSessions =
      <int, _ActiveWebSocketSession>{};

  /// Installed JSON Schema registry used for validation and manifests.
  JsonSchemaRegistry? get schemaRegistry => _schemaRegistry;

  /// Installed runtime codec registry used for request decoding.
  DartEdgeCodecRegistry get codecRegistry => _codecRegistry;

  /// Installs the JSON Schema registry for this app.
  void installSchemaRegistry(JsonSchemaRegistry registry) {
    _schemaRegistry = registry;
  }

  /// Installs the runtime codec registry for this app.
  void installCodecRegistry(DartEdgeCodecRegistry registry) {
    _codecRegistry = registry;
  }

  /// Builds the current OpenAPI JSON document for the registered routes.
  Map<String, Object?> buildOpenApiDocumentJson() {
    final compiledRoutes = _compileRoutes();
    return openApiDocument.toJson(
      routes: [
        ...compiledRoutes.routes.where(
          (route) => route.options.exposure.openApi,
        ),
        ...compiledRoutes.nativeRoutes.where(
          (route) => route.options.exposure.openApi,
        ),
      ],
      schemaRegistry: _schemaRegistry,
    );
  }

  /// Starts the native HTTP server and begins handling requests.
  ///
  /// [host] controls the bind address used by the native listener. Keep the
  /// default loopback host for local-only development, or pass `0.0.0.0` /
  /// `::` when deploying behind a reverse proxy or in a container.
  ///
  /// When [port] is `0`, the runtime binds an ephemeral free port and returns
  /// the chosen port via the resulting [DartEdgeServer].
  Future<DartEdgeServer> listen({
    String host = '127.0.0.1',
    required int port,
    int workers = 1,
  }) async {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Must not be empty.');
    }

    RangeError.checkNotNegative(workers, 'workers');
    if (workers == 0) {
      throw RangeError.value(workers, 'workers', 'Must be greater than zero.');
    }

    final existingSession = _session;
    if (existingSession != null) {
      throw StateError(
        'DartEdge is already listening on ${existingSession.host}:${existingSession.port}.',
      );
    }

    final compiledRoutes = _compileRoutes();

    final session = await _RustTransportSession.start(
      host: normalizedHost,
      requestedPort: port,
      workers: workers,
      routesJson: compiledRoutes.nativeManifestJson(
        schemaRegistry: _schemaRegistry,
      ),
      middlewaresJson: _middlewaresJson(middlewares),
      onTransportEvent: (eventKind, eventId) async {
        await _handleTransportEvent(eventKind, eventId, compiledRoutes);
      },
    );
    _session = session;

    return DartEdgeServer(
      host: session.host,
      port: session.port,
      onClose: () async {
        final currentSession = _session;
        if (currentSession == null) {
          return;
        }
        _session = null;
        await currentSession.close();
        _pendingWebSocketContexts.clear();
        for (final session in _activeWebSocketSessions.values.toList()) {
          await session.messages.close();
        }
        _activeWebSocketSessions.clear();
      },
    );
  }

  Future<void> _handleTransportEvent(
    int eventKind,
    int eventId,
    CompiledRouteTable<TServices> compiledRoutes,
  ) async {
    switch (eventKind) {
      case _transportEventRequestReady:
        await _handleTransportRequest(eventId, compiledRoutes);
        return;
      case _transportEventWebSocketOpened:
        await _handleWebSocketOpened(eventId, compiledRoutes);
        return;
      case _transportEventWebSocketMessageReady:
        _drainWebSocketMessages(eventId);
        return;
      case _transportEventWebSocketClosed:
        await _handleWebSocketClosed(eventId);
        return;
    }
  }

  Future<void> _handleTransportRequest(
    int requestId,
    CompiledRouteTable<TServices> compiledRoutes,
  ) async {
    final requestLease = DartEdgeNative.takeRequest(requestId);
    if (requestLease == null) {
      return;
    }
    final request = requestLease.request;
    final operationId = _transportOperationId(request, compiledRoutes);

    try {
      switch (request.requestKind) {
        case TransportRequestKind.http:
          await _handleHttpRequest(requestId, requestLease, compiledRoutes);
          return;
        case TransportRequestKind.webSocket:
          await _handleWebSocketHandshake(
            requestId,
            requestLease,
            compiledRoutes,
          );
          return;
      }
    } catch (error, stackTrace) {
      stderr.writeln(
        'dart_edge_http_server_runtime request handling failed for '
        '$operationId: $error',
      );
      stderr.writeln(stackTrace);
      _respondServerError(requestId);
    } finally {
      requestLease.dispose();
    }
  }

  Future<void> _handleHttpRequest(
    int requestId,
    NativeTransportRequestLease requestLease,
    CompiledRouteTable<TServices> compiledRoutes,
  ) async {
    final request = requestLease.request;
    final compiledRoute = compiledRoutes.routesById[request.routeId];
    if (compiledRoute == null) {
      _respondServerError(requestId);
      return;
    }

    final input = await decodeRequestInput(
      request,
      codecs: _codecRegistry,
      nativeRequest: requestLease.nativeRequest,
      paramsSchemaId: jsonSchemaRouteId(compiledRoute.options.params),
      querySchemaId: jsonSchemaRouteId(compiledRoute.options.query),
      headersSchemaId: jsonSchemaRouteId(compiledRoute.options.headers),
      paramsDecoder: compiledRoute.options.paramsDecoder,
      queryDecoder: compiledRoute.options.queryDecoder,
      body: compiledRoute.options.body,
    );
    final ctx = RequestContext<TServices>(
      services: _createServices(),
      req: input,
    );
    for (final guard in compiledRoute.guards) {
      final decision = await Future.sync(() => guard.authorize(ctx));
      if (!decision.isAllowed) {
        final response = encodeResponse(
          spec: compiledRoute.options.responses.success,
          body: decision.response,
          response: ctx.res,
        );
        DartEdgeNative.tryRespond(
          requestId,
          status: response.status,
          contentType: response.contentType,
          body: response.body,
          headers: response.headers,
        );
        return;
      }
    }

    final body = await Future.sync(() => compiledRoute.route.handle(ctx));
    final sseResponse = _resolveSseResponse(body, ctx.res);
    if (sseResponse != null) {
      await _streamSseResponse(requestId, sseResponse);
      return;
    }

    final response = encodeResponse(
      spec: compiledRoute.options.responses.success,
      body: body,
      response: ctx.res,
    );

    DartEdgeNative.tryRespond(
      requestId,
      status: response.status,
      contentType: response.contentType,
      body: response.body,
      headers: response.headers,
    );
  }

  Future<void> _handleWebSocketHandshake(
    int requestId,
    NativeTransportRequestLease requestLease,
    CompiledRouteTable<TServices> compiledRoutes,
  ) async {
    final request = requestLease.request;
    final compiledRoute = compiledRoutes.webSocketRoutesById[request.routeId];
    if (compiledRoute == null) {
      _respondServerError(requestId);
      return;
    }

    final input = await decodeRequestInput(
      request,
      codecs: _codecRegistry,
      nativeRequest: null,
      paramsSchemaId: null,
      querySchemaId: null,
      headersSchemaId: null,
      body: null,
    );
    final ctx = RequestContext<TServices>(
      services: _createServices(),
      req: input,
    );
    for (final guard in compiledRoute.guards) {
      final decision = await Future.sync(() => guard.authorize(ctx));
      if (!decision.isAllowed) {
        final response = encodeResponse(
          spec: ResponseSpec.text(),
          body: decision.response,
          response: ctx.res,
        );
        DartEdgeNative.tryRespond(
          requestId,
          status: response.status,
          contentType: response.contentType,
          body: response.body,
          headers: response.headers,
        );
        return;
      }
    }

    _pendingWebSocketContexts[requestId] = ctx;
    final accepted = DartEdgeNative.acceptWebSocket(
      requestId,
      headers: ctx.res.headers,
    );
    if (!accepted) {
      _pendingWebSocketContexts.remove(requestId);
      _respondServerError(requestId);
    }
  }

  Future<void> _handleWebSocketOpened(
    int sessionId,
    CompiledRouteTable<TServices> compiledRoutes,
  ) async {
    final connection = DartEdgeNative.takeWebSocketConnection(sessionId);
    if (connection == null) {
      return;
    }

    final compiledRoute =
        compiledRoutes.webSocketRoutesById[connection.routeId];
    if (compiledRoute == null) {
      DartEdgeNative.webSocketClose(
        sessionId,
        reason: 'No Dart WebSocket route registered for ${connection.routeId}.',
      );
      return;
    }

    final requestContext =
        _pendingWebSocketContexts.remove(connection.requestId) ??
        RequestContext<TServices>(
          services: _createServices(),
          req: RequestInput(
            params: Map<String, String>.unmodifiable(connection.pathParams),
            query: Map<String, String>.unmodifiable(connection.query),
            headers: Map<String, String>.unmodifiable(connection.headers),
          ),
        );

    final activeSession = _ActiveWebSocketSession(
      StreamController<WebSocketMessage>(),
    );
    _activeWebSocketSessions[sessionId] = activeSession;

    final socket = WebSocketContext<TServices>.fromRequest(
      request: requestContext,
      messages: IncomingWebSocketMessages(activeSession.messages.stream),
      sendText: (value) => _sendWebSocketText(sessionId, value),
      sendBinary: (value) => _sendWebSocketBinary(sessionId, value),
      sendJson: (value) => _sendWebSocketJson(sessionId, value),
      close: ([code, reason]) async {
        DartEdgeNative.webSocketClose(sessionId, code: code, reason: reason);
      },
    );

    activeSession.task =
        Future.sync(() => compiledRoute.route.onConnect(socket))
            .catchError((Object error, StackTrace stackTrace) {
              stderr.writeln(
                'dart_edge_http_server_runtime websocket handling failed for '
                '${compiledRoute.options.operationId}: $error',
              );
              stderr.writeln(stackTrace);
            })
            .whenComplete(() async {
              final session = _activeWebSocketSessions.remove(sessionId);
              await session?.messages.close();
              DartEdgeNative.webSocketClose(sessionId);
            });

    _drainWebSocketMessages(sessionId);
  }

  void _drainWebSocketMessages(int sessionId) {
    final session = _activeWebSocketSessions[sessionId];
    if (session == null || session.messages.isClosed) {
      return;
    }

    while (true) {
      final message = DartEdgeNative.takeWebSocketMessage(sessionId);
      if (message == null) {
        return;
      }
      session.messages.add(_decodeWebSocketMessage(message));
    }
  }

  Future<void> _handleWebSocketClosed(int sessionId) async {
    final session = _activeWebSocketSessions.remove(sessionId);
    await session?.messages.close();
  }

  SseResponse? _resolveSseResponse(Object? body, ResponseBuilder response) {
    if (body case final SseResponse response) {
      return response;
    }

    final override = response.hasBodyOverride ? response.bodyOverride : null;
    return override is SseResponse ? override : null;
  }

  Future<void> _streamSseResponse(int requestId, SseResponse response) async {
    final started = DartEdgeNative.startSseResponse(
      requestId,
      status: response.status,
      headers: _defaultSseHeaders(response.headers),
    );
    if (!started) {
      return;
    }

    try {
      await for (final event in response.events) {
        if (!DartEdgeNative.sendSseChunk(requestId, event.encode())) {
          break;
        }
      }
    } finally {
      DartEdgeNative.finishSseResponse(requestId);
    }
  }

  List<HttpHeader> _defaultSseHeaders(List<HttpHeader> headers) {
    final hasCacheControl = headers.any(
      (header) => header.name.toLowerCase() == 'cache-control',
    );
    final hasBufferingHint = headers.any(
      (header) => header.name.toLowerCase() == 'x-accel-buffering',
    );

    return [
      ...headers,
      if (!hasCacheControl) const HttpHeader('Cache-Control', 'no-cache'),
      if (!hasBufferingHint) const HttpHeader('X-Accel-Buffering', 'no'),
    ];
  }

  String _transportOperationId(
    TransportRequest request,
    CompiledRouteTable<TServices> compiledRoutes,
  ) {
    return switch (request.requestKind) {
          TransportRequestKind.http =>
            compiledRoutes.routesById[request.routeId]?.options.operationId,
          TransportRequestKind.webSocket =>
            compiledRoutes
                .webSocketRoutesById[request.routeId]
                ?.options
                .operationId,
        } ??
        request.routeId;
  }

  void _respondServerError(int requestId) {
    final response = encodeServerError();
    DartEdgeNative.tryRespond(
      requestId,
      status: response.status,
      contentType: response.contentType,
      body: response.body,
      headers: response.headers,
    );
  }

  TServices _createServices() {
    final factory = services;
    if (factory != null) {
      return factory();
    }

    if (null is TServices) {
      return null as TServices;
    }

    throw StateError(
      'No services factory configured. Pass services: () => ... to DartEdge.',
    );
  }

  CompiledRouteTable<TServices> _compileRoutes() {
    return CompiledRouteTable.fromRegistrations(routeRegistry.registrations);
  }
}

Object? _normalizeWebSocketJson(Object? value) {
  switch (value) {
    case null:
    case bool():
    case num():
    case String():
      return value;
    case List():
      return value.map(_normalizeWebSocketJson).toList(growable: false);
    case Map():
      return {
        for (final entry in value.entries)
          entry.key.toString(): _normalizeWebSocketJson(entry.value),
      };
    case JsonEncodable():
      return _normalizeWebSocketJson(value.toJson());
    default:
      throw StateError(
        'WebSocket payload of type ${value.runtimeType} is not JSON encodable.',
      );
  }
}

Future<void> _sendWebSocketText(int sessionId, String value) async {
  if (!DartEdgeNative.webSocketSendText(sessionId, value)) {
    throw StateError('Failed to send WebSocket text frame for $sessionId.');
  }
}

Future<void> _sendWebSocketBinary(int sessionId, List<int> value) async {
  if (!DartEdgeNative.webSocketSendBinary(sessionId, value)) {
    throw StateError('Failed to send WebSocket binary frame for $sessionId.');
  }
}

Future<void> _sendWebSocketJson(int sessionId, Object? value) async {
  final encoded = jsonEncode(_normalizeWebSocketJson(value));
  if (!DartEdgeNative.webSocketSendText(sessionId, encoded)) {
    throw StateError('Failed to send WebSocket JSON frame for $sessionId.');
  }
}

WebSocketMessage _decodeWebSocketMessage(NativeWebSocketMessage message) {
  return switch (message.kind) {
    NativeWebSocketMessageKind.text => WebSocketMessage.text(
      utf8.decode(message.body),
    ),
    NativeWebSocketMessageKind.binary => WebSocketMessage.binary(message.body),
  };
}

typedef _NativeTransportEvent = Void Function(Int32, Int64);

final class _RustTransportSession {
  _RustTransportSession._({
    required this.host,
    required this.port,
    required this.callback,
  });

  final String host;
  final int port;
  final NativeCallable<_NativeTransportEvent> callback;
  var _closed = false;

  static Future<_RustTransportSession> start({
    required String host,
    required int requestedPort,
    required int workers,
    required String routesJson,
    required String middlewaresJson,
    required Future<void> Function(int eventKind, int eventId) onTransportEvent,
  }) async {
    late final NativeCallable<_NativeTransportEvent> callback;

    void handleTransportEvent(int eventKind, int eventId) {
      unawaited(onTransportEvent(eventKind, eventId));
    }

    callback = NativeCallable<_NativeTransportEvent>.listener(
      handleTransportEvent,
    );
    final port = DartEdgeNative.startServer(
      host,
      requestedPort,
      workers: workers,
      routesJson: routesJson,
      middlewaresJson: middlewaresJson,
      callback: callback.nativeFunction,
    );
    if (port <= 0) {
      callback.close();
      throw StateError('Failed to start Rust-backed transport runtime.');
    }

    return _RustTransportSession._(host: host, port: port, callback: callback);
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    DartEdgeNative.stopServer();
    callback.close();
  }
}

String _middlewaresJson(List<RustMiddleware> middlewares) {
  return jsonEncode({
    'middlewares': middlewares.map(_middlewareJson).toList(growable: false),
  });
}

Map<String, Object?> _middlewareJson(RustMiddleware middleware) {
  return {
    'name': middleware.name,
    if (middleware.configuration case final configuration?)
      'configuration': _middlewareConfigurationJson(configuration),
  };
}

Map<String, Object?> _middlewareConfigurationJson(
  RustMiddlewareConfiguration configuration,
) {
  return switch (configuration) {
    RustCorsMiddlewareConfiguration() => {
      'allowOrigins': configuration.allowOrigins,
      'allowHeaders': configuration.allowHeaders,
    },
    RustTracingMiddlewareConfiguration() => {
      if (configuration.openTelemetry case final openTelemetry?)
        'openTelemetry': {
          'serviceName': openTelemetry.serviceName,
          'endpoint': openTelemetry.endpoint,
        },
    },
    RustBodyLimitMiddlewareConfiguration() => {
      'maxBytes': configuration.maxBytes,
    },
  };
}

final class _ActiveWebSocketSession {
  _ActiveWebSocketSession(this.messages);

  final StreamController<WebSocketMessage> messages;
  Future<void>? task;
}
