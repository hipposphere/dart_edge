import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_edge_core/dart_edge_core.dart';

import '../native/dart_edge_native.dart';
import 'compiled_route_table.dart';
import 'dart_edge_codec.dart';
import 'dart_edge_server.dart';
import 'open_api_document.dart';
import 'request_decoder.dart';
import 'response_writer.dart';
import 'rust_middleware.dart';

/// Main application object for a Dart Edge server.
///
/// A [DartEdge] instance owns the route registry, service factory, optional
/// JSON Schema registry, and native middleware configuration for one server.
class DartEdge<TServices> extends Router<TServices> {
  /// Creates a new application instance.
  DartEdge({
    this.services,
    List<RustMiddleware>? middlewares,
    DartEdgeCodecRegistry codecs = DartEdgeCodecRegistry.empty,
  }) : middlewares = List.unmodifiable(middlewares ?? const <RustMiddleware>[]),
       _codecRegistry = codecs;

  /// Factory used to build request-scoped services.
  final TServices Function()? services;

  /// Native middleware configuration applied before requests reach Dart.
  final List<RustMiddleware> middlewares;

  /// Application-level OpenAPI metadata attached to the app.
  final OpenApiDocument openApiDocument = OpenApiDocument();
  JsonSchemaRegistry? _schemaRegistry;
  DartEdgeCodecRegistry _codecRegistry;
  _RustTransportSession? _session;

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
    return openApiDocument.toJson(
      routes: _compileRoutes().routes,
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
      onRequestReady: (requestId) async {
        await _handleTransportRequest(requestId, compiledRoutes);
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
      },
    );
  }

  Future<void> _handleTransportRequest(
    int requestId,
    CompiledRouteTable<TServices> compiledRoutes,
  ) async {
    final request = DartEdgeNative.takeRequest(requestId);
    if (request == null) {
      return;
    }

    final compiledRoute = compiledRoutes.routesById[request.routeId];
    if (compiledRoute == null) {
      final response = encodeServerError();
      DartEdgeNative.tryRespond(
        requestId,
        status: response.status,
        contentType: response.contentType,
        body: response.body,
        headers: response.headers,
      );
      return;
    }

    try {
      final input = await decodeRequestInput(
        request,
        codecs: _codecRegistry,
        paramsSchemaId: compiledRoute.contract.options.params?.id,
        querySchemaId: compiledRoute.contract.options.query?.id,
        headersSchemaId: compiledRoute.contract.options.headers?.id,
        body: compiledRoute.contract.options.body,
      );
      final ctx = RequestContext<TServices>(
        services: _createServices(),
        req: input,
      );
      for (final guard in compiledRoute.guards) {
        final decision = await Future.sync(() => guard.authorize(ctx));
        if (!decision.isAllowed) {
          final response = encodeResponse(
            spec: compiledRoute.contract.responses.success,
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
      final response = encodeResponse(
        spec: compiledRoute.contract.responses.success,
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
    } catch (error, stackTrace) {
      stderr.writeln(
        'dart_edge_http_server_runtime request handling failed for '
        '${compiledRoute.contract.options.operationId!}: $error',
      );
      stderr.writeln(stackTrace);
      final response = encodeServerError();
      DartEdgeNative.tryRespond(
        requestId,
        status: response.status,
        contentType: response.contentType,
        body: response.body,
        headers: response.headers,
      );
    }
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

typedef _NativeRequestReady = Void Function(Int64);

final class _RustTransportSession {
  _RustTransportSession._({
    required this.host,
    required this.port,
    required this.callback,
  });

  final String host;
  final int port;
  final NativeCallable<_NativeRequestReady> callback;
  var _closed = false;

  static Future<_RustTransportSession> start({
    required String host,
    required int requestedPort,
    required int workers,
    required String routesJson,
    required Future<void> Function(int requestId) onRequestReady,
  }) async {
    late final NativeCallable<_NativeRequestReady> callback;

    void handleRequestReady(int requestId) {
      unawaited(onRequestReady(requestId));
    }

    callback = NativeCallable<_NativeRequestReady>.listener(handleRequestReady);
    final port = DartEdgeNative.startServer(
      host,
      requestedPort,
      workers: workers,
      routesJson: routesJson,
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
