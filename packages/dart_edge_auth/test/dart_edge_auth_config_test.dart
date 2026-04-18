import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
  test('serializes native postgres auth database config', () {
    const config = DartEdgeAuthConfig(
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.postgres(
        connectionString: 'postgresql://postgres:postgres@localhost:5432/app',
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'postgres',
      'connectionString': 'postgresql://postgres:postgres@localhost:5432/app',
    });
  });

  test('serializes sqlite migration management config', () {
    const config = DartEdgeAuthConfig(
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.sqlite(
        path: 'auth.db',
        manageMigrations: false,
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'sqlite',
      'path': 'auth.db',
      'inMemory': false,
      'manageMigrations': false,
    });
  });

  test('serializes admin plugin config', () {
    const config = DartEdgeAuthConfig(
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      admin: DartEdgeAuthAdminConfig(
        adminRole: 'superadmin',
        defaultUserRole: 'member',
        allowBanAdmin: true,
        defaultPageLimit: 50,
        maxPageLimit: 250,
      ),
    );

    expect(config.toJson()['admin'], {
      'adminRole': 'superadmin',
      'defaultUserRole': 'member',
      'allowBanAdmin': true,
      'defaultPageLimit': 50,
      'maxPageLimit': 250,
    });
  });

  test('derives native sqlite auth database config from a sqlite database', () {
    final database = SqliteDatabase.inMemory();
    addTearDown(database.close);

    final config = DartEdgeAuthConfig(
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.fromDatabase(
        database,
        manageMigrations: false,
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'shared',
      'dialect': 'sqlite',
      'manageMigrations': false,
    });
  });
}
