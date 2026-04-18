import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';

import 'auth.dart';
import 'database.dart';
import 'routes/database_route.dart';
import 'routes/health_route.dart';
import 'routes/raw_route.dart';
import 'services.dart';

Future<DartEdge<Services>> createApp({required int port}) async {
  final database = await openDatabase();
  final auth = createAuth(port: port, database: database);

  await seedUsers(auth);

  final app = DartEdge<Services>(
    services: () => Services(auth: auth, database: database),
  );
  final protected = app.router(
    '',
    guards: [DartEdgeAuthGuard<Services>(auth: auth)],
  );

  auth.mount(app);
  app.register(HealthRoute());
  protected.register(RawRoute());
  protected.register(DatabaseRoute());

  return app;
}
