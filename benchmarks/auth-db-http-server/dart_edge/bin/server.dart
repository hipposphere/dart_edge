import 'package:dart_edge_auth_db_benchmark_dart_edge/dart_edge_auth_db_benchmark_dart_edge.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

Future<void> main(List<String> args) async {
  final port = parseBenchmarkPort(args);
  final app = await createApp(port: port);
  await app.listen(port: port);
}
