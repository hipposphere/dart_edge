import 'session.dart';

final class BetterAuthListUserSessionsResult {
  const BetterAuthListUserSessionsResult({required this.sessions});

  final List<BetterAuthSession> sessions;

  Map<String, Object?> toJson() => {
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };
}
