import 'dart:async';

import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';

Future<void> main() async {
  final app = DartEdge<NoServices>(services: NoServices.new);
  final auth = DartEdgeAuth(
    const DartEdgeAuthConfig(
      secret: 'change-me-to-a-long-secret-that-is-at-least-32-chars',
      baseUrl: 'http://localhost:8080',
    ),
  );

  auth.mount(app);

  await app.listen(port: 8080);
}

final class NoServices {
  const NoServices();
}
