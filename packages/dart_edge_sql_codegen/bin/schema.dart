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

final class _Options {
  const _Options({required this.values, required this.help, this.error});

  final Map<String, String> values;
  final bool help;
  final String? error;

  String? value(String name) => values[name];

  static _Options parse(List<String> args) {
    final values = <String, String>{};
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
          help: help,
          error: 'Unexpected positional argument: $arg',
        );
      }

      final equalsIndex = arg.indexOf('=');
      final (name, value) = equalsIndex == -1
          ? (arg.substring(2), _takeValue(args, index))
          : (arg.substring(2, equalsIndex), arg.substring(equalsIndex + 1));
      if (equalsIndex == -1) {
        index += 1;
      }
      if (value == null || value.isEmpty) {
        return _Options(
          values: values,
          help: help,
          error: 'Missing value for --$name.',
        );
      }
      values[name] = value;
    }

    if (help) {
      return _Options(values: values, help: true);
    }

    final hasSqlite = values.containsKey('sqlite');
    final hasPostgres = values.containsKey('postgres');
    if (hasSqlite == hasPostgres) {
      return _Options(
        values: values,
        help: false,
        error: 'Pass exactly one of --sqlite or --postgres.',
      );
    }

    return _Options(values: values, help: false);
  }
}

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
  --schemas <csv>   Comma-separated PostgreSQL schemas.
  --include <csv>   Comma-separated table allow-list.
  --exclude <csv>   Comma-separated table block-list.

Examples:
  dart run dart_edge_sql_codegen:schema --sqlite sqlite.db --out lib/generated --class AppSchema
  dart run dart_edge_sql_codegen:schema --postgres postgres://localhost/app --schemas public,tenant
''';
