import 'user.dart';

final class BetterAuthListUsersResult {
  const BetterAuthListUsersResult({required this.users, required this.total});

  final List<BetterAuthUser> users;
  final int total;

  Map<String, Object?> toJson() => {
    'users': users.map((user) => user.toJson()).toList(),
    'total': total,
  };
}
