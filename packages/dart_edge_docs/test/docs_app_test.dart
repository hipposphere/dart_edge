import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
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
    );

    final paths = {
      for (final registration in router.routeRegistry.registrations)
        registration.httpPath,
    };

    expect(paths, contains('/<dartEdgeDocsPath*>'));
    expect(router.routeRegistry.registrations, hasLength(1));
  });

  test('accepts a jaspr_content template engine', () {
    final templateEngine = _NoopTemplateEngine();
    final app = DartEdgeDocsApp(wiki: wiki, templateEngine: templateEngine);

    expect(app.templateEngine, same(templateEngine));
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

final class _NoopRouteLoader extends RouteLoaderBase<PageSource> {
  @override
  Future<List<PageSource>> loadPageSources() async => const [];
}

final class _NoopTemplateEngine implements TemplateEngine {
  @override
  Future<void> render(Page page, List<Page> pages) async {}
}
