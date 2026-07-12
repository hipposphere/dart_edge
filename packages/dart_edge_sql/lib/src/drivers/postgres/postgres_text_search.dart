import '../../core/sql_statement.dart';

/// PostgreSQL parser used to turn user input into a full-text query.
enum PostgresTextSearchQueryMode {
  /// Treats the input as unformatted words joined with `AND`.
  plain,

  /// Treats the input as one phrase.
  phrase,

  /// Accepts web-style quoted phrases, `OR`, and excluded words.
  web,
}

/// Statements for PostgreSQL's built-in `tsvector` full-text search.
abstract final class PostgresTextSearch {
  /// Creates a GIN index for [column] on [table].
  static SqlStatement createIndex({
    required String table,
    required String column,
    String configuration = 'english',
    String? indexName,
  }) {
    _requireNotEmpty(table, 'table');
    _requireNotEmpty(column, 'column');
    _requireNotEmpty(configuration, 'configuration');
    final effectiveIndexName =
        indexName ?? '${table.split('.').last}_${column}_fts_idx';
    _requireNotEmpty(effectiveIndexName, 'indexName');

    final vector = _vectorExpression(column, configuration);
    return sql(
      'CREATE INDEX ${_identifier(effectiveIndexName)} '
      'ON ${_qualifiedIdentifier(table)} USING GIN ($vector)',
    );
  }

  /// Searches [column] on [table] and orders matches by descending relevance.
  ///
  /// Every source column is returned together with a `double precision` rank
  /// named [rankColumn].
  static SqlStatement search({
    required String table,
    required String column,
    required String query,
    String configuration = 'english',
    PostgresTextSearchQueryMode queryMode = PostgresTextSearchQueryMode.web,
    String rankColumn = 'search_rank',
    int limit = 20,
  }) {
    _requireNotEmpty(table, 'table');
    _requireNotEmpty(column, 'column');
    _requireNotEmpty(configuration, 'configuration');
    _requireNotEmpty(rankColumn, 'rankColumn');
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }

    final vector = _vectorExpression(column, configuration, alias: 'source');
    final queryFunction = switch (queryMode) {
      PostgresTextSearchQueryMode.plain => 'plainto_tsquery',
      PostgresTextSearchQueryMode.phrase => 'phraseto_tsquery',
      PostgresTextSearchQueryMode.web => 'websearch_to_tsquery',
    };
    final config = _stringLiteral(configuration);
    final rank = _identifier(rankColumn);

    return SqlStatement.named(
      '''
WITH "_postgres_search" AS (
  SELECT $queryFunction($config::regconfig, @query) AS "query"
)
SELECT "source".*, ts_rank_cd($vector, "_postgres_search"."query") AS $rank
FROM ${_qualifiedIdentifier(table)} AS "source"
CROSS JOIN "_postgres_search"
WHERE $vector @@ "_postgres_search"."query"
ORDER BY $rank DESC
LIMIT @limit
''',
      {'query': query, 'limit': limit},
    );
  }
}

String _vectorExpression(String column, String configuration, {String? alias}) {
  final qualifiedColumn = [
    if (alias != null) _identifier(alias),
    _identifier(column),
  ].join('.');
  return 'to_tsvector('
      '${_stringLiteral(configuration)}::regconfig, '
      "coalesce($qualifiedColumn, '')"
      ')';
}

String _qualifiedIdentifier(String value) => value
    .split('.')
    .map((part) {
      _requireNotEmpty(part, 'table');
      return _identifier(part);
    })
    .join('.');

String _identifier(String value) => '"${value.replaceAll('"', '""')}"';

String _stringLiteral(String value) => "'${value.replaceAll("'", "''")}'";

void _requireNotEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
