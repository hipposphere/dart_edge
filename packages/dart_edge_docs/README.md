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
The docs shell includes a Light/Dark/System color-mode control. It starts in
System mode, stores the selected mode in `localStorage`, and sets both
`data-theme` and the `.dark` class on the document root for stylesheet
compatibility.

For Tailwind-based apps, `web/styles/globals.tw.css` remains available as a
starter Tailwind entrypoint.

## Bundled Content

Use `DartEdgeDocsApp.fromContentSource()` when docs must not depend on loose
source files at runtime, for example in Docker images built from compiled Dart
output.

```dart
final docs = DartEdgeDocsApp.fromContentSource(
  wiki: wiki,
  source: DartEdgeDocsDataAssetContentSource(
    package: 'my_docs_app',
    assetNames: const [
      'docs/index.mdx',
      'docs/users/calls.mdx',
    ],
    pathPrefixToStrip: 'docs',
    loadString: loadDataAssetString,
  ),
);
```

A package that owns docs can use the same hook pattern as `dart_edge_docs`:
register files under `content/docs/**/*.mdx` and `content/docs/**/*.md` as data
assets with ids like `package:my_docs_app/docs/users/calls.mdx`.

Adding a bundled page requires adding the file under `content/docs` and listing
its asset name wherever the app constructs `DartEdgeDocsDataAssetContentSource`.

Until the target Dart runtime can load data assets by id, use the generated
string manifest fallback:

```sh
dart run dart_edge_docs:generate_docs_manifest \
  --input content/docs \
  --output lib/src/generated/docs_content_manifest.dart \
  --name docsContentManifest
```

```dart
const docs = DartEdgeDocsApp.fromContentSource(
  wiki: wiki,
  source: DartEdgeDocsStringManifestContentSource(docsContentManifest),
);
```

When the fallback is active, rerun the manifest generator after adding or
editing a docs page.

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

The helper mounts a single catch-all Jaspr app route and disables Jaspr static
file handling by default so bundled docs work in app-only runtime images without
a `pubspec.yaml`. For mounted docs under a prefix, pass both the route pattern
and Shelf handler base path:

```dart
app.mountDartEdgeDocs(
  docs,
  catchAllPath: '/docs/<dartEdgeDocsPath*>',
  handlerPath: '/docs',
);
```

If an app wants Jaspr to serve `web/` static files as well, pass
`serveStaticFiles: true` or provide `staticFileHandler`.
