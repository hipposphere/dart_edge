import 'sql_row.dart';

/// Result of an executed SQL statement.
final class SqlResult {
  SqlResult({this.affectedRows = 0, List<SqlRow> rows = const <SqlRow>[]})
    : rows = List<SqlRow>.unmodifiable(rows);

  /// Number of rows affected by the statement, when reported by the driver.
  final int affectedRows;

  /// Rows returned by the statement.
  final List<SqlRow> rows;

  /// Whether [rows] is empty.
  bool get isEmpty => rows.isEmpty;

  /// Whether [rows] is not empty.
  bool get isNotEmpty => rows.isNotEmpty;

  /// First returned row.
  SqlRow get first => rows.first;

  /// Only returned row.
  SqlRow get single => rows.single;
}
