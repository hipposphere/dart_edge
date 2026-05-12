import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../core/sql_migration_file_sorting.dart';

/// Configuration for [DartEdgeMigrationManifestGenerator].
final class DartEdgeMigrationManifestGeneratorConfig {
  const DartEdgeMigrationManifestGeneratorConfig({
    required this.package,
    this.migrationsDirectory = 'migrations',
    this.outputFile = 'lib/src/embedded_migration_manifest.dart',
    this.manifestFieldName = 'sqlMigrationManifest',
    this.generatedByComment = 'tool/generate_migration_manifest.dart',
    this.importUri =
        'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart',
    this.assetNamePrefix,
    this.sorting = const SqlMigrationFileSorting.lexicographic(),
    this.includeEmptyFiles = false,
  });

  /// Dart package that owns the generated manifest.
  final String package;

  /// Directory containing `.sql` migration files, relative to the package root.
  final String migrationsDirectory;

  /// Generated Dart file path, relative to the package root.
  final String outputFile;

  /// Top-level const field name to emit.
  final String manifestFieldName;

  /// Generator comment emitted into the generated library.
  final String generatedByComment;

  /// Import that exposes `SqlMigrationManifest` and
  /// `SqlMigrationManifestEntry`.
  final String importUri;

  /// Logical entry name prefix. Defaults to [migrationsDirectory].
  final String? assetNamePrefix;

  /// Sorting strategy for migration filenames.
  final SqlMigrationFileSorting sorting;

  /// Whether to include files whose SQL contents are empty after trimming.
  final bool includeEmptyFiles;
}

/// Generates a Dart library containing a const [SqlMigrationManifest].
final class DartEdgeMigrationManifestGenerator {
  const DartEdgeMigrationManifestGenerator();

  /// Writes a generated manifest library under [packageRoot].
  Future<File> writePackageManifest({
    required Directory packageRoot,
    required DartEdgeMigrationManifestGeneratorConfig config,
  }) async {
    final output = File('${packageRoot.path}/${config.outputFile}');
    await output.parent.create(recursive: true);
    await output.writeAsString(
      await generatePackageManifestSource(
        packageRoot: packageRoot,
        config: config,
      ),
    );
    return output;
  }

  /// Generates the Dart source for a manifest library under [packageRoot].
  Future<String> generatePackageManifestSource({
    required Directory packageRoot,
    required DartEdgeMigrationManifestGeneratorConfig config,
  }) async {
    final migrationsDirectory = Directory(
      '${packageRoot.path}/${config.migrationsDirectory}',
    );
    if (!await migrationsDirectory.exists()) {
      throw StateError(
        'Migration directory not found: ${migrationsDirectory.path}',
      );
    }

    final files = <_MigrationManifestFile>[];
    await for (final entity in migrationsDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.sql')) {
        continue;
      }

      final sql = await entity.readAsString();
      if (!config.includeEmptyFiles && sql.trim().isEmpty) {
        continue;
      }

      files.add(_MigrationManifestFile(file: entity, sql: sql));
    }

    files.sort((left, right) {
      return config.sorting.compare(left.stem, right.stem);
    });

    return _generateManifestSource(files: files, config: config);
  }

  String _generateManifestSource({
    required List<_MigrationManifestFile> files,
    required DartEdgeMigrationManifestGeneratorConfig config,
  }) {
    final library = Library(
      (builder) => builder
        ..generatedByComment = config.generatedByComment
        ..comments.add('Do not edit by hand.')
        ..directives.add(Directive.import(config.importUri))
        ..body.add(
          Field(
            (field) => field
              ..name = config.manifestFieldName
              ..modifier = FieldModifier.constant
              ..assignment = _manifestExpression(
                files: files,
                config: config,
              ).code,
          ),
        ),
    );

    return _dartFormatter.format('${library.accept(_dartEmitter)}');
  }

  Expression _manifestExpression({
    required List<_MigrationManifestFile> files,
    required DartEdgeMigrationManifestGeneratorConfig config,
  }) {
    final assetNamePrefix =
        config.assetNamePrefix ?? config.migrationsDirectory;
    final normalizedPrefix = assetNamePrefix.stripTrailingSlash;

    return refer('SqlMigrationManifest').constInstance([], {
      'package': literalString(config.package),
      'entries': literalConstList([
        for (final file in files)
          refer('SqlMigrationManifestEntry').constInstance([], {
            'name': literalString('$normalizedPrefix/${file.name}'),
            'sql': literalString(file.sql),
          }),
      ], refer('SqlMigrationManifestEntry')),
    });
  }
}

final class _MigrationManifestFile {
  const _MigrationManifestFile({required this.file, required this.sql});

  final File file;
  final String sql;

  String get name => file.uri.pathSegments.last;

  String get stem => name.substring(0, name.length - '.sql'.length);
}

extension on String {
  String get stripTrailingSlash {
    var result = this;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

final _dartEmitter = DartEmitter(useNullSafetySyntax: true);

final _dartFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);
