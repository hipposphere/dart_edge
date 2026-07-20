import 'dart:io';

import 'package:dart_edge_docs/src/codegen/docs_content_manifest_generator.dart';

Future<void> main(List<String> args) async {
  final options = _ManifestGeneratorOptions.parse(args);
  final input = Directory(options.inputDirectory);
  if (!await input.exists()) {
    stderr.writeln('Input directory does not exist: ${options.inputDirectory}');
    exitCode = 64;
    return;
  }

  await const DartEdgeDocsContentManifestGenerator().writeManifest(
    inputDirectory: input,
    outputFile: File(options.outputFile),
    constantName: options.constantName,
  );
}

final class _ManifestGeneratorOptions {
  const _ManifestGeneratorOptions({
    required this.inputDirectory,
    required this.outputFile,
    required this.constantName,
  });

  final String inputDirectory;
  final String outputFile;
  final String constantName;

  static _ManifestGeneratorOptions parse(List<String> args) {
    String? input;
    String? output;
    var constantName = 'dartEdgeDocsContentManifest';

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--input':
          input = _readValue(args, index += 1, arg);
        case '--output':
          output = _readValue(args, index += 1, arg);
        case '--name':
          constantName = _readValue(args, index += 1, arg);
        case '--help' || '-h':
          _printUsage();
          exit(0);
        default:
          stderr.writeln('Unknown option: $arg');
          _printUsage();
          exit(64);
      }
    }

    if (input == null || output == null) {
      _printUsage();
      exit(64);
    }

    return _ManifestGeneratorOptions(
      inputDirectory: input,
      outputFile: output,
      constantName: constantName,
    );
  }

  static String _readValue(List<String> args, int index, String option) {
    if (index >= args.length) {
      stderr.writeln('Missing value for $option');
      exit(64);
    }
    return args[index];
  }

  static void _printUsage() {
    stderr.writeln(
      'Usage: dart run dart_edge_docs:generate_docs_manifest '
      '--input content/docs --output lib/src/generated/docs_content_manifest.dart '
      '[--name docsContentManifest]',
    );
  }
}
