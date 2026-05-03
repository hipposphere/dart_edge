import 'package:dart_edge_sql/dart_edge_sql.dart';

import '../codegen/sql_codegen_config.dart';
import 'introspected_database.dart';
import 'sql_database_introspector.dart';

/// PostgreSQL schema introspector.
final class PostgresIntrospector implements SqlDatabaseIntrospector {
  PostgresIntrospector({
    required this.connectionString,
    Set<String> schemas = const {'public'},
    Set<String> includeTables = const <String>{},
    Set<String> excludeTables = const <String>{},
  }) : _database = null,
       schemas = _normalizeSchemas(schemas),
       includeTables = Set<String>.unmodifiable(includeTables),
       excludeTables = Set<String>.unmodifiable(excludeTables);

  /// Introspects an already-open `dart_edge_sql` PostgreSQL database.
  PostgresIntrospector.fromDatabase(
    PostgresPool database, {
    Set<String> schemas = const {'public'},
    Set<String> includeTables = const <String>{},
    Set<String> excludeTables = const <String>{},
  }) : connectionString = database.connectionString,
       _database = database,
       schemas = _normalizeSchemas(schemas),
       includeTables = Set<String>.unmodifiable(includeTables),
       excludeTables = Set<String>.unmodifiable(excludeTables);

  /// PostgreSQL connection string used to open the schema-inspection pool.
  final String connectionString;

  final PostgresPool? _database;

  /// Schema names to introspect.
  final Set<String> schemas;

  /// Optional allow-list of tables to include.
  final Set<String> includeTables;

  /// Optional block-list of tables to exclude.
  final Set<String> excludeTables;

  @override
  Future<IntrospectedDatabase> introspect() async {
    final (database, ownsDatabase) = switch (_database) {
      final database? => (database, false),
      null => (PostgresPool.withUrl(connectionString), true),
    };

    try {
      final raw = database.raw;
      final schemaPredicate = _schemaPredicate(
        raw,
        'namespaces.nspname',
        schemas,
      );
      final rows = await _columnsQuery(raw, schemaPredicate).execute();
      final enumRows = await _enumsQuery(raw, schemaPredicate).execute();
      final constraintRows = await _constraintsQuery(
        raw,
        schemaPredicate,
      ).execute();
      final routineRows = await _routinesQuery(raw, schemaPredicate).execute();

      final enums = <IntrospectedEnum>[];
      for (final row in enumRows) {
        enums.add(
          IntrospectedEnum(
            name: row.read<String>('enum_name'),
            schema: row.read<String>('enum_schema'),
            values: row.read<List<Object?>>('enum_values').cast<String>(),
          ),
        );
      }
      final enumValuesByType = {
        for (final value in enums)
          (schema: _schemaName(value.schema), name: value.name): value.values,
      };
      enums.sort((left, right) {
        final schemaCompare = (left.schema ?? '').compareTo(right.schema ?? '');
        if (schemaCompare != 0) {
          return schemaCompare;
        }
        return left.name.compareTo(right.name);
      });

      final constraintsByTable =
          <
            ({String schema, String table}),
            List<IntrospectedTableConstraint>
          >{};
      for (final row in constraintRows) {
        final tableName = row.read<String>('table_name');
        if (!_shouldIncludeTable(tableName)) {
          continue;
        }

        final tableSchema = row.read<String>('table_schema');
        final key = (schema: tableSchema, table: tableName);
        constraintsByTable
            .putIfAbsent(key, () => <IntrospectedTableConstraint>[])
            .add(
              IntrospectedTableConstraint(
                name: row.read<String>('constraint_name'),
                kind: _constraintKind(row.read<String>('constraint_type')),
                columns: row.read<List<Object?>>('columns').cast<String>(),
                referencedSchema: row.readNullable<String>('referenced_schema'),
                referencedTable: row.readNullable<String>('referenced_table'),
                referencedColumns: row
                    .read<List<Object?>>('referenced_columns')
                    .cast<String>(),
                expression: row.readNullable<String>('expression'),
              ),
            );
      }

      final columnsByTable =
          <({String schema, String table}), List<IntrospectedColumn>>{};
      for (final row in rows) {
        final tableName = row.read<String>('table_name');
        if (!_shouldIncludeTable(tableName)) {
          continue;
        }

        final tableSchema = row.read<String>('table_schema');
        final key = (schema: tableSchema, table: tableName);
        final columns = columnsByTable.putIfAbsent(
          key,
          () => <IntrospectedColumn>[],
        );
        final databaseType = row.read<String>('database_type');
        final typeKind = row.read<String>('type_kind');
        final typeSchema = row.read<String>('type_schema');
        final typeName = row.read<String>('type_name');
        final enumName = typeKind == 'e' ? typeName : null;
        columns.add(
          IntrospectedColumn(
            name: row.read<String>('column_name'),
            databaseType: databaseType,
            dartType: enumName == null
                ? _mapPostgresType(databaseType)
                : _enumClassName(enumName),
            nullable: row.read<bool>('is_nullable'),
            hasDefault: row.read<bool>('has_default'),
            defaultExpression: row.readNullable<String>('default_expression'),
            primaryKey: row.read<bool>('is_primary_key'),
            enumName: enumName,
            enumSchema: enumName == null ? null : typeSchema,
            enumValues: enumName == null
                ? const <String>[]
                : enumValuesByType[(
                        schema: _schemaName(typeSchema),
                        name: enumName,
                      )] ??
                      const <String>[],
          ),
        );
      }

      final tables =
          columnsByTable.entries
              .map(
                (entry) => IntrospectedTable(
                  name: entry.key.table,
                  schema: entry.key.schema,
                  columns: List<IntrospectedColumn>.unmodifiable(entry.value),
                  constraints: List<IntrospectedTableConstraint>.unmodifiable(
                    constraintsByTable[entry.key] ??
                        const <IntrospectedTableConstraint>[],
                  ),
                ),
              )
              .toList(growable: false)
            ..sort((left, right) {
              final schemaCompare = (left.schema ?? '').compareTo(
                right.schema ?? '',
              );
              if (schemaCompare != 0) {
                return schemaCompare;
              }
              return left.name.compareTo(right.name);
            });

      final routines = <IntrospectedRoutine>[];
      for (final row in routineRows) {
        final databaseType = row.read<String>('return_database_type');
        routines.add(
          IntrospectedRoutine(
            name: row.read<String>('routine_name'),
            schema: row.read<String>('routine_schema'),
            kind: IntrospectedRoutineKind.values.byName(
              row.read<String>('routine_kind'),
            ),
            returnDatabaseType: databaseType,
            returnDartType: _mapPostgresType(databaseType),
            returnsSet: row.read<bool>('returns_set'),
            parameters: [
              for (final parameter in row.read<List<Object?>>('parameters'))
                _routineParameterFromJson(parameter! as Map<String, Object?>),
            ],
          ),
        );
      }
      routines.sort((left, right) {
        final schemaCompare = (left.schema ?? '').compareTo(right.schema ?? '');
        if (schemaCompare != 0) {
          return schemaCompare;
        }
        return left.name.compareTo(right.name);
      });

      return IntrospectedDatabase(
        dialect: SqlCodegenDialect.postgres,
        tables: tables,
        enums: List<IntrospectedEnum>.unmodifiable(enums),
        routines: List<IntrospectedRoutine>.unmodifiable(routines),
      );
    } finally {
      if (ownsDatabase) {
        await database.close();
      }
    }
  }

