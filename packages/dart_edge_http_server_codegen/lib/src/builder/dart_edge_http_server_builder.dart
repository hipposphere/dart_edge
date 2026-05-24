import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'from_schema_model_builder.dart';

const _fromSchemaChecker = TypeChecker.typeNamedLiterally('FromSchema');
const _fromMultipartSchemaChecker = TypeChecker.typeNamedLiterally(
  'FromMultipartSchema',
);

/// Turns `@FromSchema` type aliases into Dart model classes.
final class DartEdgeHttpServerBuilderGenerator extends Generator {
  const DartEdgeHttpServerBuilderGenerator();

  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final jsonModels = library.annotatedWith(
      _fromSchemaChecker,
      throwOnUnresolved: false,
    );
    final multipartModels = library.annotatedWith(
      _fromMultipartSchemaChecker,
      throwOnUnresolved: false,
    );
    if (jsonModels.isEmpty && multipartModels.isEmpty) {
      return null;
    }

    final models = [
      for (final annotatedModel in jsonModels)
        buildFromSchemaModel(annotatedModel.element, annotatedModel.annotation),
      for (final annotatedModel in multipartModels)
        buildFromSchemaModel(
          annotatedModel.element,
          annotatedModel.annotation,
          source: FromSchemaModelSource.multipart,
        ),
    ];

    return generateFromSchemaModels(models);
  }
}
