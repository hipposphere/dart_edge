import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'sql_schema_introspector.dart';
import 'sql_schema_management.dart';
import 'sql_schema_migration.dart';

/// PostgreSQL-backed schema canonicalization and diff orchestration.
///
/// [canonicalizationExecutor] must point at a fresh disposable PostgreSQL or
/// PGlite database. The engine materializes [desired] there so PostgreSQL can
/// canonicalize defaults, predicates, checks, types, and routine definitions
/// before comparing them with the introspected current database.
final class PostgresSchemaDiffEngine {
  const PostgresSchemaDiffEngine({
    required this.schemas,
    this.scope = const SqlSchemaManagementScope(),
    this.skipExtensionInstallation = const <String>{},
  });

  final List<String> schemas;
  final SqlSchemaManagementScope scope;

  /// Desired extensions that the scratch backend cannot install.
  ///
  /// Their names remain in the canonical desired schema, but callers must
  /// ensure schema objects do not depend on unavailable extension behavior.
  final Set<String> skipExtensionInstallation;

  /// Computes a canonical PostgreSQL schema diff without writing files.
  Future<SqlSchemaDiff> diff({
    required SqlExecutor currentExecutor,
    required SqlExecutor canonicalizationExecutor,
    required SqlDatabaseSchema desired,
  }) async {
    _requirePostgres(currentExecutor, 'currentExecutor');
    _requirePostgres(canonicalizationExecutor, 'canonicalizationExecutor');
    if (identical(currentExecutor, canonicalizationExecutor)) {
      throw ArgumentError(
        'currentExecutor and canonicalizationExecutor must target separate '
        'databases.',
      );
    }

    final introspector = PostgresSchemaIntrospector(schemas: schemas);
    final current = await introspector.introspect(currentExecutor);
    final canonicalDesired = await PostgresSchemaCanonicalizer(
      schemas: schemas,
      skipExtensionInstallation: skipExtensionInstallation,
    ).canonicalize(executor: canonicalizationExecutor, desired: desired);

    return SqlSchemaDiff.between(
      current: current,
      desired: canonicalDesired,
      scope: scope,
    );
  }

  /// Runs a true non-writing schema check suitable for CI and command tools.
  Future<SqlSchemaCheckResult> check({
    required SqlExecutor currentExecutor,
    required SqlExecutor canonicalizationExecutor,
    required SqlDatabaseSchema desired,
  }) async {
    return SqlSchemaCheckResult(
      await diff(
        currentExecutor: currentExecutor,
        canonicalizationExecutor: canonicalizationExecutor,
        desired: desired,
      ),
    );
  }
}

/// Materializes and re-introspects a desired schema in PostgreSQL.
final class PostgresSchemaCanonicalizer {
  const PostgresSchemaCanonicalizer({
    required this.schemas,
    this.skipExtensionInstallation = const <String>{},
  });

  final List<String> schemas;
  final Set<String> skipExtensionInstallation;

  /// Returns the PostgreSQL-canonical representation of [desired].
  ///
  /// The supplied [executor] must target a fresh disposable database. Existing
  /// tables or routines in the selected schemas are rejected before any writes.
  Future<SqlDatabaseSchema> canonicalize({
    required SqlExecutor executor,
    required SqlDatabaseSchema desired,
  }) async {
    _requirePostgres(executor, 'executor');
    final introspector = PostgresSchemaIntrospector(schemas: schemas);
    final existing = await introspector.introspect(executor);
    if (existing.tables.isNotEmpty || existing.routines.isNotEmpty) {
      throw StateError(
        'PostgreSQL schema canonicalization requires a fresh disposable '
        'database; found ${existing.tables.length} tables and '
        '${existing.routines.length} routines.',
      );
    }

    _validateDesiredSchemas(desired);
    await _createSchemas(executor, desired);

    for (final extension in desired.extensions) {
      if (skipExtensionInstallation.contains(extension.name)) {
        continue;
      }
      await _executeOperation(executor, CreateSqlExtension(extension));
    }

    // Foreign keys are added after every table exists, so cyclic and
    // forward-referencing schemas can still be canonicalized.
    for (final table in desired.tables) {
      await _executeOperation(
        executor,
        CreateSqlTable(
          SqlTableSchema(
            name: table.name,
            schema: table.schema,
            columns: table.columns,
            checks: table.checks,
            uniqueConstraints: table.uniqueConstraints,
          ),
        ),
      );
    }

    // Indexes, especially UNIQUE indexes, must exist before foreign keys that
    // use them as referenced keys.
    for (final table in desired.tables) {
      for (final index in table.indexes) {
        await _executeOperation(
          executor,
          CreateSqlIndex(table: table, index: index),
        );
      }
    }

    for (final table in desired.tables) {
      for (final foreignKey in table.foreignKeys) {
        await _executeOperation(
          executor,
          AddSqlForeignKeyConstraint(table: table, foreignKey: foreignKey),
        );
      }
    }

    for (final routine in desired.routines) {
      await _executeOperation(executor, CreateSqlRoutine(routine));
    }

    final canonical = await introspector.introspect(executor);
    final desiredTables = {
      for (final table in desired.tables)
        _tableKey(_postgresSchema(table.schema), table.name),
    };
    final desiredRoutines = {
      for (final routine in desired.routines)
        _routineKey(
          _postgresSchema(routine.schema),
          routine.name,
          routine.identityArguments,
        ),
    };
    final result = SqlDatabaseSchema(
      tables: List<SqlTableSchema>.unmodifiable(
        canonical.tables.where(
          (table) =>
              desiredTables.contains(_tableKey(table.schema, table.name)),
        ),
      ),
      routines: List<SqlRoutineSchema>.unmodifiable(
        canonical.routines.where(
          (routine) => desiredRoutines.contains(
            _routineKey(
              _postgresSchema(routine.schema),
              routine.name,
              routine.identityArguments,
            ),
          ),
        ),
      ),
      // Extension schemas only contain a name, so PostgreSQL has no richer
      // representation to canonicalize. Preserve desired requirements even
      // when the scratch backend cannot install one of them.
      extensions: List<SqlExtensionSchema>.unmodifiable(desired.extensions),
    );

    if (result.tables.length != desired.tables.length ||
        result.routines.length != desired.routines.length) {
      throw StateError(
        'PostgreSQL did not expose every desired schema object after '
        'canonicalization.',
      );
    }
    return result;
  }

