import 'dart:convert';

import 'package:build/build.dart';

import '../codegen/dart_schema_emitter.dart';
import '../introspection/introspected_database.dart';

/// Build runner integration for schema snapshots.
///
/// Inputs are JSON files ending in `.schema.json`. The builder emits a single
/// Dart library beside the snapshot, ending in `.g.dart`.
final class DartEdgeSqlBuilder implements Builder {
  const DartEdgeSqlBuilder(this.options);

  final BuilderOptions options;

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.schema.json': ['.g.dart'],
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
    final naming = _namingFromOptions(options.config);
    final output = AssetId(
      input.package,
      input.path.replaceFirst(RegExp(r'\.schema\.json$'), '.g.dart'),
    );

    await buildStep.writeAsString(
      output,
      emitDartSchemaLibrary(
        database,
        databaseClassName: databaseClassName,
        naming: naming,
      ),
    );
  }
}

DartSchemaNaming _namingFromOptions(Map<String, dynamic> config) {
  if (config['prefix_models_with_schema'] == true) {
    return DartSchemaNaming.schemaPrefixed;
  }

  final style = config['model_name_style'] as String?;
  return switch (style) {
    null || 'default' => DartSchemaNaming.defaults,
    'schema_prefixed' => DartSchemaNaming.schemaPrefixed,
    'unprefixed' || 'legacy' => DartSchemaNaming.unprefixed,
    _ => throw FormatException(
      'Unsupported SQL codegen model_name_style "$style".',
    ),
  };
}
