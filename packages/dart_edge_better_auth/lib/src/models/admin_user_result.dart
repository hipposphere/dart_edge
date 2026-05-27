import 'user.dart';

final class BetterAuthAdminUserResult {
  const BetterAuthAdminUserResult({required this.user});

  final BetterAuthUser user;

  Map<String, Object?> toJson() => {'user': user.toJson()};
}
