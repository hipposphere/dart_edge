import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'sql_migration_plan.dart';
import 'sql_schema_management.dart';

/// Desired SQL database schema used to plan migrations.
final class SqlDatabaseSchema {
  const SqlDatabaseSchema({
    required this.tables,
    this.routines = const <SqlRoutineSchema>[],
    this.extensions = const <SqlExtensionSchema>[],
  });

  /// Tables that should exist in the database.
  final List<SqlTableSchema> tables;

  /// Callable routines that should exist in the database.
  final List<SqlRoutineSchema> routines;

  /// PostgreSQL extensions that should be installed in the database.
  final List<SqlExtensionSchema> extensions;

  Map<String, SqlExtensionSchema> get _extensionByName {
    return <String, SqlExtensionSchema>{
      for (final extension in extensions) extension.name: extension,
    };
  }

  Map<_TableKey, SqlTableSchema> get _tableByKey {
    return <_TableKey, SqlTableSchema>{
      for (final table in tables) _TableKey(table.schema, table.name): table,
    };
  }

  Map<_RoutineKey, SqlRoutineSchema> get _routineByKey {
    return <_RoutineKey, SqlRoutineSchema>{
      for (final routine in routines)
        _RoutineKey(
          routine.schema,
          routine.name,
          _normalizeRoutineIdentityArguments(routine.identityArguments),
        ): routine,
    };
  }
}

/// Desired shape for one SQL table.
final class SqlTableSchema {
  const SqlTableSchema({
    required this.name,
    this.schema,
    this.columns = const <SqlColumnSchema>[],
    this.checks = const <SqlCheckConstraintSchema>[],
    this.uniqueConstraints = const <SqlUniqueConstraintSchema>[],
    this.foreignKeys = const <SqlForeignKeyConstraintSchema>[],
    this.indexes = const <SqlIndexSchema>[],
  });

  /// Table name without schema qualification.
  final String name;

  /// Optional schema name for databases that support schemas.
  final String? schema;

  /// Columns that should exist on this table.
  final List<SqlColumnSchema> columns;

  /// Named table-level CHECK constraints that should exist on this table.
  final List<SqlCheckConstraintSchema> checks;

  /// Named table-level UNIQUE constraints that should exist on this table.
  final List<SqlUniqueConstraintSchema> uniqueConstraints;

  /// Named table-level foreign key constraints that should exist on this table.
  final List<SqlForeignKeyConstraintSchema> foreignKeys;

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

  Map<String, SqlCheckConstraintSchema> get _checkByName {
    return <String, SqlCheckConstraintSchema>{
      for (final check in checks) check.name: check,
    };
  }

  Map<String, SqlUniqueConstraintSchema> get _uniqueConstraintByName {
    return <String, SqlUniqueConstraintSchema>{
      for (final constraint in uniqueConstraints) constraint.name: constraint,
    };
  }

  Map<String, SqlForeignKeyConstraintSchema> get _foreignKeyByName {
    return <String, SqlForeignKeyConstraintSchema>{
      for (final foreignKey in foreignKeys) foreignKey.name: foreignKey,
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
    this.columnOrders = const <String, SqlSortOrder>{},
    this.columnNullsOrders = const <String, SqlNullsOrder>{},
    this.whereExpression,
    this.method,
    this.storageParameters = const <String, Object>{},
    this.postgresOnly = false,
  });

  /// Index name without schema qualification.
  final String name;

  /// Ordered table column names that make up the index.
  final List<String> columns;

  /// Whether this index enforces uniqueness.
  final bool unique;

  /// Optional per-column sort order metadata.
  final Map<String, SqlSortOrder> columnOrders;

  /// Optional per-column null positioning metadata.
  final Map<String, SqlNullsOrder> columnNullsOrders;

  /// Optional raw SQL predicate after `WHERE` for a partial index.
  final String? whereExpression;

  /// Optional PostgreSQL index access method, such as `gin`, `hnsw`, or
  /// extension-provided methods such as `bm25`.
  final String? method;

  /// PostgreSQL index storage parameters rendered after `WITH`.
  ///
  /// String values are quoted as SQL string literals. Numeric and boolean
  /// values are rendered as SQL literals.
  final Map<String, Object> storageParameters;

  /// Whether this index should only be planned for PostgreSQL.
  final bool postgresOnly;
}

/// One PostgreSQL extension required by the desired database schema.
final class SqlExtensionSchema {
  const SqlExtensionSchema({required this.name});

  /// Extension name as registered in `pg_available_extensions`.
  final String name;
}

/// Desired shape for one table-level CHECK constraint.
class SqlCheckConstraintSchema {
  // Keep the public parameter named `expression` while storing it behind a
  // getter so typed helper subclasses can build expressions lazily.
  // ignore: prefer_initializing_formals
  const SqlCheckConstraintSchema({
    required this.name,
    required String expression,
    // ignore: prefer_initializing_formals
  }) : _expression = expression;

  /// Constraint name without schema qualification.
  final String name;

  final String _expression;

  /// Raw SQL expression inside `CHECK (...)`.
  String get expression => _expression;
}

/// Convenience CHECK constraint for string status/enum columns.
final class SqlTextEnumCheckConstraintSchema extends SqlCheckConstraintSchema {
  const SqlTextEnumCheckConstraintSchema({
    required super.name,
    required this.column,
    required this.values,
  }) : super(expression: '');

  /// Column constrained to one of [values].
  final String column;

  /// Allowed database text values.
  final List<String> values;

  @override
  String get expression {
    final allowedValues = values.map(_quoteStringLiteral).join(', ');
    return '${_quoteIdentifier(column)} in ($allowedValues)';
  }
}

/// Desired shape for one table-level UNIQUE constraint.
final class SqlUniqueConstraintSchema {
  const SqlUniqueConstraintSchema({required this.name, required this.columns});

  /// Constraint name without schema qualification.
  final String name;

  /// Ordered table column names that make up the unique constraint.
  final List<String> columns;
}

