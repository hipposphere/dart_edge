import '../database.dart';
import 'admin_gateway.dart';
import 'credentials_gateway.dart';
import 'session_gateway.dart';
import 'user_gateway.dart';

final class BetterAuthGateways {
  BetterAuthGateways(BetterAuthStore store)
    : credentials = BetterAuthCredentialGateway(store),
      sessions = BetterAuthSessionGateway(store),
      users = BetterAuthUserGateway(store),
      admin = BetterAuthAdminGateway(store);

  final BetterAuthCredentialGateway credentials;
  final BetterAuthSessionGateway sessions;
  final BetterAuthUserGateway users;
  final BetterAuthAdminGateway admin;
}
