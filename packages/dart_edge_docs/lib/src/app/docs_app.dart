import 'package:jaspr/jaspr.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../content/content_source.dart';
import '../content/mdx.dart';
import '../layout/docs_layout.dart';
import '../wiki/wiki.dart';

/// A Jaspr documentation app for file-system-backed `.md` and `.mdx` pages.
final class DartEdgeDocsApp extends StatelessComponent {
  const DartEdgeDocsApp({
    required this.wiki,
    this.contentDirectory = 'content',
    this.dataDirectory = 'content/_data',
    this.stylesheetHref = '/styles.css',
    this.includeFallbackStyles = true,
    this.eagerlyLoadAllPages = true,
    this.templateEngine,
    this.additionalComponents = const [],
    this.debugPrintRoutes = false,
    super.key,
  }) : contentSource = null;

  /// Creates a docs app backed by bundled or generated content.
  const DartEdgeDocsApp.fromContentSource({
    required this.wiki,
    required DartEdgeDocsContentSource source,
    this.stylesheetHref = '/styles.css',
    this.includeFallbackStyles = true,
    this.eagerlyLoadAllPages = true,
    this.templateEngine,
    this.additionalComponents = const [],
    this.debugPrintRoutes = false,
    super.key,
  }) : contentSource = source,
       contentDirectory = 'content',
       dataDirectory = 'content/_data';

  /// Structured wiki navigation shown in the shell.
  final DartEdgeDocsWiki wiki;

  /// Directory containing `.md` and `.mdx` files.
  final String contentDirectory;

  /// Directory containing optional `jaspr_content` data files.
  final String dataDirectory;

  /// Optional bundled content source.
  final DartEdgeDocsContentSource? contentSource;

  /// Compiled stylesheet path.
  ///
  /// Apps can serve `web/styles/dart_edge_docs.css` from this package or point
  /// this at their own Tailwind/shadcn bundle.
  final String stylesheetHref;

  /// Whether the layout should include package-owned fallback styles for the
  /// docs shell and shadcn primitives used by the default MDX components.
  final bool includeFallbackStyles;

  /// Whether all pages should be loaded before rendering.
  final bool eagerlyLoadAllPages;

  /// Optional template engine used to preprocess page content before parsing.
  final TemplateEngine? templateEngine;

  /// Extra MDX components available to documentation pages.
  final List<CustomComponent> additionalComponents;

  /// Prints generated route information while developing.
  final bool debugPrintRoutes;

  @override
  Component build(BuildContext context) {
    final source = contentSource;
    if (source != null) {
      return ContentApp.custom(
        loaders: [
          DartEdgeDocsContentSourceLoader(
            source: source,
            debugPrint: debugPrintRoutes,
          ),
        ],
        eagerlyLoadAllPages: eagerlyLoadAllPages,
        configResolver: PageConfig.all(
          templateEngine: templateEngine,
          parsers: DartEdgeDocsMdx.parsers(),
          extensions: DartEdgeDocsMdx.extensions(),
          components: DartEdgeDocsMdx.components(
            additional: additionalComponents,
          ),
          layouts: [
            DartEdgeDocsLayout(
              wiki: wiki,
              stylesheetHref: stylesheetHref,
              includeFallbackStyles: includeFallbackStyles,
            ),
          ],
        ),
      );
    }

    return ContentApp(
      directory: contentDirectory,
      dataDirectory: dataDirectory,
      eagerlyLoadAllPages: eagerlyLoadAllPages,
      templateEngine: templateEngine,
      parsers: DartEdgeDocsMdx.parsers(),
      extensions: DartEdgeDocsMdx.extensions(),
      components: DartEdgeDocsMdx.components(additional: additionalComponents),
      layouts: [
        DartEdgeDocsLayout(
          wiki: wiki,
          stylesheetHref: stylesheetHref,
          includeFallbackStyles: includeFallbackStyles,
        ),
      ],
      debugPrint: debugPrintRoutes,
    );
  }
}
