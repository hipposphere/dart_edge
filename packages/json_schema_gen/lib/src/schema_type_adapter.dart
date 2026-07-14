import 'package:json_schema/json_schema.dart';

/// A Dart type and conversion strategy selected for a JSON Schema value.
final class SchemaDartType {
  const SchemaDartType(
    this.name, {
    this.conversion = DartSchemaConversion.infer,
  });

  /// Source-level Dart type spelling emitted by a generator.
  final String name;

  /// Conversion convention used when encoding and decoding the value.
  final DartSchemaConversion conversion;
}

/// Extends a schema-model generator with project-specific Dart type mappings.
///
/// Adapters are build-time configuration. They intentionally do not appear in
/// `@FromSchema`, keeping application annotations const-friendly and portable.
abstract class SchemaTypeAdapter {
  const SchemaTypeAdapter();

  /// Returns a Dart type mapping for [schema], or `null` when not handled.
  SchemaDartType? map(JsonSchema schema);
}
