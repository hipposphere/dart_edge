import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class Services {
  const Services({required this.auth, required this.database});

  final DartEdgeAuth auth;
  final SqliteDatabase database;
}