  bool _shouldIncludeTable(String tableName) {
    if (excludeTables.contains(tableName)) {
      return false;
    }
    if (includeTables.isEmpty) {
      return true;
    }
    return includeTables.contains(tableName);
  }
}

IntrospectedTableConstraintKind _constraintKind(String type) {
  return switch (type) {
    'p' => IntrospectedTableConstraintKind.primaryKey,
    'u' => IntrospectedTableConstraintKind.unique,
    'f' => IntrospectedTableConstraintKind.foreignKey,
    'c' => IntrospectedTableConstraintKind.check,
    _ => throw StateError('Unsupported PostgreSQL constraint type "$type".'),
  };
}

String _enumClassName(String enumName) {
  final parts = enumName
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        final sanitized = part.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
        if (sanitized.isEmpty) {
          return 'Value';
        }
        final prefixed = RegExp(r'^[0-9]').hasMatch(sanitized)
            ? 'N$sanitized'
            : sanitized;
        return '${prefixed[0].toUpperCase()}${prefixed.substring(1)}';
      })
      .toList(growable: false);
  return parts.isEmpty ? 'GeneratedEnum' : parts.join();
}

String _schemaName(String? schema) {
  final normalized = schema?.trim();
  if (normalized == null || normalized.isEmpty) {
    return 'default';
  }
  return normalized;
}

Set<String> _normalizeSchemas(Set<String> schemas) {
  final normalized = schemas
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (normalized.isEmpty) {
    return const {'public'};
  }
  return Set<String>.unmodifiable(normalized);
}

SqlPredicate _schemaPredicate(
  SqlRawQueryRoot raw,
  String expression,
  Set<String> schemas,
) {
  final predicates = [for (final schema in schemas) raw.eq(expression, schema)];
  return predicates.length == 1 ? predicates.single : .or(predicates);
}

