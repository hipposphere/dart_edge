import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'sql_migration_plan.dart';

/// Desired SQL database schema used to plan migrations.
final class SqlDatabaseSchema {
  const SqlDatabaseSchema({required this.tables});

  /// Tables that should exist in the database.
  final List<SqlTableSchema> tables;

  Map<_TableKey, SqlTableSchema> get _tableByKey {
    return <_TableKey, SqlTableSchema>{
      for (final table in tables) _TableKey(table.schema, table.name): table,
    };
  }
}

/// Desired shape for one SQL table.
final class SqlTableSchema {
  const SqlTableSchema({
    required this.name,
    this.schema,
    this.columns = const <SqlColumnSchema>[],
    this.indexes = const <SqlIndexSchema>[],
  });

  /// Table name without schema qualification.
  final String name;

  /// Optional schema name for databases that support schemas.
  final String? schema;

  /// Columns that should exist on this table.
  final List<SqlColumnSchema> columns;

  /// Secondary indexes that should exist on this table.
  final List<SqlIndexSchema> indexes;

  Map<String, SqlColumnSchema> get _columnByName {
    return <String, SqlColumnSchema>{
      for (final column in columns) column.name: column,
    };
  }

  Map<String, SqlIndexSchema> get _indexByName {
    return <String, SqlIndexSchema>{
      for (final index in indexes) index.name: index,
    };
  }
}

/// Desired shape for one SQL column.
final class SqlColumnSchema {
  const SqlColumnSchema({
    required this.name,
    required this.type,
    this.nullable = true,
    this.primaryKey = false,
    this.unique = false,
    this.defaultExpression,
  });

  /// Column name without table qualification.
  final String name;

  /// Database-native type expression, such as `TEXT`, `INTEGER`, or `BIGINT`.
  final String type;

  /// Whether this column allows `NULL`.
  final bool nullable;

  /// Whether this column is part of the table primary key.
  final bool primaryKey;

  /// Whether this column has a single-column unique constraint.
  final bool unique;

  /// Raw SQL default expression.
  final String? defaultExpression;

  bool get _canBeAddedSafely => nullable || defaultExpression != null;
}

/// Desired shape for one SQL index.
final class SqlIndexSchema {
  const SqlIndexSchema({
    required this.name,
    required this.columns,
    this.unique = false,
  });

  /// Index name without schema qualification.
  final String name;

  /// Ordered table column names that make up the index.
  final List<String> columns;

  /// Whether this index enforces uniqueness.
  final bool unique;
}

/// How much review a schema migration operation needs.
enum SqlSchemaMigrationSafety {
  /// The operation can be generated and applied without data loss.
  safe,

  /// The operation may need a data backfill or a manual cast.
  requiresReview,

  /// The operation can drop data or remove constraints.
  destructive,
}

/// Difference between two schema snapshots.
final class SqlSchemaDiff {
  const SqlSchemaDiff({required this.operations});

  /// Typed operations needed to move from the old schema to the desired schema.
  final List<SqlSchemaMigrationOp> operations;

  /// Human-readable report for operations that need a reviewed migration.
  SqlSchemaMigrationReviewReport get reviewReport {
    return SqlSchemaMigrationReviewReport(
      items: List.unmodifiable([
        for (final operation in operations) ...operation._reviewItems,
      ]),
    );
  }

  /// Human-readable report for reviewed operations in one [dialect].
  SqlSchemaMigrationReviewReport reviewReportForDialect(SqlDialect dialect) {
    return SqlSchemaMigrationReviewReport(
      items: List.unmodifiable([
        for (final operation in operations)
          ...operation.reviewItemsForDialect(dialect),
      ]),
    );
  }

