import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:test/test.dart';

void main() {
  const wiki = DartEdgeDocsWiki(
    title: 'Dart Edge',
    sections: [
      DartEdgeDocsSection(
        title: 'Guide',
        pages: [
          DartEdgeDocsPage(title: 'Overview', href: '/'),
          DartEdgeDocsPage(title: 'Routing', href: '/routing'),
          DartEdgeDocsPage(title: 'MDX', href: '/content/mdx'),
        ],
      ),
    ],
  );

  test('finds pages with normalized hrefs', () {
    expect(wiki.pageFor('/routing/')?.title, 'Routing');
    expect(wiki.pageFor('/missing'), isNull);
  });

  test('returns ordered neighbors', () {
    final neighbors = wiki.neighborsFor('/routing');

    expect(neighbors.previous?.title, 'Overview');
    expect(neighbors.next?.title, 'MDX');
  });

  test('builds readable breadcrumbs', () {
    final breadcrumbs = dartEdgeDocsBreadcrumbsFor(
      href: '/content/mdx',
      rootLabel: 'Docs',
      currentTitle: 'MDX Files',
    );

    expect(breadcrumbs.map((item) => (item.label, item.href, item.current)), [
      ('Docs', '/', false),
      ('Content', '/content', false),
      ('MDX Files', '/content/mdx', true),
    ]);
  });
}
