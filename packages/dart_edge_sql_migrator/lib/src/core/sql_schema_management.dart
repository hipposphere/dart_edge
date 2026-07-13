/// Kinds of schema objects that can be included in a managed diff.
enum SqlSchemaObjectKind {
  table,
  column,
  checkConstraint,
  uniqueConstraint,
  foreignKey,
  secondaryIndex,
  routine,
}

/// How the diff engine should treat a matching schema object.
enum SqlSchemaObjectManagement {
  /// Compare the object and plan additions, replacements, and removals.
  managed,

  /// Ignore the object completely because another owner manages it.
  unmanaged,

  /// Preserve the object because the diff engine cannot manage it safely.
  unsupported,
}

/// Stable identity for one schema object considered by a diff.
final class SqlSchemaObject {
  const SqlSchemaObject({
    required this.kind,
    required this.name,
    this.schema,
    this.table,
    this.identityArguments,
  });

  final SqlSchemaObjectKind kind;
  final String? schema;
  final String? table;
  final String name;
  final String? identityArguments;

  /// Human-readable qualified object name.
  String get displayName {
    final qualifiedName = <String>[?schema, ?table, name].join('.');
    return switch (identityArguments) {
      final String arguments => '$qualifiedName($arguments)',
      null => qualifiedName,
    };
  }

  @override
  String toString() => '${kind.name}:$displayName';
}

/// One ordered object-management rule.
///
/// Null match fields act as wildcards. Rules are evaluated in list order and
/// the first matching rule wins.
final class SqlSchemaManagementRule {
  const SqlSchemaManagementRule({
    required this.management,
    this.kind,
    this.schema,
    this.table,
    this.name,
  });

  final SqlSchemaObjectManagement management;
  final SqlSchemaObjectKind? kind;
  final String? schema;
  final String? table;
  final String? name;

  bool matches(SqlSchemaObject object) {
    return (kind == null || kind == object.kind) &&
        (schema == null || schema == object.schema) &&
        (table == null || table == object.table) &&
        (name == null || name == object.name);
  }
}

/// Controls which introspected objects are owned by a schema diff.
final class SqlSchemaManagementScope {
  const SqlSchemaManagementScope({
    this.defaultManagement = SqlSchemaObjectManagement.managed,
    this.rules = const <SqlSchemaManagementRule>[],
  });

  /// Management used when no rule matches.
  final SqlSchemaObjectManagement defaultManagement;

  /// Ordered rules; the first matching rule wins.
  final List<SqlSchemaManagementRule> rules;

  SqlSchemaObjectManagement managementFor(SqlSchemaObject object) {
    for (final rule in rules) {
      if (rule.matches(object)) {
        return rule.management;
      }
    }
    return defaultManagement;
  }
}