  /// Computes a schema diff from [current] to [desired].
  factory SqlSchemaDiff.between({
    required SqlDatabaseSchema current,
    required SqlDatabaseSchema desired,
  }) {
    final currentTables = current._tableByKey;
    final desiredTables = desired._tableByKey;
    final operations = <SqlSchemaMigrationOp>[];

    for (final entry in desiredTables.entries) {
      final desiredTable = entry.value;
      final currentTable = currentTables[entry.key];
      if (currentTable == null) {
        operations.add(CreateSqlTable(desiredTable));
        for (final index in desiredTable.indexes) {
          operations.add(CreateSqlIndex(table: desiredTable, index: index));
        }
        continue;
      }

      operations.addAll(_diffExistingTable(currentTable, desiredTable));
    }

    for (final entry in currentTables.entries) {
      if (!desiredTables.containsKey(entry.key)) {
        operations.add(DropSqlTable(entry.value));
      }
    }

    return SqlSchemaDiff(operations: List.unmodifiable(operations));
  }

  static List<SqlSchemaMigrationOp> _diffExistingTable(
    SqlTableSchema current,
    SqlTableSchema desired,
  ) {
    final operations = <SqlSchemaMigrationOp>[];
    final currentColumns = current._columnByName;
    final desiredColumns = desired._columnByName;

    for (final entry in desiredColumns.entries) {
      final currentColumn = currentColumns[entry.key];
      final desiredColumn = entry.value;
      if (currentColumn == null) {
        operations.add(AddSqlColumn(table: desired, column: desiredColumn));
      } else if (!_sameColumn(currentColumn, desiredColumn)) {
        operations.add(
          ChangeSqlColumn(
            table: desired,
            current: currentColumn,
            desired: desiredColumn,
          ),
        );
      }
    }

    for (final entry in currentColumns.entries) {
      if (!desiredColumns.containsKey(entry.key)) {
        operations.add(DropSqlColumn(table: current, column: entry.value));
      }
    }

    final currentIndexes = current._indexByName;
    final desiredIndexes = desired._indexByName;
    for (final entry in desiredIndexes.entries) {
      final currentIndex = currentIndexes[entry.key];
      final desiredIndex = entry.value;
      if (currentIndex == null) {
        operations.add(CreateSqlIndex(table: desired, index: desiredIndex));
      } else if (!_sameIndex(currentIndex, desiredIndex)) {
        operations
          ..add(DropSqlIndex(table: current, index: currentIndex))
          ..add(CreateSqlIndex(table: desired, index: desiredIndex));
      }
    }

    for (final entry in currentIndexes.entries) {
      if (!desiredIndexes.containsKey(entry.key)) {
        operations.add(DropSqlIndex(table: current, index: entry.value));
      }
    }

    return operations;
  }

  static bool _sameColumn(SqlColumnSchema left, SqlColumnSchema right) {
    return left.type == right.type &&
        left.nullable == right.nullable &&
        left.primaryKey == right.primaryKey &&
        left.unique == right.unique &&
        left.defaultExpression == right.defaultExpression;
  }

  static bool _sameIndex(SqlIndexSchema left, SqlIndexSchema right) {
    return left.unique == right.unique &&
        _sameStrings(left.columns, right.columns);
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  /// Renders safe operations into a dialect-aware migration plan.
  ///
  /// Set [includeReviewedOperations] when the caller has inspected operations
  /// marked [SqlSchemaMigrationSafety.requiresReview].
  /// Set [includeDestructiveOperations] only for explicitly approved drops.
  SqlMigrationPlan toMigrationPlan({
    bool includeReviewedOperations = false,
    bool includeDestructiveOperations = false,
  }) {
    return SqlMigrationPlan(
      byDialect: <SqlDialect, List<SqlStatement>>{
        for (final dialect in SqlDialect.values)
          dialect: [
            for (final operation in operations)
              ...switch (operation.safety) {
                SqlSchemaMigrationSafety.safe => operation.toStatements(
                  dialect,
                ),
                SqlSchemaMigrationSafety.requiresReview =>
                  includeReviewedOperations
                      ? operation.toStatements(dialect)
                      : operation.safeStatements(dialect),
                SqlSchemaMigrationSafety.destructive =>
                  includeDestructiveOperations
                      ? operation.toStatements(dialect)
                      : const <SqlStatement>[],
              },
          ],
      },
    );
  }
}

/// Human-readable review details for non-trivial schema changes.
final class SqlSchemaMigrationReviewReport {
  const SqlSchemaMigrationReviewReport({required this.items});

