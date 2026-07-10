part of '../dart_schema_emitter.dart';

/// One generated Dart file in a structured schema emission.
final class DartSchemaEmissionFile {
  const DartSchemaEmissionFile({
    required this.relativePath,
    required this.contents,
  });

  final String relativePath;
  final String contents;
}

/// Structured output tree generated from an introspected database schema.
final class DartSchemaEmission {
  DartSchemaEmission({
    required this.entrypointFileName,
    required Iterable<DartSchemaEmissionFile> files,
    required Iterable<String> directories,
  }) : files = List<DartSchemaEmissionFile>.unmodifiable(files),
       directories = List<String>.unmodifiable(
         directories.toSet().toList(growable: false)..sort(),
       );

  final String entrypointFileName;
  final List<DartSchemaEmissionFile> files;
  final List<String> directories;

  DartSchemaEmissionFile fileAt(String relativePath) {
    for (final file in files) {
      if (file.relativePath == relativePath) {
        return file;
      }
    }
    throw StateError('Generated file "$relativePath" was not found.');
  }

  void writeToDirectory(String outputDirectory) {
    final root = Directory(outputDirectory);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);

    for (final directory in directories) {
      Directory('${root.path}/$directory').createSync(recursive: true);
    }

    for (final file in files) {
      final outputFile = File('${root.path}/${file.relativePath}');
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(file.contents);
    }
  }
}

final class DartSchemaFormatterOptions {
  const DartSchemaFormatterOptions({this.pageWidth, this.trailingCommas});

  final int? pageWidth;
  final TrailingCommas? trailingCommas;

  DartFormatter createFormatter() {
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
      pageWidth: pageWidth,
      trailingCommas: trailingCommas,
    );
  }
}

/// Emits a structured Dart source tree for the introspected [database].
///
/// The generated output includes:
/// - one root entrypoint file
/// - one schema file per SQL schema / namespace
/// - one table file per table
/// - typed JSON Schema metadata for every row, insert, and update model
DartSchemaEmission emitDartSchema(
  IntrospectedDatabase database, {
  String databaseClassName = 'GeneratedDatabaseSchema',
  DartSchemaNaming? naming,
  bool primaryKeyExtensionTypes = true,
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
  Map<String, ExternalPrimaryKeySpec> externalPrimaryKeys =
      const <String, ExternalPrimaryKeySpec>{},
  DartSchemaFormatterOptions formatterOptions =
      const DartSchemaFormatterOptions(),
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  final prepared = _prepareDartSchemaEmission(
    database,
    naming: effectiveNaming,
    primaryKeyExtensionTypes: primaryKeyExtensionTypes,
    int8JsonEncoding: int8JsonEncoding,
    externalPrimaryKeys: externalPrimaryKeys,
  );
  database = prepared.database;
  final schemaGroups = _groupBySchema(database);
  final externalPrimaryKeyTypes = _externalPrimaryKeyTypes(
    prepared.externalPrimaryKeys,
  );
  final entrypointFileName = '${_fileStem(databaseClassName)}.g.dart';
  final files = <DartSchemaEmissionFile>[
    DartSchemaEmissionFile(
      relativePath: entrypointFileName,
      contents: _emitEntrypoint(
        databaseClassName: databaseClassName,
        schemaGroups: schemaGroups,
        keyManifestEntries: _sqlKeyManifestEntries(
          database,
          prepared.externalPrimaryKeys,
          effectiveNaming,
        ),
        hasExternalPrimaryKeys: externalPrimaryKeyTypes.isNotEmpty,
        formatterOptions: formatterOptions,
      ),
    ),
  ];
  final directories = <String>{};

  if (externalPrimaryKeyTypes.isNotEmpty) {
    files.add(
      DartSchemaEmissionFile(
        relativePath: 'external_keys.g.dart',
        contents: _emitExternalPrimaryKeysLibrary(
          externalPrimaryKeyTypes,
          database: database,
          formatterOptions: formatterOptions,
        ),
      ),
    );
  }

  for (final group in schemaGroups) {
    final schemaFolder = 'schemas/${group.folderName}';
    directories
      ..add(schemaFolder)
      ..add('$schemaFolder/tables')
      ..add('$schemaFolder/enums');
    if (group.routines.isNotEmpty) {
      directories.add('$schemaFolder/routines');
    }

    files.add(
      DartSchemaEmissionFile(
        relativePath: '$schemaFolder/schema.g.dart',
        contents: _emitSchemaLibrary(
          group,
          effectiveNaming,
          formatterOptions: formatterOptions,
        ),
      ),
    );

    for (final table in group.tables) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/tables/${_tableFileName(table)}',
          contents: _emitTableLibrary(
            table,
            group,
            schemaGroups,
            effectiveNaming,
            externalPrimaryKeyTypeNames: {
              for (final type in externalPrimaryKeyTypes) type.spec.typeName,
            },
            int8JsonEncoding: prepared.int8JsonEncoding,
            formatterOptions: formatterOptions,
          ),
        ),
      );
    }

    for (final value in group.enums) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/enums/${_enumFileName(value)}',
          contents: _emitEnumLibrary(value, formatterOptions: formatterOptions),
        ),
      );
    }

    if (group.routines.isNotEmpty) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/routines/${_routineFileName()}',
          contents: _emitRoutineLibrary(
            group,
            formatterOptions: formatterOptions,
          ),
        ),
      );
    }
  }

  return DartSchemaEmission(
    entrypointFileName: entrypointFileName,
    files: files,
    directories: directories,
  );
}

