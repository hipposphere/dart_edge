import 'introspected_database.dart';

/// Reads a live database schema and returns its introspected description.
abstract interface class SqlDatabaseIntrospector {
  /// Introspects the database and returns its tables and columns.
  Future<IntrospectedDatabase> introspect();
}
