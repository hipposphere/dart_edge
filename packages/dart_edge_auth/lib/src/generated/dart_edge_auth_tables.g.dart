import 'package:dart_edge_core/dart_edge_core.dart';
import 'schemas/default/schema.g.dart';
export 'schemas/default/schema.g.dart';

final class DartEdgeAuthTables {
  const DartEdgeAuthTables._();

  static const defaultSchema = DefaultSchema.instance;

  static const List<JsonSchema> schemas = <JsonSchema>[
    ...DefaultSchema.schemas,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}
