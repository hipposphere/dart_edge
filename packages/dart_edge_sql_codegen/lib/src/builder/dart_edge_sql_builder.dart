import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import '../codegen/dart_schema_emitter.dart';
import '../codegen/sql_codegen_config.dart';
import '../introspection/introspected_database.dart';

/// Build runner integration for schema snapshots.
///
/// Inputs are JSON files ending in `.schema.json`. The builder emits Dart
/// libraries beside the snapshot, ending in `.g.dart` and
/// `.key_manifest.g.dart`.
final class DartEdgeSqlBuilder implements Builder {
  const DartEdgeSqlBuilder(this.options);

  final BuilderOptions options;

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.schema.json': ['.g.dart', '.key_manifest.g.dart'],
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
    final keyManifestOutput = AssetId(
      input.package,
      input.path.replaceFirst(
        RegExp(r'\.schema\.json$'),
        '.key_manifest.g.dart',
      ),
    );
    final primaryKeyExtensionTypes = _primaryKeyExtensionTypes(options.config);
    final int8JsonEncoding = _int8JsonEncoding(options.config);
    final externalPrimaryKeys = _externalPrimaryKeys(options.config);
    final formatterOptions = _formatterOptions(options.config);

    await buildStep.writeAsString(
      output,
      emitDartSchemaLibrary(
        database,
        databaseClassName: databaseClassName,
        naming: naming,
        primaryKeyExtensionTypes: primaryKeyExtensionTypes,
        int8JsonEncoding: int8JsonEncoding,
        externalPrimaryKeys: externalPrimaryKeys,
        formatterOptions: formatterOptions,
      ),
    );
    await buildStep.writeAsString(
      keyManifestOutput,
      emitDartSqlKeyManifestLibrary(
        database,
        naming: naming,
        primaryKeyExtensionTypes: primaryKeyExtensionTypes,
        int8JsonEncoding: int8JsonEncoding,
        externalPrimaryKeys: externalPrimaryKeys,
        generatedLibraryImport: _fileName(output.path),
        formatterOptions: formatterOptions,
      ),
    );
  }
}

String _fileName(String path) {
  final slash = path.lastIndexOf('/');
  return slash == -1 ? path : path.substring(slash + 1);
}

DartSchemaFormatterOptions _formatterOptions(Map<String, dynamic> config) {
  return DartSchemaFormatterOptions(
    pageWidth: _optionalPositiveInt(config, 'page_width'),
    trailingCommas: _optionalTrailingCommas(config, 'trailing_commas'),
  );
}

int? _optionalPositiveInt(Map<String, dynamic> config, String key) {
  final value = config[key];
  if (value == null) {
    return null;
  }
  if (value is int && value > 0) {
    return value;
  }
  throw ArgumentError.value(value, key, 'must be a positive integer');
}

TrailingCommas? _optionalTrailingCommas(
  Map<String, dynamic> config,
  String key,
) {
  final value = config[key];
  return switch (value) {
    null => null,
    'automate' => TrailingCommas.automate,
    'preserve' => TrailingCommas.preserve,
    _ => throw ArgumentError.value(
      value,
      key,
      'must be "automate" or "preserve"',
    ),
  };
}

bool _primaryKeyExtensionTypes(Map<String, dynamic> config) {
  return config['primary_key_extension_types'] as bool? ?? true;
}

SqlInt8JsonEncoding _int8JsonEncoding(Map<String, dynamic> config) {
  final value = config['int8_json_encoding'] as String?;
  return switch (value) {
    null || 'number' => SqlInt8JsonEncoding.number,
    'string' => SqlInt8JsonEncoding.string,
    _ => throw FormatException(
      'Unsupported SQL codegen int8_json_encoding "$value".',
    ),
  };
}

Map<String, ExternalPrimaryKeySpec> _externalPrimaryKeys(
  Map<String, dynamic> config,
) {
  final value = config['external_primary_keys'];
  if (value == null) {
    return const <String, ExternalPrimaryKeySpec>{};
  }
  if (value is! Map) {
    throw const FormatException(
      'SQL codegen external_primary_keys must be a map.',
    );
  }
  final externalPrimaryKeys = <String, ExternalPrimaryKeySpec>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final spec = entry.value;
    if (key is! String || spec is! Map) {
      throw const FormatException(
        'SQL codegen external_primary_keys entries must map strings to '
        'objects with type and base_type.',
      );
    }
    externalPrimaryKeys[key] = _externalPrimaryKeySpec(key, spec);
  }
  return externalPrimaryKeys;
}

ExternalPrimaryKeySpec _externalPrimaryKeySpec(
  String key,
  Map<dynamic, dynamic> value,
) {
  final typeName = value['type'] ?? value['type_name'];
  final baseDartType = value['base_type'] ?? value['base_dart_type'];
  if (typeName is! String || baseDartType is! String) {
    throw FormatException(
      'SQL codegen external_primary_keys.$key must define string '
      'type and base_type values.',
    );
  }
  return ExternalPrimaryKeySpec(typeName: typeName, baseDartType: baseDartType);
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
