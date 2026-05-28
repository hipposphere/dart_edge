final class BetterAuthRoleInput {
  const BetterAuthRoleInput._(this.roles);

  factory BetterAuthRoleInput.one(String role) {
    return BetterAuthRoleInput._([role]);
  }

  factory BetterAuthRoleInput.many(List<String> roles) {
    return BetterAuthRoleInput._(List.unmodifiable(roles));
  }

  static BetterAuthRoleInput decode(Object? value) {
    return switch (value) {
      final String role => BetterAuthRoleInput.one(role),
      final List<Object?> roles => BetterAuthRoleInput.many(
        roles.cast<String>(),
      ),
      _ => throw const FormatException('Expected role or role list.'),
    };
  }

  final List<String> roles;

  String get commaSeparated => roles.join(',');

  Object toJson() => roles.length == 1 ? roles.single : roles;
}