/// Desired shape for one table-level foreign key constraint.
final class SqlForeignKeyConstraintSchema {
  const SqlForeignKeyConstraintSchema({
    required this.name,
    required this.columns,
    required this.referencesTable,
    required this.referencesColumns,
    this.referencesSchema,
    this.onDelete,
    this.onUpdate,
  });

  /// Constraint name without schema qualification.
  final String name;

  /// Ordered local table column names.
  final List<String> columns;

  /// Optional referenced schema name.
  final String? referencesSchema;

  /// Referenced table name without schema qualification.
  final String referencesTable;

  /// Ordered referenced table column names.
  final List<String> referencesColumns;

  /// Optional action for referenced row deletion.
  final SqlForeignKeyAction? onDelete;

  /// Optional action for referenced row key updates.
  final SqlForeignKeyAction? onUpdate;
}

/// Sort direction for an indexed column.
enum SqlSortOrder {
  ascending('ASC'),
  descending('DESC');

  const SqlSortOrder(this.sql);

  final String sql;
}

/// Null positioning for an indexed column.
enum SqlNullsOrder {
  first('NULLS FIRST'),
  last('NULLS LAST');

  const SqlNullsOrder(this.sql);

  final String sql;
}

/// Action applied by a foreign key when a referenced row changes.
enum SqlForeignKeyAction {
  noAction('NO ACTION'),
  restrict('RESTRICT'),
  cascade('CASCADE'),
  setNull('SET NULL'),
  setDefault('SET DEFAULT');

  const SqlForeignKeyAction(this.sql);

  final String sql;
}

/// Desired shape for one callable SQL routine.
///
/// PostgreSQL RPC functions should use a complete `CREATE OR REPLACE FUNCTION`
/// statement in [definition]. [identityArguments] is the PostgreSQL identity
/// argument list, such as `tenant_id uuid, email text`, used to distinguish
/// overloaded functions and render `DROP FUNCTION` safely.
final class SqlRoutineSchema {
  const SqlRoutineSchema({
    required this.name,
    required this.definition,
    this.schema,
    this.identityArguments = '',
  });

  /// Routine name without schema qualification.
  final String name;

  /// Optional schema name.
  final String? schema;

  /// PostgreSQL identity arguments for the routine signature.
  final String identityArguments;

  /// Full SQL definition used to create or replace the routine.
  final String definition;
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
  const SqlSchemaDiff({
    required this.operations,
    this.ignoredObjects = const <SqlSchemaObject>[],
    this.unsupportedObjects = const <SqlSchemaObject>[],
  });

  /// Typed operations needed to move from the old schema to the desired schema.
  final List<SqlSchemaMigrationOp> operations;

  /// Objects deliberately excluded because another owner manages them.
  final List<SqlSchemaObject> ignoredObjects;

