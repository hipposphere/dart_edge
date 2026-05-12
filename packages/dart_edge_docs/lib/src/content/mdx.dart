import 'package:jaspr_content/jaspr_content.dart';

import 'shadcn_mdx_components.dart';

/// Defaults for rendering documentation `.md` and `.mdx` files.
final class DartEdgeDocsMdx {
  const DartEdgeDocsMdx._();

  /// Markdown/MDX parser list for `jaspr_content`.
  static List<PageParser> parsers() => const [MarkdownParser()];

  /// Page extensions used by documentation pages.
  static List<PageExtension> extensions({int maxHeaderDepth = 3}) {
    return [
      HeadingAnchorsExtension(maxHeaderDepth: maxHeaderDepth),
      TableOfContentsExtension(maxHeaderDepth: maxHeaderDepth),
    ];
  }

  /// MDX-style custom components backed by `shadcn_jaspr`.
  static List<CustomComponent> components({
    List<CustomComponent> additional = const [],
  }) {
    return [...DartEdgeShadcnMdxComponents.defaults(), ...additional];
  }
}
