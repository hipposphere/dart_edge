import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Optional hook that can replace a completed Shelf response.
typedef ShelfResponseFallback<TServices> =
    FutureOr<RawResponse?> Function(
      RequestContext<TServices> ctx,
      RawResponse response,
    );

/// Adapts Shelf handlers so they can be mounted on a Dart Edge router.
extension ShelfRouterExtensions<TServices> on Router<TServices> {
  /// Mounts [handler] on every [methods] using one catch-all [path].
  ///
  /// The default [path] uses Dart Edge's final wildcard segment syntax and
  /// forwards `/`, static assets, and nested routes to the same Shelf handler.
  void mountShelfHandler(
    shelf.Handler handler, {
    String path = '/<shelfPath*>',
    Iterable<HttpMethod> methods = HttpMethod.values,
    RouteOptions Function(HttpMethod method, String path)? routeOptions,
    List<Guard<TServices>>? guards,
    String? handlerPath,
    ShelfResponseFallback<TServices>? fallback,
  }) {
    for (final method in methods) {
      final routeOptionsValue =
          routeOptions?.call(method, path) ??
          RouteOptions(
            operationId: _operationId(method, path),
            summary: 'Forward ${method.wireName} $path to a Shelf handler.',
            exposure: RouteExposure.none,
            success: const ResponseSpec.binary(),
          );
      Future<RawResponse> routeHandler(RequestContext<TServices> ctx) {
        return _handleShelfRequest(
          handler,
          ctx,
          method: method,
          path: path,
          handlerPath: handlerPath,
          fallback: fallback,
        );
      }

      switch (method) {
        case HttpMethod.get:
          get<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
        case HttpMethod.post:
          post<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
        case HttpMethod.put:
          put<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
        case HttpMethod.patch:
          patch<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
        case HttpMethod.delete:
          delete<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
        case HttpMethod.head:
          head<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
        case HttpMethod.options:
          options<RawResponse>(
            path,
            options: routeOptionsValue,
            guards: guards,
            handler: routeHandler,
          );
      }
    }
  }
}

Future<RawResponse> _handleShelfRequest<TServices>(
  shelf.Handler handler,
  RequestContext<TServices> ctx, {
  required HttpMethod method,
  required String path,
  required String? handlerPath,
  required ShelfResponseFallback<TServices>? fallback,
}) async {
  final request = _shelfRequestFor(
    ctx,
    method: method,
    path: path,
    handlerPath: handlerPath,
  );
  final response = await Future.value(handler(request));
  final rawResponse = await _rawResponse(response);
  return await fallback?.call(ctx, rawResponse) ?? rawResponse;
}

shelf.Request _shelfRequestFor<TServices>(
  RequestContext<TServices> ctx, {
  required HttpMethod method,
  required String path,
  required String? handlerPath,
}) {
  final uri = Uri.http(
    ctx.req.header('host') ?? 'localhost',
    _pathForRequest(path, ctx.req.paramsMap),
    ctx.req.queryMap.isEmpty ? null : ctx.req.queryMap,
  );
  return shelf.Request(
    method.wireName,
    uri,
    headers: ctx.req.headersMap,
    handlerPath: handlerPath,
    body: _requestBody(ctx),
  );
}

Object? _requestBody<TServices>(RequestContext<TServices> ctx) {
  final nativeBody = ctx.req.nativeBody;
  if (nativeBody != null) {
    return nativeBody.copyBytes();
  }

  return switch (ctx.req.bodyOrNull) {
    final Uint8List body => body,
    final List<int> body => body,
    final String body => body,
    final Object body => utf8.encode(jsonEncode(body)),
    null => null,
  };
}

String _pathForRequest(String path, Map<String, String> params) {
  var resolved = path.isEmpty ? '/' : path;
  for (final entry in params.entries) {
    resolved = resolved
        .replaceAll(':${entry.key}*', entry.value)
        .replaceAll(':${entry.key}', entry.value)
        .replaceAll('<${entry.key}*>', entry.value)
        .replaceAll('<${entry.key}>', entry.value);
  }
  return resolved;
}

Future<RawResponse> _rawResponse(shelf.Response response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response.read()) {
    builder.add(chunk);
  }

  final contentType =
      response.headers['content-type'] ?? 'application/octet-stream';
  final headers = <HttpHeader>[];
  for (final entry in response.headers.entries) {
    final name = entry.key.toLowerCase();
    if (name == 'content-type' || name == 'content-length') {
      continue;
    }
    headers.add(HttpHeader(entry.key, entry.value));
  }

  return RawResponse.binary(
    status: response.statusCode,
    contentType: contentType,
    body: builder.takeBytes(),
    headers: headers,
  );
}

String _operationId(HttpMethod method, String path) {
  final words = path
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(_capitalize)
      .join();
  return words.isEmpty ? '${method.name}Shelf' : '${method.name}Shelf$words';
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
