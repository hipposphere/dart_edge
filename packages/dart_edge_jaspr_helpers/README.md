# dart_edge_jaspr_helpers

Higher-level Jaspr page and email components for Dart Edge.

Use this package when you want reusable HTML building blocks on top of
`dart_edge_jaspr` instead of hand-writing every password-reset page or email
template.

## Current API

- `DartEdgeBrandPalette` for consistent accent, surface, text, and border colors
- `DartEdgeIcon` and `DartEdgeIconBadge` for inline SVG icon rendering
- `DartEdgeEmailLayout` for branded email-style HTML documents
- `DartEdgeNoticePage` for browser-facing confirmation and next-step pages
- `DartEdgePasswordResetEmail` and `DartEdgeVerificationEmail` as concrete auth
  templates

## Example

```dart
import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_jaspr_helpers/dart_edge_jaspr_helpers.dart';

Future<void> main() async {
  final app = DartEdge<void>(services: () {});

  app.getJaspr(
    '/preview/reset-password',
    handler: (_) => const DartEdgePasswordResetEmail(
      resetUrl: 'https://example.com/reset?token=demo',
      expiresInText: '30 minutes',
      supportEmail: 'support@example.com',
    ),
  );

  await app.listen(port: 8080);
}
```

These helpers currently focus on self-contained HTML and inline SVG. Email-safe
CSS inlining and provider adapters are still better handled by a dedicated mail
delivery package later.