  /// Changes that need a human-reviewed migration.
  final List<SqlSchemaMigrationReviewItem> items;

  /// Whether every operation can be rendered without manual review.
  bool get isEmpty => items.isEmpty;

  /// Whether at least one operation needs manual review.
  bool get isNotEmpty => items.isNotEmpty;

  /// Formats the report for CLI output or generated migration comments.
  String format() {
    if (items.isEmpty) {
      return 'No manual migration review required.';
    }

    final buffer = StringBuffer('Manual migration required:');
    for (final item in items) {
      buffer.writeln();
      buffer.writeln('- ${item.target}: ${item.summary}');
      for (final detail in item.details) {
        buffer.writeln('  - $detail');
      }
      buffer.writeln('  Suggested action: ${item.suggestedAction}');
    }
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// One actionable review item in a schema diff.
final class SqlSchemaMigrationReviewItem {
  const SqlSchemaMigrationReviewItem({
    required this.target,
    required this.summary,
    required this.details,
    required this.suggestedAction,
  });

  /// Schema object that needs review, such as `users.email`.
  final String target;

  /// Short description of the change.
  final String summary;

  /// Field-level details about what changed.
  final List<String> details;

  /// Recommended next step for the developer.
  final String suggestedAction;
}

/// One typed schema migration operation.
sealed class SqlSchemaMigrationOp {
  const SqlSchemaMigrationOp();

  /// Safety classification for this operation.
  SqlSchemaMigrationSafety get safety;

  /// Renders this operation for [dialect].
  List<SqlStatement> toStatements(SqlDialect dialect);

  /// Renders the parts of this operation that are safe without review.
  List<SqlStatement> safeStatements(SqlDialect dialect) {
    return safety == SqlSchemaMigrationSafety.safe
        ? toStatements(dialect)
        : const <SqlStatement>[];
  }

  List<SqlSchemaMigrationReviewItem> get _reviewItems =>
      const <SqlSchemaMigrationReviewItem>[];

  /// Human-readable review details for one [dialect].
  List<SqlSchemaMigrationReviewItem> reviewItemsForDialect(SqlDialect dialect) {
    return _reviewItems;
  }
}

/// Creates one table and its inline constraints.
final class CreateSqlTable extends SqlSchemaMigrationOp {
  const CreateSqlTable(this.table);

  final SqlTableSchema table;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.safe;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    final primaryKeyColumns = table.columns
        .where((column) => column.primaryKey)
        .map((column) => _quoteIdentifier(column.name))
        .toList();
    final columns = [
      for (final column in table.columns)
        _columnDefinition(
          column,
          allowInlinePrimaryKey: primaryKeyColumns.length <= 1,
        ),
    ];
    if (primaryKeyColumns.length > 1) {
      columns.add('PRIMARY KEY (${primaryKeyColumns.join(', ')})');
    }
    return [
      sql('CREATE TABLE ${_tableName(table, dialect)} (${columns.join(', ')})'),
    ];
  }
}

/// Adds one column to an existing table.
final class AddSqlColumn extends SqlSchemaMigrationOp {
  const AddSqlColumn({required this.table, required this.column});

  final SqlTableSchema table;
  final SqlColumnSchema column;

  @override
  SqlSchemaMigrationSafety get safety => column._canBeAddedSafely
      ? SqlSchemaMigrationSafety.safe
      : SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems {
    if (safety == SqlSchemaMigrationSafety.safe) {
      return const <SqlSchemaMigrationReviewItem>[];
    }
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${column.name}',
        summary: 'add non-null column without a default',
        details: ['type: ${column.type}', 'nullable: false', 'default: none'],
        suggestedAction:
            'Backfill existing rows or add a default before enforcing NOT NULL.',
      ),
    ];
  }

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return [
      sql(
        'ALTER TABLE ${_tableName(table, dialect)} '
        'ADD COLUMN ${_columnDefinition(column, allowInlineUnique: false)}',
      ),
    ];
  }
}

