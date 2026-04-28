import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'from_schema_model_builder.dart';

const _fromSchemaChecker = TypeChecker.typeNamedLiterally('FromSchema');

/// Turns `@FromSchema` type aliases into Dart model classes.
final class DartEdgeHttpServerBuilderGenerator extends Generator {
  const DartEdgeHttpServerBuilderGenerator();

  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final annotatedModels = library.annotatedWith(
      _fromSchemaChecker,
      throwOnUnresolved: false,
    );
    if (annotatedModels.isEmpty) {
      return null;
    }

    final models = [
      for (final annotatedModel in annotatedModels)
        buildFromSchemaModel(annotatedModel.element, annotatedModel.annotation),
    ];

    return generateFromSchemaModels(models);
  }
}