IntrospectedRoutineParameter _routineParameterFromJson(
  Map<String, Object?> json,
) {
  final databaseType = json['databaseType']! as String;
  return IntrospectedRoutineParameter(
    name: json['name']! as String,
    databaseType: databaseType,
    dartType: _mapPostgresType(databaseType),
  );
}

SelectedSelectQueryBuilder<SqlRow> _columnsQuery(
  SqlRawQueryRoot raw,
  SqlPredicate schemaPredicate,
) {
  return raw
      .from('pg_catalog.pg_class', alias: 'table_classes')
      .innerJoin(
        'pg_catalog.pg_namespace',
        alias: 'namespaces',
        on: raw.eqRef('namespaces.oid', 'table_classes.relnamespace'),
      )
      .innerJoin(
        'pg_catalog.pg_attribute',
        alias: 'attributes',
        on: raw.eqRef('attributes.attrelid', 'table_classes.oid'),
      )
      .innerJoin(
        'pg_catalog.pg_type',
        alias: 'types',
        on: raw.eqRef('types.oid', 'attributes.atttypid'),
      )
      .innerJoin(
        'pg_catalog.pg_namespace',
        alias: 'type_namespaces',
        on: raw.eqRef('type_namespaces.oid', 'types.typnamespace'),
      )
      .leftJoin(
        'pg_catalog.pg_attrdef',
        alias: 'defaults',
        on: raw.and([
          raw.eqRef('defaults.adrelid', 'table_classes.oid'),
          raw.eqRef('defaults.adnum', 'attributes.attnum'),
        ]),
      )
      .leftJoin(
        'pg_catalog.pg_constraint',
        alias: 'primary_keys',
        on: raw.and([
          raw.eqRef('primary_keys.conrelid', 'table_classes.oid'),
          raw.eq('primary_keys.contype', 'p'),
          .raw('attributes.attnum = ANY(primary_keys.conkey)'),
        ]),
      )
      .select(const [
        'namespaces.nspname AS table_schema',
        'table_classes.relname AS table_name',
        'attributes.attname AS column_name',
        'types.typname AS database_type',
        'type_namespaces.nspname AS type_schema',
        'types.typname AS type_name',
        'types.typtype AS type_kind',
        'NOT attributes.attnotnull AS is_nullable',
        'attributes.atthasdef AS has_default',
        'pg_catalog.pg_get_expr(defaults.adbin, defaults.adrelid) AS default_expression',
        'primary_keys.oid IS NOT NULL AS is_primary_key',
      ])
      .where(.raw("table_classes.relkind IN ('r', 'p')"))
      .where(raw.gt('attributes.attnum', 0))
      .where(raw.isFalse('attributes.attisdropped'))
      .where(schemaPredicate)
      .orderBy('table_classes.relname')
      .orderBy('attributes.attnum');
}

SelectedSelectQueryBuilder<SqlRow> _enumsQuery(
  SqlRawQueryRoot raw,
  SqlPredicate schemaPredicate,
) {
  return raw
      .from('pg_catalog.pg_type', alias: 'types')
      .innerJoin(
        'pg_catalog.pg_namespace',
        alias: 'namespaces',
        on: raw.eqRef('namespaces.oid', 'types.typnamespace'),
      )
      .innerJoin(
        'pg_catalog.pg_enum',
        alias: 'enum_values',
        on: raw.eqRef('enum_values.enumtypid', 'types.oid'),
      )
      .select(const [
        'namespaces.nspname AS enum_schema',
        'types.typname AS enum_name',
        'array_agg(enum_values.enumlabel ORDER BY enum_values.enumsortorder) AS enum_values',
      ])
      .where(raw.eq('types.typtype', 'e'))
      .where(schemaPredicate)
      .groupBy('namespaces.nspname')
      .groupBy('types.typname')
      .orderBy('namespaces.nspname')
      .orderBy('types.typname');
}

