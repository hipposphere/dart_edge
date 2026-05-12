import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:jaspr/server.dart';

Future<void> main() async {
  Jaspr.initializeApp();

  final app = DartEdge<void>(
    services: () {},
    openApiDocument: OpenApiDocument(
      title: 'Dart Edge Docs Example',
      version: '0.1.0',
    ),
  );

  const docs = DartEdgeDocsApp(
    wiki: DartEdgeDocsWiki(
      title: 'Dart Edge Docs',
      description: 'MDX-backed documentation for Dart Edge packages.',
      versionLabel: '0.1',
      sections: [
        DartEdgeDocsSection(
          title: 'Start',
          pages: [
            DartEdgeDocsPage(title: 'Overview', href: '/'),
            DartEdgeDocsPage(title: 'MDX Components', href: '/mdx-components'),
          ],
        ),
      ],
    ),
    contentDirectory: 'content',
    stylesheetHref: '/styles.css',
  );

  app.mountDartEdgeDocs(docs);

  final server = await app.listen(port: 8080, workers: 1);
  print('Serving Dart Edge docs at http://${server.host}:${server.port}');
}
