import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
  test('builds a matching PostgreSQL GIN full-text index', () {
    final statement = PostgresTextSearch.createIndex(
      table: 'content.documents',
      column: 'body',
      configuration: 'simple',
    );

    expect(statement.sql, contains('ON "content"."documents" USING GIN'));
    expect(
      statement.sql,
      contains("to_tsvector('simple'::regconfig, coalesce(\"body\", ''))"),
    );
  });

  test('builds a parameterized ranked web-search query', () {
    final statement = PostgresTextSearch.search(
      table: 'documents',
      column: 'body',
      query: 'dart OR postgres -sqlite',
      limit: 7,
    );

    expect(statement.sql, contains('websearch_to_tsquery'));
    expect(statement.sql, contains("'english'::regconfig"));
    expect(statement.sql, contains('ORDER BY "search_rank" DESC'));
    expect(statement.namedParameters, {
      'query': 'dart OR postgres -sqlite',
      'limit': 7,
    });
  });
}