  /// Objects preserved because this diff cannot manage them safely.
  final List<SqlSchemaObject> unsupportedObjects;

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
    SqlSchemaManagementScope scope = const SqlSchemaManagementScope(),
  }) {
    final currentTables = current._tableByKey;
    final desiredTables = desired._tableByKey;
    final currentRoutines = current._routineByKey;
    final desiredRoutines = desired._routineByKey;
    final currentExtensions = current._extensionByName;
    final desiredExtensions = desired._extensionByName;
    final collector = _SqlSchemaDiffCollector(scope);

    for (final entry in desiredExtensions.entries) {
      if (!currentExtensions.containsKey(entry.key)) {
        collector.operations.add(CreateSqlExtension(entry.value));
      }
    }

    for (final entry in desiredTables.entries) {
      final desiredTable = entry.value;
      final currentTable = currentTables[entry.key];
      final tableObject = _tableObject(desiredTable);
      if (!collector.manages(tableObject)) {
        continue;
      }
      if (currentTable == null) {
        collector.operations.add(CreateSqlTable(desiredTable));
        for (final index in desiredTable.indexes) {
          final indexObject = _indexObject(desiredTable, index);
          if (collector.manages(indexObject)) {
            collector.operations.add(
              CreateSqlIndex(table: desiredTable, index: index),
            );
          }
        }
        continue;
      }

      _diffExistingTable(currentTable, desiredTable, collector);
    }

    for (final entry in currentTables.entries) {
      if (!desiredTables.containsKey(entry.key)) {
        final table = entry.value;
        if (collector.manages(_tableObject(table))) {
          collector.operations.add(DropSqlTable(table));
        }
      }
    }

    for (final entry in desiredRoutines.entries) {
      final desiredRoutine = entry.value;
      final currentRoutine = currentRoutines[entry.key];
      final routineObject = _routineObject(desiredRoutine);
      if (!collector.manages(routineObject)) {
        continue;
      }
      if (currentRoutine == null) {
        collector.operations.add(CreateSqlRoutine(desiredRoutine));
      } else if (!_sameRoutine(currentRoutine, desiredRoutine)) {
        collector.operations.add(
          ReplaceSqlRoutine(current: currentRoutine, desired: desiredRoutine),
        );
      }
    }

    for (final entry in currentRoutines.entries) {
      if (!desiredRoutines.containsKey(entry.key)) {
        final routine = entry.value;
        if (collector.manages(_routineObject(routine))) {
          collector.operations.add(DropSqlRoutine(routine));
        }
      }
    }

    return collector.build();
  }

  static void _diffExistingTable(
    SqlTableSchema current,
    SqlTableSchema desired,
    _SqlSchemaDiffCollector collector,
  ) {
    final currentColumns = current._columnByName;
    final desiredColumns = desired._columnByName;

    for (final entry in desiredColumns.entries) {
      final currentColumn = currentColumns[entry.key];
      final desiredColumn = entry.value;
      final columnObject = _columnObject(desired, desiredColumn);
      if (!collector.manages(columnObject)) {
        continue;
      }
      if (currentColumn == null) {
        collector.operations.add(
          AddSqlColumn(table: desired, column: desiredColumn),
        );
      } else if (!_sameColumn(currentColumn, desiredColumn)) {
        collector.operations.add(
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
        final column = entry.value;
        if (collector.manages(_columnObject(current, column))) {
          collector.operations.add(
            DropSqlColumn(table: current, column: column),
          );
        }
      }
    }

    final currentChecks = current._checkByName;
    final desiredChecks = desired._checkByName;
    for (final entry in desiredChecks.entries) {
      final currentCheck = currentChecks[entry.key];
      final desiredCheck = entry.value;
      final checkObject = _checkObject(desired, desiredCheck);
      if (!collector.manages(checkObject)) {
        continue;
      }
      if (currentCheck == null) {
        collector.operations.add(
          AddSqlCheckConstraint(table: desired, check: desiredCheck),
        );
      } else if (!_sameCheck(currentCheck, desiredCheck)) {
        collector.operations.add(
          ReplaceSqlCheckConstraint(
            currentTable: current,
            desiredTable: desired,
            current: currentCheck,
            desired: desiredCheck,
          ),
        );
      }
    }

    for (final entry in currentChecks.entries) {
      if (!desiredChecks.containsKey(entry.key)) {
        final check = entry.value;
        if (collector.manages(_checkObject(current, check))) {
          collector.operations.add(
            DropSqlCheckConstraint(table: current, check: check),
          );
        }
      }
    }

    final currentUniqueConstraints = current._uniqueConstraintByName;
    final desiredUniqueConstraints = desired._uniqueConstraintByName;
    final currentIndexes = current._indexByName;
    final desiredIndexes = desired._indexByName;
    final replacedCurrentUniqueConstraints = <String>{};
    final replacedDesiredUniqueConstraints = <String>{};
    final replacedCurrentIndexes = <String>{};
    final replacedDesiredIndexes = <String>{};

    for (final entry in currentUniqueConstraints.entries) {
      final desiredIndex = desiredIndexes[entry.key];
      if (desiredIndex == null) {
        continue;
      }
      final currentObject = _uniqueConstraintObject(current, entry.value);
      final desiredObject = _indexObject(desired, desiredIndex);
      final managesCurrent = collector.manages(currentObject);
      final managesDesired = collector.manages(desiredObject);
      if (!managesCurrent || !managesDesired) {
        replacedCurrentUniqueConstraints.add(entry.key);
        replacedDesiredIndexes.add(entry.key);
        continue;
      }
      collector.operations.add(
        ReplaceSqlUniqueConstraintWithIndex(
          currentTable: current,
          desiredTable: desired,
          current: entry.value,
          desired: desiredIndex,
        ),
      );
      replacedCurrentUniqueConstraints.add(entry.key);
      replacedDesiredIndexes.add(entry.key);
    }

    for (final entry in currentIndexes.entries) {
      final desiredConstraint = desiredUniqueConstraints[entry.key];
      if (desiredConstraint == null) {
        continue;
      }
      final currentObject = _indexObject(current, entry.value);
      final desiredObject = _uniqueConstraintObject(desired, desiredConstraint);
      final managesCurrent = collector.manages(currentObject);
      final managesDesired = collector.manages(desiredObject);
      if (!managesCurrent || !managesDesired) {
        replacedCurrentIndexes.add(entry.key);
        replacedDesiredUniqueConstraints.add(entry.key);
        continue;
      }
      collector.operations.add(
        ReplaceSqlIndexWithUniqueConstraint(
          currentTable: current,
          desiredTable: desired,
          current: entry.value,
          desired: desiredConstraint,
        ),
      );
      replacedCurrentIndexes.add(entry.key);
      replacedDesiredUniqueConstraints.add(entry.key);
    }

    for (final entry in desiredUniqueConstraints.entries) {
      if (replacedDesiredUniqueConstraints.contains(entry.key)) {
        continue;
      }
      final currentConstraint = currentUniqueConstraints[entry.key];
      final desiredConstraint = entry.value;
      final constraintObject = _uniqueConstraintObject(
        desired,
        desiredConstraint,
      );
      if (!collector.manages(constraintObject)) {
        continue;
      }
      if (currentConstraint == null) {
        collector.operations.add(
          AddSqlUniqueConstraint(table: desired, constraint: desiredConstraint),
        );
      } else if (!_sameUniqueConstraint(currentConstraint, desiredConstraint)) {
        collector.operations.add(
          ReplaceSqlUniqueConstraint(
            currentTable: current,
            desiredTable: desired,
            current: currentConstraint,
            desired: desiredConstraint,
          ),
        );
      }
    }

    for (final entry in currentUniqueConstraints.entries) {
      if (replacedCurrentUniqueConstraints.contains(entry.key)) {
        continue;
      }
      if (!desiredUniqueConstraints.containsKey(entry.key)) {
        final constraint = entry.value;
        if (collector.manages(_uniqueConstraintObject(current, constraint))) {
          collector.operations.add(
            DropSqlUniqueConstraint(table: current, constraint: constraint),
          );
        }
      }
    }

    final currentForeignKeys = current._foreignKeyByName;
    final desiredForeignKeys = desired._foreignKeyByName;
    for (final entry in desiredForeignKeys.entries) {
      final currentForeignKey = currentForeignKeys[entry.key];
      final desiredForeignKey = entry.value;
      final foreignKeyObject = _foreignKeyObject(desired, desiredForeignKey);
      if (!collector.manages(foreignKeyObject)) {
        continue;
      }
      if (currentForeignKey == null) {
        collector.operations.add(
          AddSqlForeignKeyConstraint(
            table: desired,
            foreignKey: desiredForeignKey,
          ),
        );
      } else if (!_sameForeignKey(currentForeignKey, desiredForeignKey)) {
        collector.operations.add(
          ReplaceSqlForeignKeyConstraint(
            currentTable: current,
            desiredTable: desired,
            current: currentForeignKey,
            desired: desiredForeignKey,
          ),
        );
      }
    }

    for (final entry in currentForeignKeys.entries) {
      if (!desiredForeignKeys.containsKey(entry.key)) {
        final foreignKey = entry.value;
        if (collector.manages(_foreignKeyObject(current, foreignKey))) {
          collector.operations.add(
            DropSqlForeignKeyConstraint(table: current, foreignKey: foreignKey),
          );
        }
      }
    }

    for (final entry in desiredIndexes.entries) {
      if (replacedDesiredIndexes.contains(entry.key)) {
        continue;
      }
      final currentIndex = currentIndexes[entry.key];
      final desiredIndex = entry.value;
      final indexObject = _indexObject(desired, desiredIndex);
      if (!collector.manages(indexObject)) {
        continue;
      }
      if (currentIndex == null) {
        collector.operations.add(
          CreateSqlIndex(table: desired, index: desiredIndex),
        );
      } else if (!_sameIndex(currentIndex, desiredIndex)) {
        collector.operations.add(
          ReplaceSqlIndex(
            currentTable: current,
            desiredTable: desired,
            current: currentIndex,
            desired: desiredIndex,
          ),
        );
      }
    }

    for (final entry in currentIndexes.entries) {
      if (replacedCurrentIndexes.contains(entry.key)) {
        continue;
      }
      if (!desiredIndexes.containsKey(entry.key)) {
        final index = entry.value;
        if (collector.manages(_indexObject(current, index))) {
          collector.operations.add(DropSqlIndex(table: current, index: index));
        }
      }
    }
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
        _sameStrings(left.columns, right.columns) &&
        _sameMaps(left.columnOrders, right.columnOrders) &&
        _sameMaps(left.columnNullsOrders, right.columnNullsOrders) &&
        left.method == right.method &&
        _containsMap(left.storageParameters, right.storageParameters) &&
        left.postgresOnly == right.postgresOnly &&
        _normalizeOptionalSqlExpression(left.whereExpression) ==
            _normalizeOptionalSqlExpression(right.whereExpression);
  }

  static bool _sameCheck(
    SqlCheckConstraintSchema left,
    SqlCheckConstraintSchema right,
  ) {
    return _normalizeCheckExpression(left.expression) ==
        _normalizeCheckExpression(right.expression);
  }

  static bool _sameUniqueConstraint(
    SqlUniqueConstraintSchema left,
    SqlUniqueConstraintSchema right,
  ) {
    return _sameStrings(left.columns, right.columns);
  }

  static bool _sameForeignKey(
    SqlForeignKeyConstraintSchema left,
    SqlForeignKeyConstraintSchema right,
  ) {
    return _sameStrings(left.columns, right.columns) &&
        left.referencesSchema == right.referencesSchema &&
        left.referencesTable == right.referencesTable &&
        _sameStrings(left.referencesColumns, right.referencesColumns) &&
        _normalizeForeignKeyAction(left.onDelete) ==
            _normalizeForeignKeyAction(right.onDelete) &&
        _normalizeForeignKeyAction(left.onUpdate) ==
            _normalizeForeignKeyAction(right.onUpdate);
  }

  static bool _sameRoutine(SqlRoutineSchema left, SqlRoutineSchema right) {
    return _normalizeRoutineDefinition(left.definition) ==
        _normalizeRoutineDefinition(right.definition);
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

  static bool _sameMaps<K, V>(Map<K, V> left, Map<K, V> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _containsMap<K, V>(Map<K, V> current, Map<K, V> desired) {
    for (final entry in desired.entries) {
      if (current[entry.key]?.toString() != entry.value.toString()) {
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

final class _SqlSchemaDiffCollector {
  _SqlSchemaDiffCollector(this.scope);

  final SqlSchemaManagementScope scope;
  final List<SqlSchemaMigrationOp> operations = <SqlSchemaMigrationOp>[];
  final List<SqlSchemaObject> ignoredObjects = <SqlSchemaObject>[];
  final List<SqlSchemaObject> unsupportedObjects = <SqlSchemaObject>[];

  bool manages(SqlSchemaObject object) {
    return switch (scope.managementFor(object)) {
      SqlSchemaObjectManagement.managed => true,
      SqlSchemaObjectManagement.unmanaged => _record(ignoredObjects, object),
      SqlSchemaObjectManagement.unsupported => _record(
        unsupportedObjects,
        object,
      ),
    };
  }

  bool _record(List<SqlSchemaObject> target, SqlSchemaObject object) {
    if (!target.any(
      (candidate) =>
          candidate.kind == object.kind &&
          candidate.schema == object.schema &&
          candidate.table == object.table &&
          candidate.name == object.name &&
          candidate.identityArguments == object.identityArguments,
    )) {
      target.add(object);
    }
    return false;
  }

  SqlSchemaDiff build() {
    return SqlSchemaDiff(
      operations: List<SqlSchemaMigrationOp>.unmodifiable(operations),
      ignoredObjects: List<SqlSchemaObject>.unmodifiable(ignoredObjects),
      unsupportedObjects: List<SqlSchemaObject>.unmodifiable(
        unsupportedObjects,
      ),
    );
  }
}

SqlSchemaObject _tableObject(SqlTableSchema table) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.table,
    schema: table.schema,
    name: table.name,
  );
}

SqlSchemaObject _columnObject(SqlTableSchema table, SqlColumnSchema column) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.column,
    schema: table.schema,
    table: table.name,
    name: column.name,
  );
}

SqlSchemaObject _checkObject(
  SqlTableSchema table,
  SqlCheckConstraintSchema check,
) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.checkConstraint,
    schema: table.schema,
    table: table.name,
    name: check.name,
  );
}

