import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'from_schema_model_builder.dart';

const _fromSchemaChecker = TypeChecker.typeNamedLiterally('FromSchema');

/// Turns portable `@FromSchema` type aliases into plain Dart JSON models.
final class JsonSchemaBuilderGenerator extends Generator {
  const JsonSchemaBuilderGenerator({
    this._formatterOptions = const FromSchemaFormatterOptions(),
  });

  factory JsonSchemaBuilderGenerator.fromOptions(BuilderOptions options) {
    final config = options.config;
    return JsonSchemaBuilderGenerator(
      formatterOptions: FromSchemaFormatterOptions(
        pageWidth: _optionalPositiveInt(config, 'page_width'),
        trailingCommas: _optionalTrailingCommas(config, 'trailing_commas'),
      ),
    );
  }

  final FromSchemaFormatterOptions _formatterOptions;

  String formatOutput(String code) =>
      _formatterOptions.createFormatter().format(code);

  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final models = library.annotatedWith(
      _fromSchemaChecker,
      throwOnUnresolved: false,
    );
    if (models.isEmpty) {
      return null;
    }
    return generateFromSchemaModels([
      for (final model in models)
        buildFromSchemaModel(model.element, model.annotation),
    ], formatterOptions: _formatterOptions);
  }
}

int? _optionalPositiveInt(Map<String, dynamic> config, String key) {
  final value = config[key];
  if (value == null) return null;
  if (value is int && value > 0) return value;
  throw ArgumentError.value(value, key, 'must be a positive integer');
}

TrailingCommas? _optionalTrailingCommas(
  Map<String, dynamic> config,
  String key,
) {
  return switch (config[key]) {
    null => null,
    'automate' => TrailingCommas.automate,
    'preserve' => TrailingCommas.preserve,
    final value => throw ArgumentError.value(
      value,
      key,
      'must be "automate" or "preserve"',
    ),
  };
}
