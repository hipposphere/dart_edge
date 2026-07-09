part of '../dart_schema_emitter.dart';

String _emitEntrypoint({
  required String databaseClassName,
  required List<_SchemaGroup> schemaGroups,
  required bool hasExternalPrimaryKeys,
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import('package:dart_edge_core/dart_edge_core.dart'),
      )
      ..body.add(_databaseClass(databaseClassName, schemaGroups));

    for (final group in schemaGroups) {
      builder.directives.add(
        Directive.import('schemas/${group.folderName}/schema.g.dart'),
      );
    }
    builder.directives.add(Directive.export('key_manifest.g.dart'));
    if (hasExternalPrimaryKeys) {
      builder.directives.add(Directive.export('external_keys.g.dart'));
    }
    for (final group in schemaGroups) {
      builder.directives.add(
        Directive.export('schemas/${group.folderName}/schema.g.dart'),
      );
    }
  });
  return _format(library, formatterOptions: formatterOptions);
}

String _emitSqlKeyManifestLibrary(
  IntrospectedDatabase database,
  Map<_ColumnKey, ExternalPrimaryKeySpec> externalPrimaryKeyTypeSpecs, {
  required DartSchemaNaming naming,
  required String? generatedLibraryImport,
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final entries = _sqlKeyManifestEntries(
    database,
    externalPrimaryKeyTypeSpecs,
    naming,
  );
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        Directive.import('package:dart_edge_core/dart_edge_core.dart'),
      )
      ..body.add(
        Field((field) {
          field
            ..modifier = FieldModifier.constant
            ..name = 'sqlKeyManifest'
            ..type = _listOf(refer('SqlKeyManifestEntry'))
            ..assignment = literalList([
              for (final entry in entries)
                refer(entry.dartType).property('manifest'),
            ], refer('SqlKeyManifestEntry')).code;
        }),
      );
    if (generatedLibraryImport case final import?) {
      builder.directives.add(Directive.import(import));
    } else {
      if (externalPrimaryKeyTypeSpecs.isNotEmpty) {
        builder.directives.add(Directive.import('external_keys.g.dart'));
      }
      for (final group in _groupBySchema(database)) {
        builder.directives.add(
          Directive.import('schemas/${group.folderName}/schema.g.dart'),
        );
      }
    }
  });
  return _format(library, formatterOptions: formatterOptions);
}

