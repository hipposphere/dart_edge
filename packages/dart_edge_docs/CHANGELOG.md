## 0.2.2

- Forward Jaspr static file and handler base-path options from
  `mountDartEdgeDocs(...)`, with Jaspr static file handling disabled by default
  for app-only runtime images.

## 0.2.0

- Mount docs through the Shelf-backed Jaspr app handler.
- Ship a precompiled default docs stylesheet.
- Reorganize package internals by app, content, layout, routing, styles, and
  wiki concerns.

## 0.1.1

- Expose `templateEngine` on `DartEdgeDocsApp` and forward it to
  `jaspr_content`'s `ContentApp`.

## 0.1.0

- Add the initial Jaspr docs app shell with MDX routing defaults.