/// Emits a single generated Dart library suitable for build_runner outputs.
String emitDartSchemaLibrary(
  IntrospectedDatabase database, {
  String databaseClassName = 'GeneratedDatabaseSchema',
  DartSchemaNaming? naming,
  bool primaryKeyExtensionTypes = true,
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
  Map<String, ExternalPrimaryKeySpec> externalPrimaryKeys =
      const <String, ExternalPrimaryKeySpec>{},
  DartSchemaFormatterOptions formatterOptions =
      const DartSchemaFormatterOptions(),
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  final prepared = _prepareDartSchemaEmission(
    database,
    naming: effectiveNaming,
    primaryKeyExtensionTypes: primaryKeyExtensionTypes,
    int8JsonEncoding: int8JsonEncoding,
    externalPrimaryKeys: externalPrimaryKeys,
  );
  database = prepared.database;
  final externalPrimaryKeyTypes = _externalPrimaryKeyTypes(
    prepared.externalPrimaryKeys,
  );
  final schemaGroups = _groupBySchema(database);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        Directive.import('package:dart_edge_core/dart_edge_core.dart'),
      )
      ..body.add(
        _databaseClass(
          databaseClassName,
          schemaGroups,
          _sqlKeyManifestEntries(
            database,
            prepared.externalPrimaryKeys,
            effectiveNaming,
          ),
        ),
      )
      ..body.addAll(
        schemaGroups.expand(
          (group) => [
            _schemaClass(group, effectiveNaming),
            _schemaTablesExtension(group, effectiveNaming),
          ],
        ),
      );

    builder.body.addAll(
      _externalPrimaryKeyExtensionTypeSpecs(database, externalPrimaryKeyTypes),
    );

    if (schemaGroups.any((group) => group.routines.isNotEmpty)) {
      builder.directives.add(
        Directive.import('package:dart_edge_core/dart_edge_core.dart'),
      );
    }

    for (final group in schemaGroups) {
      for (final value in group.enums) {
        builder.body.add(_enumSpec(value));
      }
      for (final table in group.tables) {
        builder.body.addAll(
          _tableSpecs(
            table,
            effectiveNaming,
            int8JsonEncoding: prepared.int8JsonEncoding,
          ),
        );
      }
      if (group.routines.isNotEmpty) {
        builder.body.add(_routinesClass(group));
      }
    }
  });
  return _format(library, formatterOptions: formatterOptions);
}

