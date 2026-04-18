/// Parsed migration identity derived from one file-based migration stem.
final class SqlMigrationFileIdentity {
  const SqlMigrationFileIdentity({required this.version, required this.name});

  /// Stable migration version used for ordering and metadata.
  final String version;

  /// Human-readable migration name derived from the file stem.
  final String name;
}

/// Sorting and filename parsing strategy for file-based migrations.
abstract interface class SqlMigrationFileSorting {
  const factory SqlMigrationFileSorting.lexicographic() =
      _LexicographicSqlMigrationFileSorting;
  const factory SqlMigrationFileSorting.flyway() =
      _FlywaySqlMigrationFileSorting;

  /// Parses one logical migration stem into version and name metadata.
  SqlMigrationFileIdentity parse(String stem);

  /// Compares two logical migration stems.
  int compare(String leftStem, String rightStem);
}

final class _LexicographicSqlMigrationFileSorting
    implements SqlMigrationFileSorting {
  const _LexicographicSqlMigrationFileSorting();

  @override
  int compare(String leftStem, String rightStem) {
    return leftStem.compareTo(rightStem);
  }

  @override
  SqlMigrationFileIdentity parse(String stem) {
    if (stem.isEmpty) {
      throw FormatException('Migration file stem must not be empty.');
    }

    return SqlMigrationFileIdentity(version: stem, name: stem);
  }
}

final class _FlywaySqlMigrationFileSorting implements SqlMigrationFileSorting {
  const _FlywaySqlMigrationFileSorting();

  @override
  int compare(String leftStem, String rightStem) {
    final left = _parseStem(leftStem);
    final right = _parseStem(rightStem);

    final count = left.versionSegments.length < right.versionSegments.length
        ? left.versionSegments.length
        : right.versionSegments.length;
    for (var index = 0; index < count; index += 1) {
      final difference =
          left.versionSegments[index] - right.versionSegments[index];
      if (difference != 0) {
        return difference;
      }
    }

    if (left.versionSegments.length != right.versionSegments.length) {
      return left.versionSegments.length - right.versionSegments.length;
    }

    return left.name.compareTo(right.name);
  }

  @override
  SqlMigrationFileIdentity parse(String stem) {
    final parsed = _parseStem(stem);
    return SqlMigrationFileIdentity(version: parsed.version, name: parsed.name);
  }
}

({String version, String name, List<int> versionSegments}) _parseStem(
  String stem,
) {
  final match = _flywayStemPattern.firstMatch(stem);
  if (match == null) {
    throw FormatException(
      'Flyway migration files must look like '
      '"V1__create_users.sql" or "V10__add_index.down.sql".',
    );
  }

  final version = match.group(1)!;
  final description = match.group(2)!;
  final versionSegments = version
      .split(RegExp(r'[._]'))
      .map((segment) {
        final parsed = int.tryParse(segment);
        if (parsed == null) {
          throw FormatException(
            'Flyway version segment "$segment" in "$stem" is not numeric.',
          );
        }
        return parsed;
      })
      .toList(growable: false);

  return (
    version: version,
    name: description,
    versionSegments: versionSegments,
  );
}

final _flywayStemPattern = RegExp(
  r'^V([0-9]+(?:[._][0-9]+)*)__([A-Za-z0-9_]+)$',
);
