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

`shadcn_jaspr` components expect Tailwind and the shadcn CSS variables. This
package includes `web/styles/globals.tw.css` as a starter Tailwind entrypoint;
compile it to the `stylesheetHref` used by `DartEdgeDocsApp`, which defaults to
`/styles.css`.
