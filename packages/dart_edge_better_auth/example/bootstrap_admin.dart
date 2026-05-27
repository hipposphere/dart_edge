import 'package:dart_edge_better_auth/dart_edge_better_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

Future<void> main() async {
  final pool = PostgresPool.withUrl(
    const String.fromEnvironment('DATABASE_URL'),
  );

  await DartEdgeBetterAuthMigrator(pool: pool).migrateToLatest();

  final auth = DartEdgeBetterAuth.withPool(
    options: const BetterAuthOptions(
      secret: String.fromEnvironment('BETTER_AUTH_SECRET'),
      baseUrl: String.fromEnvironment('BETTER_AUTH_BASE_URL'),
    ),
    pool: pool,
  );

  await auth.trusted.admin.createUser(
    email: const String.fromEnvironment('ADMIN_EMAIL'),
    password: const String.fromEnvironment('ADMIN_PASSWORD'),
    name: const String.fromEnvironment('ADMIN_NAME', defaultValue: 'Admin'),
  );

  await pool.close();
}
