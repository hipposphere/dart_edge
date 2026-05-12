import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';

import '../app/docs_app.dart';

/// Dart Edge router helpers for serving a complete [DartEdgeDocsApp].
extension DartEdgeDocsRouterExtensions<TServices> on Router<TServices> {
  /// Mounts the complete docs app through Jaspr's app handler.
  void mountDartEdgeDocs(
    DartEdgeDocsApp docs, {
    String catchAllPath = '/<dartEdgeDocsPath*>',
  }) {
    mountJasprApp(
      docs,
      catchAllPath: catchAllPath,
      paths: const <String>[],
      routeOptions: (path) {
        return const RouteOptions(
          operationId: 'getDartEdgeDocsApp',
          summary: 'Render the mounted Dart Edge documentation app.',
          exposure: RouteExposure.none,
          success: ResponseSpec.html(),
        );
      },
    );
  }
}
