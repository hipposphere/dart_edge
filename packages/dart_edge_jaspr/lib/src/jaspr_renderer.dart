import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:jaspr/dom.dart' show StyleRule;
import 'package:jaspr/jaspr.dart' show Component;
import 'package:jaspr/server.dart'
    as jaspr_server
    show Jaspr, Request, renderComponent, Document;

typedef _RenderedJasprResponse = ({
  int statusCode,
  Uint8List body,
  Map<String, List<String>> headers,
});

/// Renders Jaspr components into HTML strings or Dart Edge raw responses.
///
/// This package auto-initializes Jaspr with default server options on first use
/// so server-side rendering works out of the box for HTML pages, previews, and
/// email markup. Applications that need custom Jaspr server options can
/// initialize Jaspr explicitly before calling these helpers.
final class JasprRenderer {
  const JasprRenderer._();

  /// Ensures Jaspr has been initialized for server-side rendering.
  static void ensureInitialized() {
    if (!jaspr_server.Jaspr.isInitialized) {
      jaspr_server.Jaspr.initializeApp();
    }
  }

  /// Renders [component] to an HTML string.
  ///
  /// When [standalone] is `false`, Jaspr produces a full HTML document. When it
  /// is `true`, only the component subtree is rendered.
  static Future<String> renderString(
    Component component, {
    jaspr_server.Request? request,
    bool standalone = false,
  }) async {
    final rendered = await _render(
      component,
      request: request,
      standalone: standalone,
    );
    return utf8.decode(rendered.body);
  }

  /// Renders [component] into a Dart Edge `text/html` response.
  ///
  /// If [status] is omitted, Jaspr's rendered response status is preserved.
  static Future<RawResponse> html(
    Component component, {
    int? status,
    List<HttpHeader> headers = const <HttpHeader>[],
    jaspr_server.Request? request,
    bool standalone = false,
  }) async {
    final rendered = await _render(
      component,
      request: request,
      standalone: standalone,
    );
    return RawResponse.encoded(
      status: status ?? rendered.statusCode,
      contentType: 'text/html; charset=utf-8',
      body: utf8.decode(rendered.body),
      headers: [..._flattenHeaders(rendered.headers), ...headers],
    );
  }

  /// Builds a Jaspr `Document` and renders it as a Dart Edge HTML response.
  static Future<RawResponse> document({
    String? title,
    String? lang,
    String? base,
    String? charset,
    String? viewport,
    Map<String, String> meta = const <String, String>{},
    List<StyleRule> styles = const <StyleRule>[],
    List<Component> head = const <Component>[],
    required Component body,
    int? status,
    List<HttpHeader> headers = const <HttpHeader>[],
    jaspr_server.Request? request,
  }) {
    return html(
      jaspr_server.Document(
        title: title,
        lang: lang,
        base: base,
        charset: charset,
        viewport: viewport,
        meta: meta,
        styles: styles,
        head: head,
        body: body,
      ),
      status: status,
      headers: headers,
      request: request,
    );
  }

  static Future<_RenderedJasprResponse> _render(
    Component component, {
    jaspr_server.Request? request,
    required bool standalone,
  }) async {
    ensureInitialized();
    return jaspr_server.renderComponent(
      component,
      request: request,
      standalone: standalone,
    );
  }
}

List<HttpHeader> _flattenHeaders(Map<String, List<String>> headers) {
  final flattened = <HttpHeader>[];
  for (final entry in headers.entries) {
    for (final value in entry.value) {
      flattened.add(HttpHeader(entry.key, value));
    }
  }
  return flattened;
}
