import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/builder/json_schema_builder.dart';

/// Builder entrypoint used by `build_runner`.
Builder jsonSchemaBuilder(BuilderOptions options) {
  final generator = JsonSchemaBuilderGenerator.fromOptions(options);
  return SharedPartBuilder(
    [generator],
    'json_schema',
    formatOutput: (code, _) => generator.formatOutput(code),
  );
}
