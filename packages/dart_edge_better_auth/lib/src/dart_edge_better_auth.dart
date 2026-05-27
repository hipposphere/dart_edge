import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'api.dart';
import 'config.dart';
import 'database.dart';
import 'gateway/better_auth_gateways.dart';
import 'routes.dart';
import 'trusted_api.dart';

final class DartEdgeBetterAuth<TServices> {
  DartEdgeBetterAuth({required this.options, required this.sqlPool});

  final BetterAuthOptions options;
  final SqlPool Function(TServices services) sqlPool;

  BetterAuthApi get api {
    throw StateError(
      'Direct Better Auth API calls need a SqlPool. Use '
      'DartEdgeBetterAuth.withPool for direct calls.',
    );
  }

  BetterAuthTrustedApi get trusted {
    throw StateError(
      'Trusted Better Auth API calls need a SqlPool. Use '
      'DartEdgeBetterAuth.withPool for direct calls.',
    );
  }

  BetterAuthGateways get gateways {
    throw StateError(
      'Better Auth gateways need a SqlPool. Use '
      'DartEdgeBetterAuth.withPool for direct gateway calls.',
    );
  }

  Router<TServices> router() {
    final router = Router<TServices>();
    mount(router);
    return router;
  }

  void mount(Router<TServices> router) {
    mountBetterAuthRoutes(router, this);
  }

  BetterAuthStore storeFor(TServices services) {
    return BetterAuthStore(pool: sqlPool(services), options: options);
  }

  BetterAuthApi apiFor(TServices services) => BetterAuthApi(storeFor(services));

  BetterAuthGateways gatewaysFor(TServices services) =>
      storeFor(services).gateways;

  BetterAuthTrustedApi trustedFor(TServices services) {
    return BetterAuthTrustedApi(storeFor(services));
  }

  static DartEdgeBetterAuth<void> withPool({
    required BetterAuthOptions options,
    required SqlPool pool,
  }) {
    return _DirectDartEdgeBetterAuth(options: options, pool: pool);
  }
}

final class _DirectDartEdgeBetterAuth extends DartEdgeBetterAuth<void> {
  _DirectDartEdgeBetterAuth({required super.options, required SqlPool pool})
    : _pool = pool,
      super(sqlPool: (_) => pool) {
    final store = BetterAuthStore(pool: _pool, options: options);
    _directApi = BetterAuthApi(store);
    _directTrusted = BetterAuthTrustedApi(store);
    _directGateways = store.gateways;
  }

  final SqlPool _pool;
  late final BetterAuthApi _directApi;
  late final BetterAuthTrustedApi _directTrusted;
  late final BetterAuthGateways _directGateways;

  @override
  BetterAuthApi get api => _directApi;

  @override
  BetterAuthTrustedApi get trusted => _directTrusted;

  @override
  BetterAuthGateways get gateways => _directGateways;
}
