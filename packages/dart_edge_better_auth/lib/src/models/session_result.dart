import 'session.dart';
import 'user.dart';

final class BetterAuthSessionResult {
  const BetterAuthSessionResult({required this.session, required this.user});

  final BetterAuthSession session;
  final BetterAuthUser user;

  Map<String, Object?> toJson() => {
    'session': session.toJson(),
    'user': user.toJson(),
  };
}
