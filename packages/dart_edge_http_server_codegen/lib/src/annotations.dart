import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

/// Generates a Dart model type from a const JSON Schema.
///
/// Use this on a type alias whose target is the generated private backing
/// class, for example:
///
/// ```dart
/// @FromSchema(createUserInputSchema, registry: userSchemas)
/// typedef CreateUserInput = _$CreateUserInput;
/// ```
final class FromSchema {
  const FromSchema(this.schema, {this.registry});

  /// The schema used to infer the generated Dart model.
  final JsonSchema schema;

  /// Optional registry used for resolving schema references.
  final JsonSchemaRegistry? registry;
}
