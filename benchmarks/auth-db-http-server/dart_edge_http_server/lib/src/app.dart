import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

import 'auth.dart';
import 'benchmark_config.dart';
import 'database.dart';
import 'routes/database_route.dart';
import 'routes/health_route.dart';
import 'routes/raw_route.dart';
import 'routes/upload_multipart_route.dart';
import 'services.dart';

Future<DartEdge<Services>> createApp({required int port}) async {
  final database = await openDatabase();
  final auth = createAuth(port: port, database: database);
  final s3Client = await openBenchmarkS3Client();

  await seedUsers(auth);

  final app = DartEdge<Services>(
    services: () => Services(
      auth: auth,
      database: database,
      s3Client: s3Client,
      s3Bucket: benchmarkS3BucketName,
    ),
  );
  final protected = app.router(
    '',
    guards: [DartEdgeAuthGuard<Services>(auth: auth)],
  );

  auth.mount(app);
  app.register(HealthRoute());
  protected.register(RawRoute());
  protected.register(DatabaseRoute());
  protected.register(UploadMultipartRoute());

  return app;
}
