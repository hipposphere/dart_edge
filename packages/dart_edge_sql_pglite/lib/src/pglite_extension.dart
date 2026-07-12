/// A bundled PostgreSQL extension selected when a PGlite database opens.
///
/// PGlite validates [sqlName] against the extension catalog bundled by its
/// native runtime. Constructing a value does not imply that every runtime
/// version contains that extension.
extension type const PgliteExtension(String sqlName) {
  /// Case-insensitive text and pattern matching with `citext`.
  static const citext = PgliteExtension('citext');

  /// Fuzzy string matching functions such as Levenshtein distance.
  static const fuzzyStringMatch = PgliteExtension('fuzzystrmatch');

  /// Key/value storage through PostgreSQL's `hstore` type.
  static const hstore = PgliteExtension('hstore');

  /// Hierarchical tree paths through PostgreSQL's `ltree` type.
  static const ltree = PgliteExtension('ltree');

  /// Trigram similarity and indexed fuzzy matching.
  static const pgTrgm = PgliteExtension('pg_trgm');

  /// BM25-ranked full-text search through `pg_textsearch`.
  static const pgTextSearch = PgliteExtension('pg_textsearch');

  /// Accent-removing text search dictionary and function.
  static const unaccent = PgliteExtension('unaccent');

  /// Vector columns and similarity indexes through `pgvector`.
  static const vector = PgliteExtension('vector');
}