/// Emits a generated manifest describing SQL key extension types.
String emitDartSqlKeyManifestLibrary(
  IntrospectedDatabase database, {
  DartSchemaNaming? naming,
  bool primaryKeyExtensionTypes = true,
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
  Map<String, ExternalPrimaryKeySpec> externalPrimaryKeys =
      const <String, ExternalPrimaryKeySpec>{},
  String? generatedLibraryImport,
  DartSchemaFormatterOptions formatterOptions =
      const DartSchemaFormatterOptions(),
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  final prepared = _prepareDartSchemaEmission(
    database,
    naming: effectiveNaming,
    primaryKeyExtensionTypes: primaryKeyExtensionTypes,
    int8JsonEncoding: int8JsonEncoding,
    externalPrimaryKeys: externalPrimaryKeys,
  );
  return _emitSqlKeyManifestLibrary(
    prepared.database,
    prepared.externalPrimaryKeys,
    naming: effectiveNaming,
    generatedLibraryImport: generatedLibraryImport,
    formatterOptions: formatterOptions,
  );
}

/// Emits only SQL table descriptors for existing row/insert/update models.
///
/// This is intended for packages that already own their domain models but want
/// generated [SqlTable] descriptors from an introspected SQL schema.
String emitDartTableDescriptorLibrary(
  IntrospectedDatabase database, {
  String? partOf,
  DartSchemaNaming? naming,
  String? schemaClassName,
  String schemaFieldName = 'databaseSchema',
  DartSchemaFormatterOptions formatterOptions =
      const DartSchemaFormatterOptions(),
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  final schemaGroups = _groupBySchema(database);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        partOf == null
            ? Directive.import('package:dart_edge_core/dart_edge_core.dart')
            : Directive.partOf(partOf),
      );

    for (final group in schemaGroups) {
      for (final table in group.tables) {
        builder.body.add(
          _tableClass(table, effectiveNaming, encodeMapValues: true),
        );
      }
    }

    if (schemaClassName case final className?) {
      builder.body.add(
        _existingSchemaTablesExtension(
          className,
          schemaGroups.expand((group) => group.tables),
          effectiveNaming,
          schemaFieldName: schemaFieldName,
        ),
      );
    }
  });
  return _format(library, formatterOptions: formatterOptions);
}

/// Emits SQL row, insert, update, and table models without database wrappers.
///
/// This is intended for packages that want generated table models inside an
/// existing public library or `part` file structure.
String emitDartTableModelLibrary(
  IntrospectedDatabase database, {
  String? partOf,
  DartSchemaNaming? naming,
  String? schemaClassName,
  String schemaFieldName = 'databaseSchema',
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
  DartSchemaFormatterOptions formatterOptions =
      const DartSchemaFormatterOptions(),
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  final effectiveInt8JsonEncoding = _effectiveInt8JsonEncoding(
    database,
    int8JsonEncoding,
  );
  final schemaGroups = _groupBySchema(database);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        partOf == null
            ? Directive.import('package:dart_edge_core/dart_edge_core.dart')
            : Directive.partOf(partOf),
      );

    for (final group in schemaGroups) {
      for (final table in group.tables) {
        builder.body.addAll(
          _tableSpecs(
            table,
            effectiveNaming,
            int8JsonEncoding: effectiveInt8JsonEncoding,
          ),
        );
      }
    }

    if (schemaClassName case final className?) {
      builder.body.add(
        _existingSchemaTablesExtension(
          className,
          schemaGroups.expand((group) => group.tables),
          effectiveNaming,
          schemaFieldName: schemaFieldName,
        ),
      );
    }
  });
  return _format(library, formatterOptions: formatterOptions);
}

SqlInt8JsonEncoding _effectiveInt8JsonEncoding(
  IntrospectedDatabase database,
  SqlInt8JsonEncoding int8JsonEncoding,
) {
  return database.dialect == SqlCodegenDialect.postgres
      ? int8JsonEncoding
      : SqlInt8JsonEncoding.number;
}

_PreparedDartSchemaEmission _prepareDartSchemaEmission(
  IntrospectedDatabase database, {
  required DartSchemaNaming naming,
  required bool primaryKeyExtensionTypes,
  required SqlInt8JsonEncoding int8JsonEncoding,
  required Map<String, ExternalPrimaryKeySpec> externalPrimaryKeys,
}) {
  final effectiveInt8JsonEncoding = _effectiveInt8JsonEncoding(
    database,
    int8JsonEncoding,
  );
  final normalizedExternalPrimaryKeys = _externalPrimaryKeyNames(
    externalPrimaryKeys,
  );
  if (primaryKeyExtensionTypes) {
    database = _withGeneratedPrimaryKeyExtensionTypes(
      database,
      naming,
      externalPrimaryKeyTypeSpecs: normalizedExternalPrimaryKeys,
    );
  }
  database = _withGeneratedConstrainedTextTypes(database, naming);
  return _PreparedDartSchemaEmission(
    database: database,
    int8JsonEncoding: effectiveInt8JsonEncoding,
    externalPrimaryKeys: normalizedExternalPrimaryKeys,
  );
}

final class _PreparedDartSchemaEmission {
  const _PreparedDartSchemaEmission({
    required this.database,
    required this.int8JsonEncoding,
    required this.externalPrimaryKeys,
  });

  final IntrospectedDatabase database;
  final SqlInt8JsonEncoding int8JsonEncoding;
  final Map<_ColumnKey, ExternalPrimaryKeySpec> externalPrimaryKeys;
}