SqlSchemaObject _uniqueConstraintObject(
  SqlTableSchema table,
  SqlUniqueConstraintSchema constraint,
) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.uniqueConstraint,
    schema: table.schema,
    table: table.name,
    name: constraint.name,
  );
}

SqlSchemaObject _foreignKeyObject(
  SqlTableSchema table,
  SqlForeignKeyConstraintSchema foreignKey,
) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.foreignKey,
    schema: table.schema,
    table: table.name,
    name: foreignKey.name,
  );
}

SqlSchemaObject _indexObject(SqlTableSchema table, SqlIndexSchema index) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.secondaryIndex,
    schema: table.schema,
    table: table.name,
    name: index.name,
  );
}

SqlSchemaObject _routineObject(SqlRoutineSchema routine) {
  return SqlSchemaObject(
    kind: SqlSchemaObjectKind.routine,
    schema: routine.schema,
    name: routine.name,
    identityArguments: _normalizeRoutineIdentityArguments(
      routine.identityArguments,
    ),
  );
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
    for (final check in table.checks) {
      columns.add(_checkConstraintDefinition(check));
    }
    for (final constraint in table.uniqueConstraints) {
      columns.add(_uniqueConstraintDefinition(constraint));
    }
    for (final foreignKey in table.foreignKeys) {
      columns.add(_foreignKeyConstraintDefinition(foreignKey));
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

/// Adds one CHECK constraint to an existing table.
final class AddSqlCheckConstraint extends SqlSchemaMigrationOp {
  const AddSqlCheckConstraint({required this.table, required this.check});

  final SqlTableSchema table;
  final SqlCheckConstraintSchema check;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems {
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${check.name}',
        summary: 'add check constraint',
        details: ['expression: ${check.expression}'],
        suggestedAction:
            'Validate existing rows satisfy the CHECK expression before '
            'adding the constraint, or use a reviewed database-specific '
            'validation strategy.',
      ),
    ];
  }

  @override
  List<SqlSchemaMigrationReviewItem> reviewItemsForDialect(SqlDialect dialect) {
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${check.name}',
        summary: 'add check constraint',
        details: [
          'expression: ${check.expression}',
          switch (dialect) {
            SqlDialect.postgres =>
              'PostgreSQL validates existing rows when the constraint is '
                  'added unless a reviewed NOT VALID flow is used.',
            SqlDialect.sqlite =>
              'SQLite requires a table rebuild to add table constraints.',
          },
        ],
        suggestedAction:
            'Validate existing rows satisfy the CHECK expression before '
            'adding the constraint, or use a reviewed database-specific '
            'validation strategy.',
      ),
    ];
  }

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'ALTER TABLE ${_tableName(table, dialect)} ADD '
          '${_checkConstraintDefinition(check)}',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Drops one CHECK constraint from an existing table.
