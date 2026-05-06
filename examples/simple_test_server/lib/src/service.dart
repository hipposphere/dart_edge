import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class SimpleTestServices {
  const SimpleTestServices({required this.database, required this.auth});

  final PostgresPool database;
  final DartEdgeAuth auth;
}
