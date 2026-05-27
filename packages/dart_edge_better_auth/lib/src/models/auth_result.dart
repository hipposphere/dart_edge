import 'session.dart';
import 'user.dart';

final class BetterAuthAuthResult {
  const BetterAuthAuthResult({required this.user, required this.session});

  final BetterAuthUser user;
  final BetterAuthSession session;

  String get token => session.token;

  Map<String, Object?> toJson() => {
    'user': user.toJson(),
    'session': session.toJson(),
    'token': token,
  };
}
