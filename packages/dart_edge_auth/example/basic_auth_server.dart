import 'dart:async';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

Future<void> main() async {
  final app = DartEdge<NoServices>(services: NoServices.new);
  final auth = DartEdgeAuth(
    const DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
      baseUrl: 'http://localhost:8080',
    ),
  );

  app.installSchemaRegistry(DartEdgeAuthSchema.jsonSchemas);
  auth.mount(app);

  await app.listen(port: 8080);
}

final class NoServices {
  const NoServices();
}
