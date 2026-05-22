import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_router/jaspr_router.dart' as jaspr_router;
import 'package:test/test.dart';

void main() {
  const wiki = DartEdgeDocsWiki(
    title: 'Dart Edge',
    sections: [
      DartEdgeDocsSection(
        title: 'Guide',
        pages: [DartEdgeDocsPage(title: 'Overview', href: '/')],
      ),
    ],
  );

  test('includes fallback styles by default', () async {
    final html = await _renderHead(
      const DartEdgeDocsLayout(wiki: wiki, stylesheetHref: '/docs/styles.css'),
    );

    expect(html, contains('href="/docs/styles.css"'));
    expect(html, contains('[data-slot="breadcrumb-list"]'));
    expect(html, contains('--background: #ffffff'));
    expect(html, contains(':root[data-theme="dark"]'));
    expect(html, contains('dart_edge_docs_color_mode'));
  });

  test('can disable fallback styles for full Tailwind bundles', () async {
    final html = await _renderHead(
      const DartEdgeDocsLayout(
        wiki: wiki,
        stylesheetHref: '/docs/styles.css',
        includeFallbackStyles: false,
      ),
    );

    expect(html, contains('href="/docs/styles.css"'));
    expect(html, isNot(contains('[data-slot="breadcrumb-list"]')));
    expect(html, isNot(contains('--background: #ffffff')));
  });

  test('mounts docs pages and default assets on a Dart Edge router', () {
    final router = Router<void>();

    router.mountDartEdgeDocs(
      const DartEdgeDocsApp(wiki: wiki, stylesheetHref: '/docs/styles.css'),
      catchAllPath: '/docs/<dartEdgeDocsPath*>',
      handlerPath: '/docs',
    );

    final paths = {
      for (final registration in router.routeRegistry.registrations)
        registration.httpPath,
    };

    expect(paths, contains('/docs/<dartEdgeDocsPath*>'));
    expect(router.routeRegistry.registrations, hasLength(1));
  });

  test('accepts a jaspr_content template engine', () {
    final templateEngine = _NoopTemplateEngine();
    final app = DartEdgeDocsApp(wiki: wiki, templateEngine: templateEngine);

    expect(app.templateEngine, same(templateEngine));
  });

  test('renders color mode controls defaulting to system', () async {
    final html = await _renderBody(
      const DartEdgeDocsLayout(wiki: wiki, stylesheetHref: '/docs/styles.css'),
    );

    expect(html, contains('aria-label="Color mode"'));
    expect(html, contains('data-de-docs-theme-value="system"'));
    expect(html, contains('aria-pressed="true"'));
    expect(html, contains('data-de-docs-theme-value="light"'));
    expect(html, contains('data-de-docs-theme-value="dark"'));
  });

  test('loads docs pages from data asset ids', () async {
    final requestedAssetIds = <String>[];
    final source = DartEdgeDocsDataAssetContentSource(
      package: 'dart_edge_docs_example',
      assetNames: const ['docs/index.mdx', 'docs/users/calls.mdx'],
      pathPrefixToStrip: 'docs',
      loadString: (assetId) async {
        requestedAssetIds.add(assetId);
        return '# ${assetId.split('/').last}';
      },
    );

    final pages = await source.loadPages();

    expect(requestedAssetIds, [
      'package:dart_edge_docs_example/docs/index.mdx',
      'package:dart_edge_docs_example/docs/users/calls.mdx',
    ]);
    expect(pages.map((page) => page.path), ['index.mdx', 'users/calls.mdx']);
  });

  test('loads routes from a string manifest content source', () async {
    const source = DartEdgeDocsStringManifestContentSource({
      'index.mdx': '# Overview',
      'users/calls.mdx': '# Calls',
    });
    final loader = DartEdgeDocsContentSourceLoader(source: source);

    final routes = await loader.loadRoutes((_) => const PageConfig(), false);

    expect(routes.map((route) => (route as jaspr_router.Route).path), [
      '/',
      '/users/calls',
    ]);
  });
}

Future<String> _renderHead(DartEdgeDocsLayout layout) {
  final page = Page(
    path: 'index.mdx',
    url: '/',
    content: '# Overview',
    config: const PageConfig(),
    loader: _NoopRouteLoader(),
  );

  return JasprRenderer.renderString(
    Component.fragment(layout.buildHead(page).toList(growable: false)),
    standalone: true,
  );
}

Future<String> _renderBody(DartEdgeDocsLayout layout) {
  final page = Page(
    path: 'index.mdx',
    url: '/',
    content: '# Overview',
    config: const PageConfig(),
    loader: _NoopRouteLoader(),
  );

  return JasprRenderer.renderString(
    layout.buildBody(page, Component.text('Overview')),
    standalone: true,
  );
}

final class _NoopRouteLoader extends RouteLoaderBase<PageSource> {
  @override
  Future<List<PageSource>> loadPageSources() async => const [];
}

final class _NoopTemplateEngine implements TemplateEngine {
  @override
  Future<void> render(Page page, List<Page> pages) async {}
}
