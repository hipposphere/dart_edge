import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:jaspr/server.dart';

void main() {
  Jaspr.initializeApp();

  runApp(
    const DartEdgeDocsApp(
      wiki: DartEdgeDocsWiki(
        title: 'Dart Edge Docs',
        description: 'MDX-backed documentation for Dart Edge packages.',
        versionLabel: '0.1',
        sections: [
          DartEdgeDocsSection(
            title: 'Start',
            pages: [
              DartEdgeDocsPage(title: 'Overview', href: '/'),
              DartEdgeDocsPage(
                title: 'MDX Components',
                href: '/mdx-components',
              ),
            ],
          ),
        ],
      ),
      contentDirectory: 'example/content',
    ),
  );
}
