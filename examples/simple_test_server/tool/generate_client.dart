import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:simple_test_server/server.dart';
import 'package:simple_test_server/src/service.dart';

Future<void> main() async {
  final server = DartEdge<SimpleTestServices>();
  final auth = DartEdgeAuth(
    const DartEdgeAuthConfig(
      secret:
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      baseUrl: 'http://localhost:3100',
      admin: DartEdgeAuthAdminConfig(),
    ),
  );
  installSimpleTestRoutes(server, auth: auth);
  final spec = DartEdgeClientLibrarySpec.fromRouter(
    className: 'SimpleTestClient',
    router: server,
    schemas: server.schemaRegistry?.schemas ?? const <JsonSchema>[],
    options: DartEdgeClientGenerationOptions(ignorePaths: {'/auth/admin'}),
  );

  await const DartEdgeClientFileEmitter().emit(
    spec,
    output: Directory('../simple_test_client/lib/generated'),
  );
  auth.dispose();
}