final class DropSqlCheckConstraint extends SqlSchemaMigrationOp {
  const DropSqlCheckConstraint({required this.table, required this.check});

  final SqlTableSchema table;
  final SqlCheckConstraintSchema check;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'ALTER TABLE ${_tableName(table, dialect)} '
          'DROP CONSTRAINT ${_quoteIdentifier(check.name)}',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Atomically replaces one changed CHECK constraint after review.
final class ReplaceSqlCheckConstraint extends SqlSchemaMigrationOp {
  const ReplaceSqlCheckConstraint({
    required this.currentTable,
    required this.desiredTable,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema currentTable;
  final SqlTableSchema desiredTable;
  final SqlCheckConstraintSchema current;
  final SqlCheckConstraintSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems => [
    SqlSchemaMigrationReviewItem(
      target: '${_tableDisplayName(desiredTable)}.${desired.name}',
      summary: 'replace check constraint',
      details: [
        'current expression: ${current.expression}',
        'desired expression: ${desired.expression}',
      ],
      suggestedAction:
          'Validate existing rows against the new expression before approving '
          'the atomic drop-and-add replacement.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => _atomicReplacement(
    DropSqlCheckConstraint(
      table: currentTable,
      check: current,
    ).toStatements(dialect),
    AddSqlCheckConstraint(
      table: desiredTable,
      check: desired,
    ).toStatements(dialect),
  );
}

/// Adds one UNIQUE constraint to an existing table.
final class AddSqlUniqueConstraint extends SqlSchemaMigrationOp {
  const AddSqlUniqueConstraint({required this.table, required this.constraint});

  final SqlTableSchema table;
  final SqlUniqueConstraintSchema constraint;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems {
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${constraint.name}',
        summary: 'add unique constraint',
        details: ['columns: ${constraint.columns.join(', ')}'],
        suggestedAction:
            'Validate existing rows do not contain duplicates before adding '
            'the UNIQUE constraint.',
      ),
    ];
  }

  @override
  List<SqlSchemaMigrationReviewItem> reviewItemsForDialect(SqlDialect dialect) {
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${constraint.name}',
        summary: 'add unique constraint',
        details: [
          'columns: ${constraint.columns.join(', ')}',
          switch (dialect) {
            SqlDialect.postgres =>
              'PostgreSQL validates existing rows when the constraint is '
                  'added.',
            SqlDialect.sqlite =>
              'SQLite requires a table rebuild to add table constraints.',
          },
        ],
        suggestedAction:
            'Validate existing rows do not contain duplicates before adding '
            'the UNIQUE constraint.',
      ),
    ];
  }

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'ALTER TABLE ${_tableName(table, dialect)} ADD '
          '${_uniqueConstraintDefinition(constraint)}',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Drops one UNIQUE constraint from an existing table.
final class DropSqlUniqueConstraint extends SqlSchemaMigrationOp {
  const DropSqlUniqueConstraint({
    required this.table,
    required this.constraint,
  });

