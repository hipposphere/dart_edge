import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'schemas/default/schema.g.dart';
export 'schemas/default/schema.g.dart';

final class AppSchema {
  const AppSchema._();

  static const defaultSchema = DefaultSchema.instance;

  static const List<JsonSchema> schemas = <JsonSchema>[
    ...DefaultSchema.schemas,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}
