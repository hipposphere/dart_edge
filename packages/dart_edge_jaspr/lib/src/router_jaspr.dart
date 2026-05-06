import 'dart:async';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:jaspr/jaspr.dart' show Component;

import 'jaspr_renderer.dart';

/// Route handler signature for Jaspr-backed HTML endpoints.
typedef JasprComponentHandler<TServices> =
    FutureOr<Component> Function(RequestContext<TServices> ctx);

/// HTML route helpers backed by Jaspr component rendering.
extension JasprRouterExtensions<TServices> on Router<TServices> {
  /// Registers an inline `GET` Jaspr handler.
  void getJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.get,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }

  /// Registers an inline `POST` Jaspr handler.
  void postJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.post,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }

  /// Registers an inline `PUT` Jaspr handler.
  void putJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.put,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }

  /// Registers an inline `PATCH` Jaspr handler.
  void patchJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.patch,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }

  /// Registers an inline `DELETE` Jaspr handler.
  void deleteJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.delete,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }

  /// Registers an inline `HEAD` Jaspr handler.
  void headJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.head,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }

  /// Registers an inline `OPTIONS` Jaspr handler.
  void optionsJaspr(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    List<HttpHeader> headers = const <HttpHeader>[],
    bool standalone = false,
    required JasprComponentHandler<TServices> handler,
  }) {
    _registerJasprRoute(
      this,
      method: HttpMethod.options,
      path: path,
      options: options,
      guards: guards,
      headers: headers,
      standalone: standalone,
      handler: handler,
    );
  }
}

void _registerJasprRoute<TServices>(
  Router<TServices> router, {
  required HttpMethod method,
  required String path,
  required RouteOptions options,
  required JasprComponentHandler<TServices> handler,
  List<Guard<TServices>>? guards,
  List<HttpHeader> headers = const <HttpHeader>[],
  required bool standalone,
}) {
  final normalizedOptions = _normalizeJasprOptions(options);

  Future<RawResponse> render(RequestContext<TServices> ctx) async {
    final component = await Future.sync(() => handler(ctx));
    return JasprRenderer.html(
      component,
      status: normalizedOptions.success!.status,
      headers: headers,
      standalone: standalone,
    );
  }

  switch (method) {
    case HttpMethod.get:
      router.get<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
    case HttpMethod.post:
      router.post<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
    case HttpMethod.put:
      router.put<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
    case HttpMethod.patch:
      router.patch<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
    case HttpMethod.delete:
      router.delete<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
    case HttpMethod.head:
      router.head<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
    case HttpMethod.options:
      router.options<RawResponse>(
        path,
        options: normalizedOptions,
        guards: guards,
        handler: render,
      );
  }
}

RouteOptions _normalizeJasprOptions(RouteOptions options) {
  final successStatus = options.success?.status ?? 200;
  return RouteOptions(
    operationId: options.operationId,
    summary: options.summary,
    tags: options.tags,
    deprecated: options.deprecated,
    exposure: options.exposure,
    params: options.params,
    query: options.query,
    headers: options.headers,
    body: options.body,
    success: ResponseSpec.html(status: successStatus),
    errors: options.errors,
  );
}