  final SqlTableSchema table;
  final SqlUniqueConstraintSchema constraint;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'ALTER TABLE ${_tableName(table, dialect)} '
          'DROP CONSTRAINT ${_quoteIdentifier(constraint.name)}',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Atomically replaces one changed UNIQUE constraint after review.
final class ReplaceSqlUniqueConstraint extends SqlSchemaMigrationOp {
  const ReplaceSqlUniqueConstraint({
    required this.currentTable,
    required this.desiredTable,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema currentTable;
  final SqlTableSchema desiredTable;
  final SqlUniqueConstraintSchema current;
  final SqlUniqueConstraintSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems => [
    SqlSchemaMigrationReviewItem(
      target: '${_tableDisplayName(desiredTable)}.${desired.name}',
      summary: 'replace unique constraint',
      details: [
        'current columns: ${current.columns.join(', ')}',
        'desired columns: ${desired.columns.join(', ')}',
      ],
      suggestedAction:
          'Validate uniqueness for the desired columns before approving the '
          'atomic drop-and-add replacement.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => _atomicReplacement(
    DropSqlUniqueConstraint(
      table: currentTable,
      constraint: current,
    ).toStatements(dialect),
    AddSqlUniqueConstraint(
      table: desiredTable,
      constraint: desired,
    ).toStatements(dialect),
  );
}

/// Adds one foreign key constraint to an existing table.
final class AddSqlForeignKeyConstraint extends SqlSchemaMigrationOp {
  const AddSqlForeignKeyConstraint({
    required this.table,
    required this.foreignKey,
  });

  final SqlTableSchema table;
  final SqlForeignKeyConstraintSchema foreignKey;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems {
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${foreignKey.name}',
        summary: 'add foreign key constraint',
        details: [
          'columns: ${foreignKey.columns.join(', ')}',
          'references: ${_foreignKeyReferenceDisplay(foreignKey)}',
        ],
        suggestedAction:
            'Validate existing rows have matching referenced rows before '
            'adding the foreign key.',
      ),
    ];
  }

  @override
  List<SqlSchemaMigrationReviewItem> reviewItemsForDialect(SqlDialect dialect) {
    return [
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${foreignKey.name}',
        summary: 'add foreign key constraint',
        details: [
          'columns: ${foreignKey.columns.join(', ')}',
          'references: ${_foreignKeyReferenceDisplay(foreignKey)}',
          switch (dialect) {
            SqlDialect.postgres =>
              'PostgreSQL validates existing rows when the constraint is '
                  'added unless a reviewed NOT VALID flow is used.',
            SqlDialect.sqlite =>
              'SQLite requires a table rebuild to add table constraints.',
          },
        ],
        suggestedAction:
            'Validate existing rows have matching referenced rows before '
            'adding the foreign key.',
      ),
    ];
  }

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'ALTER TABLE ${_tableName(table, dialect)} ADD '
          '${_foreignKeyConstraintDefinition(foreignKey)}',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Drops one foreign key constraint from an existing table.
final class DropSqlForeignKeyConstraint extends SqlSchemaMigrationOp {
  const DropSqlForeignKeyConstraint({
    required this.table,
    required this.foreignKey,
  });

