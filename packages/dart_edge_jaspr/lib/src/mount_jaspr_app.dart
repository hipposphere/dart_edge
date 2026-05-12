import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_shelf/dart_edge_shelf.dart';
import 'package:jaspr/jaspr.dart' show Component;
import 'package:jaspr/server.dart' as jaspr_server show serveApp;

import 'jaspr_renderer.dart';

/// Mounts a Jaspr component app onto Dart Edge routes.
///
/// Jaspr's own app server is a Shelf handler that serves `web/` static assets
/// before rendering the app.
extension JasprAppRouterExtensions<TServices> on Router<TServices> {
  void mountJasprApp(
    Component app, {
    String? catchAllPath,
    Iterable<String> paths = const <String>['/'],
    RouteOptions Function(String path)? routeOptions,
    List<Guard<TServices>>? guards,
  }) {
    JasprRenderer.ensureInitialized();

    final handler = jaspr_server.serveApp((request, render) => render(app));

    if (catchAllPath case final path?) {
      mountShelfHandler(
        handler,
        path: path,
        methods: const [HttpMethod.get],
        guards: guards,
        routeOptions: (method, path) =>
            routeOptions?.call(path) ??
            const RouteOptions(
              summary: 'Render the mounted Jaspr app.',
              exposure: RouteExposure.none,
              success: ResponseSpec.html(),
            ),
      );
      return;
    }

    final mountedPaths = <String>{};
    for (final path in paths) {
      if (!mountedPaths.add(path)) {
        continue;
      }

      mountShelfHandler(
        handler,
        path: path,
        methods: const [HttpMethod.get],
        guards: guards,
        routeOptions: (method, path) =>
            routeOptions?.call(path) ??
            RouteOptions(
              summary: 'Render Jaspr app route $path.',
              success: const ResponseSpec.html(),
            ),
      );
    }
  }
}
