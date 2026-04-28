import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

/// Generates a Dart model type from a const JSON Schema.
///
/// Use this on a type alias whose target is the generated private backing
/// class, for example:
///
/// ```dart
/// @FromSchema(
///   createUserInputSchema,
///   registry: userSchemas,
///   refs: [SchemaRefModel(UserDto)],
/// )
/// typedef CreateUserInput = _$CreateUserInput;
/// ```
final class FromSchema {
  const FromSchema(this.schema, {this.registry, this.refs = const []});

  /// The schema used to infer the generated Dart model.
  final JsonSchema schema;

  /// Optional registry used for resolving schema references.
  final JsonSchemaRegistry? registry;

  /// Existing Dart model types used when this schema contains `$ref` values.
  final List<SchemaRefModel> refs;
}

/// Binds a JSON Schema `$ref` to an existing Dart model type.
///
/// By default the schema id is inferred from [type], so
/// `SchemaRefModel(UserDto)` binds `JsonSchema.ref('UserDto')` to `UserDto`.
/// Use [schemaId] when the Dart class name and schema id differ.
final class SchemaRefModel {
  const SchemaRefModel(this.type, {this.schemaId});

  /// Existing Dart model type used for this schema reference.
  final Type type;

  /// Optional schema id override.
  final String? schemaId;
}