  void _validateDesiredSchemas(SqlDatabaseSchema desired) {
    final allowed = schemas.toSet();
    final requested = <String>{
      for (final table in desired.tables) _postgresSchema(table.schema),
      for (final routine in desired.routines) _postgresSchema(routine.schema),
    };
    final missing = requested.difference(allowed);
    if (missing.isNotEmpty) {
      throw ArgumentError.value(
        missing.toList()..sort(),
        'desired',
        'Desired schema objects use schemas not configured for introspection.',
      );
    }
  }

  Future<void> _createSchemas(
    SqlExecutor executor,
    SqlDatabaseSchema desired,
  ) async {
    final schemaNames = <String>{
      for (final table in desired.tables)
        if (table.schema != null && table.schema != 'public') table.schema!,
      for (final routine in desired.routines)
        if (routine.schema != null && routine.schema != 'public')
          routine.schema!,
    }.toList()..sort();
    for (final schema in schemaNames) {
      await executor.execute(
        sql('CREATE SCHEMA IF NOT EXISTS ${_quoteIdentifier(schema)}'),
      );
    }
  }

  Future<void> _executeOperation(
    SqlExecutor executor,
    SqlSchemaMigrationOp operation,
  ) async {
    for (final statement in operation.toStatements(SqlDialect.postgres)) {
      await executor.execute(statement);
    }
  }
}

/// Result of a non-writing schema check.
final class SqlSchemaCheckResult {
  const SqlSchemaCheckResult(this.diff);

  final SqlSchemaDiff diff;

  /// Whether every managed object matches the desired schema.
  bool get matches => diff.operations.isEmpty;

  /// Conventional process exit code for command-line check modes.
  int get exitCode => matches ? 0 : 1;

  /// Throws [SqlSchemaDriftException] when managed schema drift exists.
  void throwIfDrift() {
    if (!matches) {
      throw SqlSchemaDriftException(this);
    }
  }

  /// Formats a concise CLI-friendly check report.
  String format() {
    final buffer = StringBuffer(
      matches
          ? 'Schema matches the desired state.'
          : 'Schema drift detected (${diff.operations.length} operations):',
    );
    for (final operation in diff.operations) {
      buffer
        ..writeln()
        ..write('- ${operation.runtimeType} (${operation.safety.name})');
    }
    if (diff.ignoredObjects.isNotEmpty) {
      buffer
        ..writeln()
        ..write('Ignored unmanaged objects: ${diff.ignoredObjects.length}');
    }
    if (diff.unsupportedObjects.isNotEmpty) {
      buffer
        ..writeln()
        ..write(
          'Preserved unsupported objects: ${diff.unsupportedObjects.length}',
        );
    }
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// Raised when [SqlSchemaCheckResult.throwIfDrift] finds managed drift.
final class SqlSchemaDriftException implements Exception {
  const SqlSchemaDriftException(this.result);

  final SqlSchemaCheckResult result;

  @override
  String toString() => result.format();
}

void _requirePostgres(SqlExecutor executor, String parameterName) {
  if (executor.dialect != SqlDialect.postgres) {
    throw ArgumentError.value(
      executor.dialect,
      parameterName,
      'PostgreSQL schema canonicalization requires a PostgreSQL executor.',
    );
  }
}

String _tableKey(String? schema, String name) => '${schema ?? ''}\u0000$name';

String _postgresSchema(String? schema) => schema ?? 'public';

String _routineKey(String? schema, String name, String identityArguments) {
  final normalizedArguments = identityArguments.trim().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  return '${schema ?? ''}\u0000$name\u0000$normalizedArguments';
}

String _quoteIdentifier(String identifier) {
  return '"${identifier.replaceAll('"', '""')}"';
}
