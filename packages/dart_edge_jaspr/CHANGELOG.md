## 0.3.5

- Remove direct Dart Edge HTML route helpers in favor of mounting Jaspr's Shelf
  handler through `dart_edge_shelf`.
- Remove custom static asset fallback plumbing from `mountJasprApp(...)`;
  static assets are handled by Jaspr's app handler.
- Keep `JasprRenderer.renderString(...)` for tests, previews, and email
  rendering.

## 0.3.4

- Preserve route-local path parameter and query parameter decoders when
  normalizing Jaspr route options.
- Update Dart Edge dependency constraints for the latest core and runtime APIs.

## 0.3.2

- Update development constraint for rebuilt HTTP runtime native artifacts.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
