part of '../database.dart';

extension BetterAuthStoreSql on BetterAuthStore {
  SqlStatement _statement(String text, Map<String, Object?> parameters) {
    if (pool.dialect == SqlDialect.sqlite) {
      final values = <Object?>[];
      final positionalText = text.replaceAllMapped(
        RegExp(r'@[A-Za-z_][A-Za-z0-9_]*'),
        (match) {
          final name = match.group(0)!.substring(1);
          if (!parameters.containsKey(name)) {
            return match.group(0)!;
          }
          values.add(parameters[name]);
          return '?';
        },
      );
      return sql(positionalText, parameters: values);
    }
    return sql(text, parameters: parameters);
  }

  SqlStatement _insertStatement(
    SqlTable<dynamic, dynamic, dynamic> table,
    Map<String, Object?> values,
  ) {
    final presentValues = {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    final columns = presentValues.keys.toList();
    final columnSql = columns.map((column) => '"$column"').join(', ');
    final placeholders = columns.map(_placeholder).join(', ');
    return _statement(
      'INSERT INTO ${_table(table.name)} ($columnSql) VALUES ($placeholders)',
      presentValues,
    );
  }

  DefaultSchema get _schema =>
      DefaultSchema(databaseSchema: options.database.postgresSchema);

  String _placeholder(String name) =>
      pool.dialect == SqlDialect.sqlite ? '@$name' : '@$name';

  String _typedPlaceholder(String name, String postgresType) {
    final placeholder = _placeholder(name);
    return pool.dialect == SqlDialect.postgres
        ? 'CAST($placeholder AS $postgresType)'
        : placeholder;
  }

  String _table(String name) {
    final quoted = '"$name"';
    final schema = options.database.postgresSchema;
    if (pool.dialect == SqlDialect.postgres && schema != null) {
      return '"$schema".$quoted';
    }
    return quoted;
  }
}
