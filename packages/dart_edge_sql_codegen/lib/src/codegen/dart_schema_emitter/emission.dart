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
}) {
  final schemaGroups = _groupTablesBySchema(database.tables);
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

    files.add(
      DartSchemaEmissionFile(
        relativePath: '$schemaFolder/schema.g.dart',
        contents: _emitSchemaLibrary(group),
      ),
    );

    for (final table in group.tables) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/tables/${_tableFileName(table)}',
          contents: _emitTableLibrary(table),
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
}) {
  final schemaGroups = _groupTablesBySchema(database.tables);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..directives.add(
        Directive.import('package:dart_edge_sql/dart_edge_sql.dart'),
      )
      ..body.add(_databaseClass(databaseClassName, schemaGroups))
      ..body.addAll(schemaGroups.map(_schemaClass));

    for (final group in schemaGroups) {
      for (final table in group.tables) {
        builder.body.addAll(_tableSpecs(table));
      }
    }
  });
  return _format(library);
}