String _emitExternalPrimaryKeysLibrary(
  List<
    ({String schema, String table, String column, ExternalPrimaryKeySpec spec})
  >
  externalPrimaryKeyTypes, {
  required IntrospectedDatabase database,
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final library = Library((builder) {
    builder.directives.add(
      Directive.import('package:dart_edge_core/dart_edge_core.dart'),
    );
    builder.body.addAll(
      _externalPrimaryKeyExtensionTypeSpecs(database, externalPrimaryKeyTypes),
    );
  });
  return _format(library, formatterOptions: formatterOptions);
}

String _sqlKeyManifestEntryCode(_SqlKeyManifestEntry entry) {
  final fields = <String>[
    "dartType: '${_escapeLiteral(entry.dartType)}'",
    "baseDartType: '${_escapeLiteral(entry.baseDartType)}'",
    "schema: '${_escapeLiteral(entry.schema)}'",
    "table: '${_escapeLiteral(entry.table)}'",
    "column: '${_escapeLiteral(entry.column)}'",
  ];
  if (entry.nullable) {
    fields.add('nullable: true');
  }
  if (entry.external) {
    fields.add('external: true');
  }
  return 'SqlKeyManifestEntry(${fields.join(', ')})';
}

List<_SqlKeyManifestEntry> _sqlKeyManifestEntries(
  IntrospectedDatabase database,
  Map<_ColumnKey, ExternalPrimaryKeySpec> externalPrimaryKeyTypeSpecs,
  DartSchemaNaming naming,
) {
  final entries = <_SqlKeyManifestEntry>[
    for (final externalEntry in externalPrimaryKeyTypeSpecs.entries)
      _SqlKeyManifestEntry(
        dartType: externalEntry.value.typeName,
        baseDartType: externalEntry.value.baseDartType,
        schema: externalEntry.key.schema,
        table: externalEntry.key.table,
        column: externalEntry.key.column,
        external: true,
      ),
  ];

  for (final table in database.tables) {
    for (final column in table.columns) {
      if (!_declaresExtensionValueType(table, naming, column)) {
        continue;
      }
      entries.add(
        _SqlKeyManifestEntry(
          dartType: _valueType(column),
          baseDartType: _databaseValueType(column),
          schema: _schemaName(table.schema),
          table: table.name,
          column: column.name,
          nullable: column.nullable,
        ),
      );
    }
  }

  entries.sort((left, right) {
    final schemaOrder = left.schema.compareTo(right.schema);
    if (schemaOrder != 0) {
      return schemaOrder;
    }
    final tableOrder = left.table.compareTo(right.table);
    if (tableOrder != 0) {
      return tableOrder;
    }
    final columnOrder = left.column.compareTo(right.column);
    if (columnOrder != 0) {
      return columnOrder;
    }
    return left.dartType.compareTo(right.dartType);
  });
  return entries;
}

final class _SqlKeyManifestEntry {
  const _SqlKeyManifestEntry({
    required this.dartType,
    required this.baseDartType,
    required this.schema,
    required this.table,
    required this.column,
    this.nullable = false,
    this.external = false,
  });

  final String dartType;
  final String baseDartType;
  final String schema;
  final String table;
  final String column;
  final bool nullable;
  final bool external;
}

String _emitSchemaLibrary(
  _SchemaGroup group,
  DartSchemaNaming naming, {
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final library = Library((builder) {
    builder.directives.add(
      Directive.import('package:dart_edge_core/dart_edge_core.dart'),
    );
    builder.body.addAll([
      _schemaClass(group, naming),
      _schemaTablesExtension(group, naming),
    ]);

    for (final table in group.tables) {
      builder.directives.add(
        Directive.import('tables/${_tableFileName(table)}'),
      );
    }
    if (group.routines.isNotEmpty) {
      builder.directives.add(
        Directive.import('routines/${_routineFileName()}'),
      );
    }
    for (final value in group.enums) {
      builder.directives.add(Directive.import('enums/${_enumFileName(value)}'));
    }
    for (final table in group.tables) {
      builder.directives.add(
        Directive.export('tables/${_tableFileName(table)}'),
      );
    }
    for (final value in group.enums) {
      builder.directives.add(Directive.export('enums/${_enumFileName(value)}'));
    }
    if (group.routines.isNotEmpty) {
      builder.directives.add(
        Directive.export('routines/${_routineFileName()}'),
      );
    }
  });
  return _format(library, formatterOptions: formatterOptions);
}

String _emitTableLibrary(
  IntrospectedTable table,
  _SchemaGroup group,
  List<_SchemaGroup> schemaGroups,
  DartSchemaNaming naming, {
  required Set<String> externalPrimaryKeyTypeNames,
  required SqlInt8JsonEncoding int8JsonEncoding,
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final library = Library((builder) {
    builder.directives.add(
      Directive.import('package:dart_edge_core/dart_edge_core.dart'),
    );
    if (_usesExternalPrimaryKeyType(table, externalPrimaryKeyTypeNames)) {
      builder.directives.add(Directive.import('../../../external_keys.g.dart'));
    }
    for (final import in _tableEnumImports(table, group, schemaGroups)) {
      builder.directives.add(Directive.import(import.path));
    }
    for (final import in _tablePrimaryKeyTypeImports(
      table,
      group,
      schemaGroups,
      naming,
    )) {
      builder.directives.add(Directive.import(import.path));
    }
    builder.body.addAll(
      _tableSpecs(table, naming, int8JsonEncoding: int8JsonEncoding),
    );
  });
  return _format(library, formatterOptions: formatterOptions);
}

String _emitEnumLibrary(
  IntrospectedEnum value, {
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final library = Library((builder) {
    builder.body.add(_enumSpec(value));
  });
  return _format(library, formatterOptions: formatterOptions);
}

String _emitRoutineLibrary(
  _SchemaGroup group, {
  required DartSchemaFormatterOptions formatterOptions,
}) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import('package:dart_edge_core/dart_edge_core.dart'),
      )
      ..body.add(_routinesClass(group));
  });
  return _format(library, formatterOptions: formatterOptions);
}