SelectedSelectQueryBuilder<SqlRow> _constraintsQuery(
  SqlRawQueryRoot raw,
  SqlPredicate schemaPredicate,
) {
  return raw
      .from('pg_catalog.pg_constraint', alias: 'constraints')
      .innerJoin(
        'pg_catalog.pg_class',
        alias: 'table_classes',
        on: raw.eqRef('table_classes.oid', 'constraints.conrelid'),
      )
      .innerJoin(
        'pg_catalog.pg_namespace',
        alias: 'namespaces',
        on: raw.eqRef('namespaces.oid', 'table_classes.relnamespace'),
      )
      .leftJoin(
        'pg_catalog.pg_class',
        alias: 'referenced_classes',
        on: raw.eqRef('referenced_classes.oid', 'constraints.confrelid'),
      )
      .leftJoin(
        'pg_catalog.pg_namespace',
        alias: 'referenced_namespaces',
        on: raw.eqRef(
          'referenced_namespaces.oid',
          'referenced_classes.relnamespace',
        ),
      )
      .leftJoin(
        '''
LATERAL (
  SELECT array_agg(attributes.attname ORDER BY keys.ordinality) AS columns
  FROM unnest(constraints.conkey) WITH ORDINALITY AS keys(attnum, ordinality)
  JOIN pg_catalog.pg_attribute AS attributes
    ON attributes.attrelid = constraints.conrelid
   AND attributes.attnum = keys.attnum
)''',
        alias: 'local_columns',
        on: 'TRUE',
      )
      .leftJoin(
        '''
LATERAL (
  SELECT array_agg(attributes.attname ORDER BY keys.ordinality) AS columns
  FROM unnest(constraints.confkey) WITH ORDINALITY AS keys(attnum, ordinality)
  JOIN pg_catalog.pg_attribute AS attributes
    ON attributes.attrelid = constraints.confrelid
   AND attributes.attnum = keys.attnum
)''',
        alias: 'referenced_columns',
        on: 'TRUE',
      )
      .select(const [
        'namespaces.nspname AS table_schema',
        'table_classes.relname AS table_name',
        'constraints.conname AS constraint_name',
        'constraints.contype AS constraint_type',
        'COALESCE(local_columns.columns, ARRAY[]::text[]) AS columns',
        'referenced_namespaces.nspname AS referenced_schema',
        'referenced_classes.relname AS referenced_table',
        'COALESCE(referenced_columns.columns, ARRAY[]::text[]) AS referenced_columns',
        '''
CASE
  WHEN constraints.contype = 'c'
    THEN pg_catalog.pg_get_constraintdef(constraints.oid, true)
  ELSE NULL
END AS expression''',
      ])
      .where(schemaPredicate)
      .where(.raw("constraints.contype IN ('p', 'u', 'f', 'c')"))
      .orderBy('namespaces.nspname')
      .orderBy('table_classes.relname')
      .orderBy('constraints.conname');
}

SelectedSelectQueryBuilder<SqlRow> _routinesQuery(
  SqlRawQueryRoot raw,
  SqlPredicate schemaPredicate,
) {
  return raw
      .from('pg_catalog.pg_proc', alias: 'procedures')
      .innerJoin(
        'pg_catalog.pg_namespace',
        alias: 'namespaces',
        on: raw.eqRef('namespaces.oid', 'procedures.pronamespace'),
      )
      .innerJoin(
        'pg_catalog.pg_type',
        alias: 'return_types',
        on: raw.eqRef('return_types.oid', 'procedures.prorettype'),
      )
      .leftJoin(
        '''
LATERAL (
  SELECT jsonb_agg(
    jsonb_build_object(
      'name',
      COALESCE(
        procedures.proargnames[arguments.position + 1],
        'arg' || (arguments.position + 1)::text
      ),
      'databaseType',
      argument_types.typname
    )
    ORDER BY arguments.position
  ) AS parameters
  FROM generate_series(0, procedures.pronargs - 1) AS arguments(position)
  JOIN pg_catalog.pg_type AS argument_types
    ON argument_types.oid = procedures.proargtypes[arguments.position]
)''',
        alias: 'parameters',
        on: 'TRUE',
      )
      .select(const [
        'namespaces.nspname AS routine_schema',
        'procedures.proname AS routine_name',
        '''
CASE procedures.prokind
  WHEN 'p' THEN 'procedure'
  ELSE 'function'
END AS routine_kind''',
        'return_types.typname AS return_database_type',
        'procedures.proretset AS returns_set',
        "COALESCE(parameters.parameters, '[]'::jsonb) AS parameters",
      ])
      .where(schemaPredicate)
      .where(.raw("procedures.prokind IN ('f', 'p')"))
      .where(raw.notEq('return_types.typname', 'trigger'))
      .orderBy('procedures.proname');
}

String _mapPostgresType(String databaseType) {
  final normalized = databaseType.toLowerCase();
  return switch (normalized) {
    'int2' || 'int4' || 'int8' || 'serial' || 'bigserial' => 'int',
    'float4' || 'float8' => 'double',
    'numeric' || 'decimal' || 'money' => 'num',
    'bool' => 'bool',
    'date' || 'timestamp' || 'timestamptz' => 'DateTime',
    'time' || 'timetz' => 'String',
    'text' || 'varchar' || 'bpchar' || 'citext' || 'uuid' => 'String',
    'json' || 'jsonb' => 'Object?',
    'bytea' => 'List<int>',
    _ when normalized.startsWith('_') => 'List<Object?>',
    _ => 'Object?',
  };
}