/// Changes one column definition.
final class ChangeSqlColumn extends SqlSchemaMigrationOp {
  const ChangeSqlColumn({
    required this.table,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema table;
  final SqlColumnSchema current;
  final SqlColumnSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      _columnReviewDetails(current, desired).isEmpty
      ? SqlSchemaMigrationSafety.safe
      : SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems {
    return _reviewItemsFromDetails(_columnReviewDetails(current, desired));
  }

  @override
  List<SqlSchemaMigrationReviewItem> reviewItemsForDialect(SqlDialect dialect) {
    final details = switch (dialect) {
      SqlDialect.postgres => _postgresColumnReviewDetails(current, desired),
      SqlDialect.sqlite => _sqliteColumnReviewDetails(current, desired),
    };
    return _reviewItemsFromDetails(details);
  }

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return safeStatements(dialect);
  }

  @override
  List<SqlStatement> safeStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => _postgresSafeColumnChangeStatements(),
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }

  List<SqlStatement> _postgresSafeColumnChangeStatements() {
    final statements = <SqlStatement>[];
    final tableName = _tableName(table, SqlDialect.postgres);
    final columnName = _quoteIdentifier(desired.name);

    if (current.nullable == false && desired.nullable) {
      statements.add(
        sql('ALTER TABLE $tableName ALTER COLUMN $columnName DROP NOT NULL'),
      );
    }

    if (current.defaultExpression != desired.defaultExpression) {
      final defaultExpression = desired.defaultExpression;
      statements.add(
        sql(
          defaultExpression == null
              ? 'ALTER TABLE $tableName ALTER COLUMN $columnName DROP DEFAULT'
              : 'ALTER TABLE $tableName ALTER COLUMN $columnName '
                    'SET DEFAULT $defaultExpression',
        ),
      );
    }

    return List.unmodifiable(statements);
  }

  List<SqlSchemaMigrationReviewItem> _reviewItemsFromDetails(
    List<String> details,
  ) {
    if (details.isEmpty) {
      return const <SqlSchemaMigrationReviewItem>[];
    }

    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${desired.name}',
        summary: 'change column definition',
        details: details,
        suggestedAction:
            'Write a reviewed migration with any needed casts, backfills, '
            'constraint validation, or data cleanup before applying this shape.',
      ),
    ];
  }
}

/// Drops one column from an existing table.
final class DropSqlColumn extends SqlSchemaMigrationOp {
  const DropSqlColumn({required this.table, required this.column});

  final SqlTableSchema table;
  final SqlColumnSchema column;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return [
      sql(
        'ALTER TABLE ${_tableName(table, dialect)} '
        'DROP COLUMN ${_quoteIdentifier(column.name)}',
      ),
    ];
  }
}

/// Creates one secondary index.
final class CreateSqlIndex extends SqlSchemaMigrationOp {
  const CreateSqlIndex({required this.table, required this.index});

  final SqlTableSchema table;
  final SqlIndexSchema index;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.safe;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    final unique = index.unique ? 'UNIQUE ' : '';
    final columns = index.columns.map(_quoteIdentifier).join(', ');
    return [
      sql(
        'CREATE ${unique}INDEX ${_quoteIdentifier(index.name)} '
        'ON ${_tableName(table, dialect)} ($columns)',
      ),
    ];
  }
}

/// Drops one secondary index.
final class DropSqlIndex extends SqlSchemaMigrationOp {
  const DropSqlIndex({required this.table, required this.index});

  final SqlTableSchema table;
  final SqlIndexSchema index;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return [
      sql(switch (dialect) {
        SqlDialect.sqlite => 'DROP INDEX ${_quoteIdentifier(index.name)}',
        SqlDialect.postgres =>
          'DROP INDEX ${_schemaQualifiedName(table.schema, index.name)}',
      }),
    ];
  }
}

/// Drops one table.
final class DropSqlTable extends SqlSchemaMigrationOp {
  const DropSqlTable(this.table);

  final SqlTableSchema table;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return [sql('DROP TABLE ${_tableName(table, dialect)}')];
  }
}

final class _TableKey {
  const _TableKey(this.schema, this.name);

  final String? schema;
  final String name;

  @override
  bool operator ==(Object other) {
    return other is _TableKey && other.schema == schema && other.name == name;
  }