Class _databaseClass(
  String databaseClassName,
  List<_SchemaGroup> schemaGroups,
) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = databaseClassName
      ..constructors.add(_privateConstConstructor())
      ..fields.addAll([
        for (final group in schemaGroups)
          _staticConstField(
            name: group.memberName,
            assignment: refer(group.className).property('instance'),
          ),
        _staticConstField(
          name: 'schemas',
          type: _listOf(refer('JsonSchema')),
          assignment: literalList([
            for (final group in schemaGroups)
              refer(group.className).property('schemas').spread,
          ], refer('JsonSchema')),
        ),
        _staticConstField(
          name: 'jsonSchemas',
          type: refer('JsonSchemaRegistry'),
          assignment: refer(
            'JsonSchemaRegistry',
          ).constInstance(const <Expression>[], {'schemas': refer('schemas')}),
        ),
      ]);
  });
}

Class _schemaClass(_SchemaGroup group, DartSchemaNaming naming) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = group.className
      ..constructors.addAll([
        Constructor((constructor) {
          constructor
            ..constant = true
            ..optionalParameters.add(_fieldParameter('databaseSchema'));
        }),
        Constructor((constructor) {
          constructor
            ..constant = true
            ..name = '_'
            ..initializers.add(
              refer('databaseSchema').assign(literalNull).code,
            );
        }),
      ])
      ..fields.addAll([
        _instanceFinalField('databaseSchema', refer('String?')),
        _staticConstField(
          name: 'instance',
          assignment: refer(group.className).constInstanceNamed('_', const []),
        ),
        _staticConstField(
          name: 'schemaName',
          assignment: literalString(group.schemaName),
        ),
        for (final table in group.tables)
          _staticConstField(
            name: _schemaTableMemberName(table.name),
            assignment: refer(_tableClassName(table, naming)).property('table'),
          ),
        if (group.routines.isNotEmpty)
          _staticConstField(
            name: 'routines',
            assignment: refer(group.routinesClassName).property('routines'),
          ),
        _staticConstField(
          name: 'schemas',
          type: _listOf(refer('JsonSchema')),
          assignment: literalList([
            for (final table in group.tables) ...[
              refer(_rowClassName(table, naming)).property('jsonSchema'),
              refer(_insertClassName(table, naming)).property('jsonSchema'),
              refer(_updateClassName(table, naming)).property('jsonSchema'),
            ],
          ], refer('JsonSchema')),
        ),
        _staticConstField(
          name: 'jsonSchemas',
          type: refer('JsonSchemaRegistry'),
          assignment: refer(
            'JsonSchemaRegistry',
          ).constInstance(const <Expression>[], {'schemas': refer('schemas')}),
        ),
      ]);
  });
}

Extension _schemaTablesExtension(_SchemaGroup group, DartSchemaNaming naming) {
  return Extension((builder) {
    builder
      ..name = '${group.className}Tables'
      ..on = refer(group.className)
      ..methods.addAll([
        for (final table in group.tables)
          Method((method) {
            method
              ..type = MethodType.getter
              ..returns = refer(_tableClassName(table, naming))
              ..name = _schemaTableMemberName(table.name)
              ..lambda = true
              ..body = refer(_tableClassName(table, naming)).newInstanceNamed(
                'withSchema',
                [
                  refer('databaseSchema').ifNullThen(
                    refer(
                      _tableClassName(table, naming),
                    ).property('table').property('schema'),
                  ),
                ],
              ).code;
          }),
      ]);
  });
}

Extension _existingSchemaTablesExtension(
  String schemaClassName,
  Iterable<IntrospectedTable> tables,
  DartSchemaNaming naming, {
  required String schemaFieldName,
}) {
  return Extension((builder) {
    builder
      ..name = '${schemaClassName}Tables'
      ..on = refer(schemaClassName)
      ..methods.addAll([
        for (final table in tables)
          Method((method) {
            final tableClassName = _tableClassName(table, naming);
            method
              ..type = MethodType.getter
              ..returns = refer(tableClassName)
              ..name = _lowerCamel(table.name)
              ..lambda = true
              ..body = refer(tableClassName).newInstanceNamed('withSchema', [
                refer(schemaFieldName).ifNullThen(
                  refer(tableClassName).property('table').property('schema'),
                ),
              ]).code;
          }),
      ]);
  });
}
