import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:test/test.dart';

void main() {
  test('renders shadcn-backed MDX components', () async {
    final component = NodesBuilder(DartEdgeDocsMdx.components()).build(
      const MarkdownParser().parsePage(
        Page(
          path: 'index.mdx',
          url: '/',
          content: '''
<Callout title="Heads up" variant="destructive">
Check the routing table.
</Callout>

<Badge variant="secondary">Preview</Badge>
''',
          config: const PageConfig(),
          loader: _NoopRouteLoader(),
        ),
      ),
    );

    final html = await JasprRenderer.renderString(component, standalone: true);

    expect(html, contains('data-slot="alert"'));
    expect(html, contains('Heads up'));
    expect(html, contains('Check the routing table.'));
    expect(html, contains('data-slot="badge"'));
    expect(html, contains('Preview'));
  });
}

final class _NoopRouteLoader extends RouteLoaderBase<PageSource> {
  @override
  Future<List<PageSource>> loadPageSources() async => const [];
}