  final SqlTableSchema table;
  final SqlForeignKeyConstraintSchema foreignKey;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'ALTER TABLE ${_tableName(table, dialect)} '
          'DROP CONSTRAINT ${_quoteIdentifier(foreignKey.name)}',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Atomically replaces one changed foreign key constraint after review.
final class ReplaceSqlForeignKeyConstraint extends SqlSchemaMigrationOp {
  const ReplaceSqlForeignKeyConstraint({
    required this.currentTable,
    required this.desiredTable,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema currentTable;
  final SqlTableSchema desiredTable;
  final SqlForeignKeyConstraintSchema current;
  final SqlForeignKeyConstraintSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems => [
    SqlSchemaMigrationReviewItem(
      target: '${_tableDisplayName(desiredTable)}.${desired.name}',
      summary: 'replace foreign key constraint',
      details: [
        'current reference: ${_foreignKeyReferenceDisplay(current)}',
        'desired reference: ${_foreignKeyReferenceDisplay(desired)}',
      ],
      suggestedAction:
          'Validate existing references and approve the atomic drop-and-add '
          'replacement.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => _atomicReplacement(
    DropSqlForeignKeyConstraint(
      table: currentTable,
      foreignKey: current,
    ).toStatements(dialect),
    AddSqlForeignKeyConstraint(
      table: desiredTable,
      foreignKey: desired,
    ).toStatements(dialect),
  );
}

/// Creates one secondary index.
final class CreateSqlIndex extends SqlSchemaMigrationOp {
  const CreateSqlIndex({required this.table, required this.index});

  final SqlTableSchema table;
  final SqlIndexSchema index;

  @override
  SqlSchemaMigrationSafety get safety =>
      index.method == null &&
          index.storageParameters.isEmpty &&
          !index.postgresOnly
      ? SqlSchemaMigrationSafety.safe
      : SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems {
    if (safety == SqlSchemaMigrationSafety.safe) {
      return const <SqlSchemaMigrationReviewItem>[];
    }
    return <SqlSchemaMigrationReviewItem>[
      SqlSchemaMigrationReviewItem(
        target: '${_tableDisplayName(table)}.${index.name}',
        summary: 'create PostgreSQL-specific index',
        details: <String>[
          if (index.method != null) 'access method: ${index.method}',
          if (index.storageParameters.isNotEmpty)
            'storage parameters: ${index.storageParameters}',
        ],
        suggestedAction:
            'Verify the access method extension and index options are available before applying.',
      ),
    ];
  }

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    if (dialect == SqlDialect.sqlite && index.postgresOnly) {
      return const <SqlStatement>[];
    }
    final unique = index.unique ? 'UNIQUE ' : '';
    final columns = [
      for (final column in index.columns) _indexColumnDefinition(index, column),
    ].join(', ');
    final whereExpression = index.whereExpression;
    final whereClause = whereExpression == null
        ? ''
        : ' WHERE $whereExpression';
    final method = index.method;
    final usingClause = dialect == SqlDialect.postgres && method != null
        ? ' USING ${_quoteIdentifier(method)}'
        : '';
    final storageClause =
        dialect == SqlDialect.postgres && index.storageParameters.isNotEmpty
        ? ' WITH (${index.storageParameters.entries.map(_indexStorageParameter).join(', ')})'
        : '';
    return [
      sql(
        'CREATE ${unique}INDEX ${_quoteIdentifier(index.name)} '
        'ON ${_tableName(table, dialect)}$usingClause ($columns)'
        '$storageClause$whereClause',
      ),
    ];
  }
}

/// Installs one PostgreSQL extension after explicit migration review.
final class CreateSqlExtension extends SqlSchemaMigrationOp {
  const CreateSqlExtension(this.extension);

  final SqlExtensionSchema extension;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem>
  get _reviewItems => <SqlSchemaMigrationReviewItem>[
    SqlSchemaMigrationReviewItem(
      target: extension.name,
      summary: 'install PostgreSQL extension',
      details: <String>['extension: ${extension.name}'],
      suggestedAction:
          'Verify the extension is installed on the PostgreSQL server and approve its database code.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => switch (dialect) {
    SqlDialect.postgres => [
      sql('CREATE EXTENSION IF NOT EXISTS ${_quoteIdentifier(extension.name)}'),
    ],
    SqlDialect.sqlite => const <SqlStatement>[],
  };
}

/// Removes one PostgreSQL extension.
final class DropSqlExtension extends SqlSchemaMigrationOp {
  const DropSqlExtension(this.extension);

  final SqlExtensionSchema extension;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => switch (dialect) {
    SqlDialect.postgres => [
      sql('DROP EXTENSION ${_quoteIdentifier(extension.name)}'),
    ],
    SqlDialect.sqlite => const <SqlStatement>[],
  };
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

/// Atomically replaces one changed secondary index after review.
final class ReplaceSqlIndex extends SqlSchemaMigrationOp {
  const ReplaceSqlIndex({
    required this.currentTable,
    required this.desiredTable,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema currentTable;
  final SqlTableSchema desiredTable;
  final SqlIndexSchema current;
  final SqlIndexSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems => [
    SqlSchemaMigrationReviewItem(
      target: '${_tableDisplayName(desiredTable)}.${desired.name}',
      summary: 'replace index',
      details: [
        'current columns: ${current.columns.join(', ')}',
        'desired columns: ${desired.columns.join(', ')}',
      ],
      suggestedAction:
          'Review locking, uniqueness, access-method, and query-plan impact '
          'before approving the atomic drop-and-create replacement.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => _atomicReplacement(
    DropSqlIndex(table: currentTable, index: current).toStatements(dialect),
    CreateSqlIndex(table: desiredTable, index: desired).toStatements(dialect),
  );
}

/// Replaces a UNIQUE constraint with a same-named index as one reviewed unit.
final class ReplaceSqlUniqueConstraintWithIndex extends SqlSchemaMigrationOp {
  const ReplaceSqlUniqueConstraintWithIndex({
    required this.currentTable,
    required this.desiredTable,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema currentTable;
  final SqlTableSchema desiredTable;
  final SqlUniqueConstraintSchema current;
  final SqlIndexSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems => [
    SqlSchemaMigrationReviewItem(
      target: '${_tableDisplayName(desiredTable)}.${desired.name}',
      summary: 'replace unique constraint with index',
      details: [
        'constraint columns: ${current.columns.join(', ')}',
        'index columns: ${desired.columns.join(', ')}',
      ],
      suggestedAction:
          'Confirm the application does not rely on the named UNIQUE '
          'constraint before approving this representation change.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => _atomicReplacement(
    DropSqlUniqueConstraint(
      table: currentTable,
      constraint: current,
    ).toStatements(dialect),
    CreateSqlIndex(table: desiredTable, index: desired).toStatements(dialect),
  );
}

/// Replaces an index with a same-named UNIQUE constraint as one reviewed unit.
final class ReplaceSqlIndexWithUniqueConstraint extends SqlSchemaMigrationOp {
  const ReplaceSqlIndexWithUniqueConstraint({
    required this.currentTable,
    required this.desiredTable,
    required this.current,
    required this.desired,
  });

  final SqlTableSchema currentTable;
  final SqlTableSchema desiredTable;
  final SqlIndexSchema current;
  final SqlUniqueConstraintSchema desired;

  @override
  SqlSchemaMigrationSafety get safety =>
      SqlSchemaMigrationSafety.requiresReview;

  @override
  List<SqlSchemaMigrationReviewItem> get _reviewItems => [
    SqlSchemaMigrationReviewItem(
      target: '${_tableDisplayName(desiredTable)}.${desired.name}',
      summary: 'replace index with unique constraint',
      details: [
        'index columns: ${current.columns.join(', ')}',
        'constraint columns: ${desired.columns.join(', ')}',
      ],
      suggestedAction:
          'Validate uniqueness and approve the representation change as one '
          'atomic replacement.',
    ),
  ];

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) => _atomicReplacement(
    DropSqlIndex(table: currentTable, index: current).toStatements(dialect),
    AddSqlUniqueConstraint(
      table: desiredTable,
      constraint: desired,
    ).toStatements(dialect),
  );
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

/// Creates one callable routine.
final class CreateSqlRoutine extends SqlSchemaMigrationOp {
  const CreateSqlRoutine(this.routine);

  final SqlRoutineSchema routine;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.safe;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [sql(_trimSql(routine.definition))],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Replaces one callable routine whose definition changed.
final class ReplaceSqlRoutine extends SqlSchemaMigrationOp {
  const ReplaceSqlRoutine({required this.current, required this.desired});

  final SqlRoutineSchema current;
  final SqlRoutineSchema desired;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.safe;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [sql(_trimSql(desired.definition))],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

/// Drops one callable routine.
final class DropSqlRoutine extends SqlSchemaMigrationOp {
  const DropSqlRoutine(this.routine);

  final SqlRoutineSchema routine;

  @override
  SqlSchemaMigrationSafety get safety => SqlSchemaMigrationSafety.destructive;

  @override
  List<SqlStatement> toStatements(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => [
        sql(
          'DROP FUNCTION ${_schemaQualifiedName(routine.schema, routine.name)}'
          '(${routine.identityArguments})',
        ),
      ],
      SqlDialect.sqlite => const <SqlStatement>[],
    };
  }
}

List<SqlStatement> _atomicReplacement(
  List<SqlStatement> remove,
  List<SqlStatement> create,
) {
  if (remove.isEmpty || create.isEmpty) {
    return const <SqlStatement>[];
  }
  return List<SqlStatement>.unmodifiable(<SqlStatement>[...remove, ...create]);
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

final class _RoutineKey {
  const _RoutineKey(this.schema, this.name, this.identityArguments);

  final String? schema;
  final String name;
  final String identityArguments;

  @override
  bool operator ==(Object other) {
    return other is _RoutineKey &&
        other.schema == schema &&
        other.name == name &&
        other.identityArguments == identityArguments;
  }

  @override
  int get hashCode => Object.hash(schema, name, identityArguments);
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

String _checkConstraintDefinition(SqlCheckConstraintSchema check) {
  return 'CONSTRAINT ${_quoteIdentifier(check.name)} '
      'CHECK (${check.expression})';
}

String _uniqueConstraintDefinition(SqlUniqueConstraintSchema constraint) {
  final columns = constraint.columns.map(_quoteIdentifier).join(', ');
  return 'CONSTRAINT ${_quoteIdentifier(constraint.name)} UNIQUE ($columns)';
}

String _foreignKeyConstraintDefinition(
  SqlForeignKeyConstraintSchema foreignKey,
) {
  final columns = foreignKey.columns.map(_quoteIdentifier).join(', ');
  final referencedColumns = foreignKey.referencesColumns
      .map(_quoteIdentifier)
      .join(', ');
  final parts = <String>[
    'CONSTRAINT ${_quoteIdentifier(foreignKey.name)}',
    'FOREIGN KEY ($columns)',
    'REFERENCES ${_schemaQualifiedName(foreignKey.referencesSchema, foreignKey.referencesTable)} '
        '($referencedColumns)',
  ];
  final onDelete = foreignKey.onDelete;
  if (onDelete != null && onDelete != SqlForeignKeyAction.noAction) {
    parts.add('ON DELETE ${onDelete.sql}');
  }
  final onUpdate = foreignKey.onUpdate;
  if (onUpdate != null && onUpdate != SqlForeignKeyAction.noAction) {
    parts.add('ON UPDATE ${onUpdate.sql}');
  }
  return parts.join(' ');
}

String _indexColumnDefinition(SqlIndexSchema index, String column) {
  final parts = <String>[_quoteIdentifier(column)];
  final order = index.columnOrders[column];
  if (order != null) {
    parts.add(order.sql);
  }
  final nullsOrder = index.columnNullsOrders[column];
  if (nullsOrder != null) {
    parts.add(nullsOrder.sql);
  }
  return parts.join(' ');
}

String _indexStorageParameter(MapEntry<String, Object> entry) {
  final value = switch (entry.value) {
    final String value => _quoteStringLiteral(value),
    final bool value => value ? 'true' : 'false',
    final num value => value.toString(),
    final Object value => throw ArgumentError.value(
      value,
      'storageParameters[${entry.key}]',
      'Only String, num, and bool values are supported.',
    ),
  };
  return '${_quoteIdentifier(entry.key)} = $value';
}

String _foreignKeyReferenceDisplay(SqlForeignKeyConstraintSchema foreignKey) {
  return '${_schemaQualifiedName(foreignKey.referencesSchema, foreignKey.referencesTable)}'
      '(${foreignKey.referencesColumns.join(', ')})';
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

String _trimSql(String sql) => sql.trim();

String _normalizeRoutineDefinition(String definition) {
  return _trimSql(
    definition
        .replaceAllMapped(
          RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$'),
          (match) => ' ${match.group(0)} ',
        )
        .replaceAll(RegExp(r'\s+'), ' '),
  ).replaceFirst(RegExp(r';$'), '');
}

String _normalizeRoutineIdentityArguments(String identityArguments) {
  return identityArguments.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? _normalizeOptionalSqlExpression(String? expression) {
  return expression?.trim().replaceAll(RegExp(r'\s+'), ' ');
}

SqlForeignKeyAction _normalizeForeignKeyAction(SqlForeignKeyAction? action) {
  return action ?? SqlForeignKeyAction.noAction;
}

String _normalizeCheckExpression(String expression) {
  final stripped = _stripCheckKeyword(
    expression,
  ).replaceFirst(RegExp(r';\s*$'), '').trim();
  final normalizedWhitespace = _stripOuterParentheses(
    stripped,
  ).replaceAll(RegExp(r'\s+'), ' ');
  return _normalizeEnumCheckExpression(normalizedWhitespace) ??
      normalizedWhitespace;
}

String _stripCheckKeyword(String expression) {
  final trimmed = expression.trim();
  if (!trimmed.startsWith(RegExp('CHECK\\s*\\(', caseSensitive: false))) {
    return trimmed;
  }
  final openIndex = trimmed.indexOf('(');
  final content = trimmed.substring(openIndex + 1);
  if (!content.endsWith(')')) {
    return content;
  }
  return content.substring(0, content.length - 1);
}

String _stripOuterParentheses(String expression) {
  var current = expression.trim();
  while (current.length >= 2 &&
      current.startsWith('(') &&
      current.endsWith(')') &&
      _outerParenthesesWrapWholeExpression(current)) {
    current = current.substring(1, current.length - 1).trim();
  }
  return current;
}

bool _outerParenthesesWrapWholeExpression(String expression) {
  var depth = 0;
  for (var index = 0; index < expression.length; index += 1) {
    final character = expression[index];
    if (character == '(') {
      depth += 1;
    } else if (character == ')') {
      depth -= 1;
      if (depth == 0 && index != expression.length - 1) {
        return false;
      }
      if (depth < 0) {
        return false;
      }
    }
  }
  return depth == 0;
}

String? _normalizeEnumCheckExpression(String expression) {
  final inMatch = RegExp(
    r'^"?([A-Za-z_][A-Za-z0-9_]*)"?\s+in\s*\((.*)\)$',
    caseSensitive: false,
  ).firstMatch(expression);
  if (inMatch != null) {
    return _normalizedEnumCheck(
      inMatch.group(1)!,
      _normalizeSqlLiteralList(inMatch.group(2)!),
    );
  }

  final anyMatch = RegExp(
    r'^"?([A-Za-z_][A-Za-z0-9_]*)"?\s*=\s*ANY\s*'
    r'\(\s*ARRAY\s*\[(.*)\]\s*\)$',
    caseSensitive: false,
  ).firstMatch(expression);
  if (anyMatch != null) {
    return _normalizedEnumCheck(
      anyMatch.group(1)!,
      _normalizeSqlLiteralList(anyMatch.group(2)!),
    );
  }

  return null;
}

String _normalizedEnumCheck(String column, List<String> values) {
  return '${column.toLowerCase()} IN (${values.join(', ')})';
}

List<String> _normalizeSqlLiteralList(String text) {
  return [
    for (final value in text.split(','))
      value.trim().replaceFirst(
        RegExp(r'::[A-Za-z_][A-Za-z0-9_]*(\[\])?$'),
        '',
      ),
  ];
}

String _quoteStringLiteral(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