  @override
  int get hashCode => Object.hash(schema, name);
}

String _columnDefinition(
  SqlColumnSchema column, {
  bool allowInlinePrimaryKey = true,
  bool allowInlineUnique = true,
}) {
  final parts = <String>[_quoteIdentifier(column.name), column.type];
  if (!column.nullable || column.primaryKey) {
    parts.add('NOT NULL');
  }
  final defaultExpression = column.defaultExpression;
  if (defaultExpression != null) {
    parts.add('DEFAULT $defaultExpression');
  }
  if (allowInlinePrimaryKey && column.primaryKey) {
    parts.add('PRIMARY KEY');
  }
  if (allowInlineUnique && column.unique) {
    parts.add('UNIQUE');
  }
  return parts.join(' ');
}

List<String> _columnReviewDetails(
  SqlColumnSchema current,
  SqlColumnSchema desired,
) {
  return List.unmodifiable({
    ..._postgresColumnReviewDetails(current, desired),
    ..._sqliteColumnReviewDetails(current, desired),
  });
}

List<String> _postgresColumnReviewDetails(
  SqlColumnSchema current,
  SqlColumnSchema desired,
) {
  final details = <String>[];
  if (current.type != desired.type) {
    details.add(
      'type: ${current.type} -> ${desired.type}; add an explicit cast or '
      'data rewrite if existing values need conversion.',
    );
  }
  if (current.nullable && !desired.nullable) {
    details.add(
      'nullable: true -> false; validate or backfill existing NULL values '
      'before enforcing NOT NULL.',
    );
  }
  if (current.primaryKey != desired.primaryKey) {
    details.add(
      'primaryKey: ${current.primaryKey} -> ${desired.primaryKey}; primary '
      'key changes need explicit constraint and data policy.',
    );
  }
  if (current.unique != desired.unique) {
    details.add(
      'unique: ${current.unique} -> ${desired.unique}; validate duplicates '
      'and choose the constraint or index name explicitly.',
    );
  }
  return List.unmodifiable(details);
}

List<String> _sqliteColumnReviewDetails(
  SqlColumnSchema current,
  SqlColumnSchema desired,
) {
  final details = <String>[];
  if (current.type != desired.type) {
    details.add(
      'type: ${current.type} -> ${desired.type}; SQLite requires a table '
      'rebuild and an explicit data copy policy.',
    );
  }
  if (current.nullable != desired.nullable) {
    details.add(
      'nullable: ${current.nullable} -> ${desired.nullable}; SQLite requires '
      'a table rebuild.',
    );
  }
  if (current.primaryKey != desired.primaryKey) {
    details.add(
      'primaryKey: ${current.primaryKey} -> ${desired.primaryKey}; SQLite '
      'requires a table rebuild and explicit key policy.',
    );
  }
  if (current.unique != desired.unique) {
    details.add(
      'unique: ${current.unique} -> ${desired.unique}; validate duplicates '
      'and choose the constraint or index name explicitly.',
    );
  }
  if (current.defaultExpression != desired.defaultExpression) {
    details.add(
      'default: ${_displayNullable(current.defaultExpression)} -> '
      '${_displayNullable(desired.defaultExpression)}; SQLite requires a '
      'table rebuild.',
    );
  }
  return List.unmodifiable(details);
}

String _displayNullable(String? value) => value ?? 'none';

String _tableDisplayName(SqlTableSchema table) {
  return switch (table.schema) {
    final String schema => '$schema.${table.name}',
    null => table.name,
  };
}

String _tableName(SqlTableSchema table, SqlDialect dialect) {
  return switch (dialect) {
    SqlDialect.sqlite => _quoteIdentifier(table.name),
    SqlDialect.postgres => _schemaQualifiedName(table.schema, table.name),
  };
}

String _schemaQualifiedName(String? schema, String name) {
  return switch (schema) {
    final String schemaName =>
      '${_quoteIdentifier(schemaName)}.${_quoteIdentifier(name)}',
    null => _quoteIdentifier(name),
  };
}

String _quoteIdentifier(String identifier) {
  final escaped = identifier.replaceAll('"', '""');
  return '"$escaped"';
}
