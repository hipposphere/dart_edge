part of '../dart_schema_emitter.dart';

String _emitEntrypoint({
  required String databaseClassName,
  required List<_SchemaGroup> schemaGroups,
}) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..body.add(_databaseClass(databaseClassName, schemaGroups));

    for (final group in schemaGroups) {
      builder.directives.add(
        Directive.import('schemas/${group.folderName}/schema.g.dart'),
      );
      builder.directives.add(
        Directive.export('schemas/${group.folderName}/schema.g.dart'),
      );
    }
  });
  return _format(library);
}

String _emitSchemaLibrary(_SchemaGroup group) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..body.add(_schemaClass(group));

    for (final table in group.tables) {
      builder.directives.add(
        Directive.import('tables/${_tableFileName(table)}'),
      );
    }
    for (final table in group.tables) {
      builder.directives.add(
        Directive.export('tables/${_tableFileName(table)}'),
      );
    }
  });
  return _format(library);
}

String _emitTableLibrary(IntrospectedTable table) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..directives.add(
        Directive.import('package:dart_edge_sql/dart_edge_sql.dart'),
      )
      ..body.addAll(_tableSpecs(table));
  });
  return _format(library);
}

Class _databaseClass(
  String databaseClassName,
  List<_SchemaGroup> schemaGroups,
) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = databaseClassName
      ..constructors.add(_privateConstConstructor())
      ..fields.addAll([
        for (final group in schemaGroups)
          _staticConstField(
            name: group.memberName,
            assignment: refer(group.className).property('instance'),
          ),
        _staticConstField(
          name: 'schemas',
          type: _listOf(refer('JsonSchema')),
          assignment: literalList([
            for (final group in schemaGroups)
              refer(group.className).property('schemas').spread,
          ], refer('JsonSchema')),
        ),
        _staticConstField(
          name: 'jsonSchemas',
          type: refer('JsonSchemaRegistry'),
          assignment: refer(
            'JsonSchemaRegistry',
          ).constInstance(const <Expression>[], {'schemas': refer('schemas')}),
        ),
      ]);
  });
}

Class _schemaClass(_SchemaGroup group) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = group.className
      ..constructors.add(_privateConstConstructor())
      ..fields.addAll([
        _staticConstField(
          name: 'instance',
          assignment: refer(group.className).constInstanceNamed('_', const []),
        ),
        _staticConstField(
          name: 'schemaName',
          assignment: literalString(group.schemaName),
        ),
        for (final table in group.tables)
          _staticConstField(
            name: _schemaTableMemberName(table.name),
            assignment: refer(
              '${_upperCamel(table.name)}Table',
            ).property('table'),
          ),
        _staticConstField(
          name: 'schemas',
          type: _listOf(refer('JsonSchema')),
          assignment: literalList([
            for (final table in group.tables) ...[
              refer('${_upperCamel(table.name)}Row').property('jsonSchema'),
              refer('${_upperCamel(table.name)}Insert').property('jsonSchema'),
              refer('${_upperCamel(table.name)}Update').property('jsonSchema'),
            ],
          ], refer('JsonSchema')),
        ),
        _staticConstField(
          name: 'jsonSchemas',
          type: refer('JsonSchemaRegistry'),
          assignment: refer(
            'JsonSchemaRegistry',
          ).constInstance(const <Expression>[], {'schemas': refer('schemas')}),
        ),
      ]);
  });
}
