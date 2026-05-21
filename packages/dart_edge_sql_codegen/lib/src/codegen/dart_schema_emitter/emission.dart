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
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  if (primaryKeyExtensionTypes) {
    database = _withGeneratedPrimaryKeyExtensionTypes(
      database,
      effectiveNaming,
    );
  }
  database = _withGeneratedConstrainedTextTypes(database, effectiveNaming);
  final schemaGroups = _groupBySchema(database);
  final entrypointFileName = '${_fileStem(databaseClassName)}.g.dart';
  final files = <DartSchemaEmissionFile>[
    DartSchemaEmissionFile(
      relativePath: entrypointFileName,
      contents: _emitEntrypoint(
        databaseClassName: databaseClassName,
        schemaGroups: schemaGroups,
      ),
    ),
  ];
  final directories = <String>{};

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
        contents: _emitSchemaLibrary(group, effectiveNaming),
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
          ),
        ),
      );
    }

    for (final value in group.enums) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/enums/${_enumFileName(value)}',
          contents: _emitEnumLibrary(value),
        ),
      );
    }

    if (group.routines.isNotEmpty) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/routines/${_routineFileName()}',
          contents: _emitRoutineLibrary(group),
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
}) {
  final effectiveNaming = naming ?? DartSchemaNaming.defaults;
  if (primaryKeyExtensionTypes) {
    database = _withGeneratedPrimaryKeyExtensionTypes(
      database,
      effectiveNaming,
    );
  }
  database = _withGeneratedConstrainedTextTypes(database, effectiveNaming);
  final schemaGroups = _groupBySchema(database);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        Directive.import('package:dart_edge_core/dart_edge_core.dart'),
      )
      ..body.add(_databaseClass(databaseClassName, schemaGroups))
      ..body.addAll(
        schemaGroups.map((group) => _schemaClass(group, effectiveNaming)),
      );

    if (schemaGroups.any((group) => group.routines.isNotEmpty)) {
      builder.directives.add(
        Directive.import('package:dart_edge_sql/dart_edge_sql.dart'),
      );
    }

    for (final group in schemaGroups) {
      for (final value in group.enums) {
        builder.body.add(_enumSpec(value));
      }
      for (final table in group.tables) {
        builder.body.addAll(_tableSpecs(table, effectiveNaming));
      }
      if (group.routines.isNotEmpty) {
        builder.body.add(_routinesClass(group));
      }
    }
  });
  return _format(library);
}
