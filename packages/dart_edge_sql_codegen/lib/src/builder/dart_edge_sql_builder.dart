import 'dart:convert';

import 'package:build/build.dart';

import '../codegen/dart_schema_emitter.dart';
import '../introspection/introspected_database.dart';

/// Build runner integration for schema snapshots.
///
/// Inputs are JSON files ending in `.dart_edge_sql.json`. The builder emits a
/// single Dart library beside the snapshot, ending in `.dart_edge_sql.g.dart`.
final class DartEdgeSqlBuilder implements Builder {
  const DartEdgeSqlBuilder(this.options);

  final BuilderOptions options;

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart_edge_sql.json': ['.dart_edge_sql.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final decoded = jsonDecode(await buildStep.readAsString(input));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Expected the SQL schema snapshot to be a JSON object.',
      );
    }

    final database = IntrospectedDatabase.fromJson(decoded);
    final databaseClassName =
        decoded['databaseClassName'] as String? ??
        options.config['database_class_name'] as String? ??
        'GeneratedDatabaseSchema';
    final output = AssetId(
      input.package,
      input.path.replaceFirst(
        RegExp(r'\.dart_edge_sql\.json$'),
        '.dart_edge_sql.g.dart',
      ),
    );

    await buildStep.writeAsString(
      output,
      emitDartSchemaLibrary(database, databaseClassName: databaseClassName),
    );
  }
}
