import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'schemas/default/schema.dart';

final class AppSchema {
  const AppSchema._();

  static const defaultSchema = DefaultSchema.instance;

  static const schemas = <JsonSchema>[...DefaultSchema.schemas];

  static const jsonSchemas = JsonSchemaRegistry(schemas: schemas);
}
