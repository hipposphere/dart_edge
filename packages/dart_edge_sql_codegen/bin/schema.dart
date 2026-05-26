import 'dart:io';

import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  if (options.error case final error?) {
    stderr.writeln(error);
    stderr.writeln();
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final includeTables = _csv(options.value('include'));
  final excludeTables = _csv(options.value('exclude'));
  final schemas = _csv(options.value('schemas'));
  final externalPrimaryKeys = _externalPrimaryKeys(
    options.value('external-primary-keys'),
  );
  final introspector = switch ((
    sqlite: options.value('sqlite'),
    postgres: options.value('postgres'),
  )) {
    (sqlite: final path?, postgres: null) => SqliteIntrospector(
      path: path,
      includeTables: includeTables,
      excludeTables: excludeTables,
    ),
    (sqlite: null, postgres: final connectionString?) => PostgresIntrospector(
      connectionString: connectionString,
      schemas: schemas,
      includeTables: includeTables,
      excludeTables: excludeTables,
    ),
    _ => throw StateError('Expected exactly one database source.'),
  };

  final database = await introspector.introspect();
  final emission = emitDartSchema(
    database,
    databaseClassName: options.value('class') ?? 'GeneratedDatabaseSchema',
    naming: _namingFromStyle(options.value('model-name-style')),
    primaryKeyExtensionTypes: !options.flag('no-primary-key-extension-types'),
    int8JsonEncoding: _int8JsonEncoding(options.value('int8-json-encoding')),
    externalPrimaryKeys: externalPrimaryKeys,
  );
  final outputDirectory = options.value('out') ?? 'lib/generated';
  emission.writeToDirectory(outputDirectory);
  stdout.writeln(
    'Generated ${emission.files.length} file(s) in $outputDirectory.',
  );
}

Set<String> _csv(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const <String>{};
  }
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
}

Map<String, ExternalPrimaryKeySpec> _externalPrimaryKeys(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const <String, ExternalPrimaryKeySpec>{};
  }
  final externalPrimaryKeys = <String, ExternalPrimaryKeySpec>{};
  for (final part in value.split(',')) {
    final entry = part.trim();
    if (entry.isEmpty) {
      continue;
    }
    final mapping = _externalPrimaryKeyName(entry);
    externalPrimaryKeys[mapping.$1] = mapping.$2;
  }
  return externalPrimaryKeys;
}

(String, ExternalPrimaryKeySpec) _externalPrimaryKeyName(String value) {
  final equals = value.indexOf('=');
  if (equals <= 0 || equals == value.length - 1) {
    throw FormatException(
      'Expected external primary key mapping "$value" to use '
      'key=TypeName:BaseType.',
    );
  }
  final key = value.substring(0, equals).trim();
  final typeSpec = value.substring(equals + 1).trim();
  final separator = typeSpec.indexOf(':');
  if (separator <= 0 || separator == typeSpec.length - 1) {
    throw FormatException(
      'Expected external primary key mapping "$value" to include a base type '
      'as key=TypeName:BaseType.',
    );
  }
  return (
    key,
    ExternalPrimaryKeySpec(
      typeName: typeSpec.substring(0, separator).trim(),
      baseDartType: typeSpec.substring(separator + 1).trim(),
    ),
  );
}

DartSchemaNaming _namingFromStyle(String? style) {
  return switch (style) {
    null || 'default' => DartSchemaNaming.defaults,
    'schema_prefixed' => DartSchemaNaming.schemaPrefixed,
    'unprefixed' || 'legacy' => DartSchemaNaming.unprefixed,
    _ => throw FormatException(
      'Unsupported --model-name-style "$style". Expected default, '
      'schema_prefixed, or unprefixed.',
    ),
  };
}

SqlInt8JsonEncoding _int8JsonEncoding(String? value) {
  return switch (value) {
    null || 'number' => SqlInt8JsonEncoding.number,
    'string' => SqlInt8JsonEncoding.string,
    _ => throw FormatException(
      'Unsupported --int8-json-encoding "$value". Expected number or string.',
    ),
  };
}

final class _Options {
  const _Options({
    required this.values,
    required this.flags,
    required this.help,
    this.error,
  });

  final Map<String, String> values;
  final Set<String> flags;
  final bool help;
  final String? error;

  String? value(String name) => values[name];
  bool flag(String name) => flags.contains(name);

  static _Options parse(List<String> args) {
    final values = <String, String>{};
    final flags = <String>{};
    var help = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      if (arg == '--help' || arg == '-h') {
        help = true;
        continue;
      }
      if (!arg.startsWith('--')) {
        return _Options(
          values: values,
          flags: flags,
          help: help,
          error: 'Unexpected positional argument: $arg',
        );
      }

      final equalsIndex = arg.indexOf('=');
      final flagName = arg.substring(2);
      if (equalsIndex == -1 && _flagOptions.contains(flagName)) {
        flags.add(flagName);
        continue;
      }
      final (name, value) = equalsIndex == -1
          ? (arg.substring(2), _takeValue(args, index))
          : (arg.substring(2, equalsIndex), arg.substring(equalsIndex + 1));
      if (equalsIndex == -1) {
        index += 1;
      }
      if (value == null || value.isEmpty) {
        return _Options(
          values: values,
          flags: flags,
          help: help,
          error: 'Missing value for --$name.',
        );
      }
      values[name] = value;
    }

    if (help) {
      return _Options(values: values, flags: flags, help: true);
    }

    final hasSqlite = values.containsKey('sqlite');
    final hasPostgres = values.containsKey('postgres');
    if (hasSqlite == hasPostgres) {
      return _Options(
        values: values,
        flags: flags,
        help: false,
        error: 'Pass exactly one of --sqlite or --postgres.',
      );
    }

    return _Options(values: values, flags: flags, help: false);
  }
}

const _flagOptions = {'no-primary-key-extension-types'};

String? _takeValue(List<String> args, int index) {
  final valueIndex = index + 1;
  if (valueIndex >= args.length) {
    return null;
  }
  final value = args[valueIndex];
  if (value.startsWith('--')) {
    return null;
  }
  return value;
}

const _usage = '''
Generates Dart Edge SQL descriptors from a live database.

Usage:
  dart run dart_edge_sql_codegen:schema --sqlite <path> [options]
  dart run dart_edge_sql_codegen:schema --postgres <url> [options]

Options:
  --out <dir>       Output directory. Defaults to lib/generated.
  --class <name>    Root schema class. Defaults to GeneratedDatabaseSchema.
  --model-name-style <style>
                   Model class naming: default/schema_prefixed or unprefixed.
  --int8-json-encoding <mode>
                   PostgreSQL int8 JSON mode: number or string.
  --schemas <csv>   Comma-separated PostgreSQL schemas.
  --include <csv>   Comma-separated table allow-list.
  --exclude <csv>   Comma-separated table block-list.
  --external-primary-keys <csv>
                   Comma-separated schema.table.column=TypeName:BaseType mappings.
  --no-primary-key-extension-types
                   Keep primary and foreign key fields on primitive Dart types.

Examples:
  dart run dart_edge_sql_codegen:schema --sqlite sqlite.db --out lib/generated --class AppSchema
  dart run dart_edge_sql_codegen:schema --postgres postgres://localhost/app --schemas public,tenant
''';
