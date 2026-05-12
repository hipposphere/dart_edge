# dart_edge_docs

Jaspr documentation app primitives for MDX-backed structured wikis.

The package layers a Dart Edge documentation shell over:

- `jaspr_content` for Markdown/MDX parsing, frontmatter, file-system routing,
  heading anchors, and table-of-contents data.
- `jaspr_router` for route generation.
- `shadcn_jaspr` for reusable docs UI components.

## Basic App

```dart
import 'package:dart_edge_docs/dart_edge_docs.dart';
import 'package:jaspr/server.dart';

void main() {
  Jaspr.initializeApp();

  runApp(
    DartEdgeDocsApp(
      wiki: const DartEdgeDocsWiki(
        title: 'Dart Edge',
        sections: [
          DartEdgeDocsSection(
            title: 'Guide',
            pages: [
              DartEdgeDocsPage(title: 'Overview', href: '/'),
              DartEdgeDocsPage(title: 'Routing', href: '/routing'),
            ],
          ),
        ],
      ),
    ),
  );
}
```

Place `.md` and `.mdx` files under `content/`. The default app supports
frontmatter, heading anchors, table-of-contents metadata, and MDX-style custom
components such as:

```mdx
---
title: Routing
description: Build documentation pages from MDX files.
---

# Routing

<Callout title="Note" variant="default">
Use normal links for wiki navigation.
</Callout>

<Badge variant="secondary">Preview</Badge>
```

`DartEdgeDocsApp` also forwards `templateEngine` to `jaspr_content`, so docs can
use `MustacheTemplateEngine`, `LiquidTemplateEngine`, or a custom
`TemplateEngine` for preprocessing content before Markdown/MDX parsing.

`DartEdgeDocsApp` links `stylesheetHref`, which defaults to `/styles.css`.
The package ships a precompiled default stylesheet at `web/styles.css`.
Serve that stylesheet through the consuming Jaspr app's normal static asset
setup, or point `stylesheetHref` at your own Tailwind/shadcn bundle.

The layout also includes package-owned fallback styles by default for the docs
shell and the shadcn primitives used by the built-in MDX components. Set
`includeFallbackStyles: false` when the consuming app serves a complete
Tailwind/shadcn stylesheet and wants that bundle to own all component styling.

For Tailwind-based apps, `web/styles/globals.tw.css` remains available as a
starter Tailwind entrypoint.

## Dart Edge Mounting

```dart
final app = DartEdge<void>(services: () {});

app.mountDartEdgeDocs(
  const DartEdgeDocsApp(
    wiki: DartEdgeDocsWiki(
      title: 'Dart Edge',
      sections: [
        DartEdgeDocsSection(
          title: 'Guide',
          pages: [
            DartEdgeDocsPage(title: 'Overview', href: '/'),
            DartEdgeDocsPage(title: 'Routing', href: '/routing'),
          ],
        ),
      ],
    ),
  ),
);
```

The helper mounts a single catch-all Jaspr app route. Static files are handled
by Jaspr's app handler, so app-local files under `web/` are served the same way
they are in a normal Jaspr server.
