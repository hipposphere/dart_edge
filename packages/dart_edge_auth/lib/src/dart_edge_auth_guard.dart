import 'dart:async';
import 'dart:io';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'dart_edge_auth.dart';

/// Authenticated Better Auth identity resolved for the current request.
final class DartEdgeAuthIdentity implements JsonEncodable {
  const DartEdgeAuthIdentity({
    required this.session,
    required this.user,
    required this.response,
  });

  /// Resolved Better Auth session.
  final DartEdgeAuthSession session;

  /// Resolved Better Auth user.
  final DartEdgeAuthUser user;

  /// Original typed Better Auth API result.
  final DartEdgeAuthSessionResult response;

  /// Serialized Better Auth session object.
  Map<String, Object?> get sessionJson => session.toJson();

  /// Serialized Better Auth user object.
  Map<String, Object?> get userJson => user.toJson();

  /// Resolved user id when present.
  String get userId => user.id;

  /// Resolved user email when present.
  String? get email => user.email;

  @override
  Map<String, Object?> toJson() => {'session': session, 'user': user};
}

/// Optional authorization hook run after authentication succeeds.
typedef DartEdgeAuthorizationCheck<TServices> =
    FutureOr<GuardResult> Function(
      RequestContext<TServices> ctx,
      DartEdgeAuthIdentity identity,
    );

/// Better Auth-backed guard that authenticates and stores the resolved identity.
final class DartEdgeAuthGuard<TServices> implements Guard<TServices> {
  DartEdgeAuthGuard({
    required this.auth,
    this.onUnauthorized,
    this.authorization,
  });

  /// Better Auth instance used for session resolution.
  final DartEdgeAuth auth;

  /// Optional custom response emitted when authentication fails.
  final RawResponse Function(RequestContext<TServices> ctx)? onUnauthorized;

  /// Optional authorization check run after authentication succeeds.
  final DartEdgeAuthorizationCheck<TServices>? authorization;

  @override
  Future<GuardResult> authorize(RequestContext<TServices> ctx) async {
    final headers = _headersFor(ctx);
    final authorizationHeader = headers['authorization'];
    final hasBearer =
        authorizationHeader != null &&
        authorizationHeader.startsWith('Bearer ');

    if (!hasBearer && !headers.containsKey('cookie')) {
      return GuardResult.deny(_unauthorized(ctx));
    }

    final response = await auth.api.tryGetSession(headers: headers);
    final identity = response == null ? null : _identityFrom(response);
    if (identity == null) {
      return GuardResult.deny(_unauthorized(ctx));
    }

    ctx.put(identity);

    final authorizationCheck = authorization;
    if (authorizationCheck == null) {
      return const GuardResult.allow();
    }

    return await Future.sync(() => authorizationCheck(ctx, identity));
  }

  RawResponse _unauthorized(RequestContext<TServices> ctx) {
    final builder = onUnauthorized;
    if (builder != null) {
      return builder(ctx);
    }

    return RawResponse.json(
      status: HttpStatus.unauthorized,
      body: {'error': 'unauthorized'},
    );
  }

  DartEdgeAuthIdentity _identityFrom(DartEdgeAuthSessionResult response) {
    return DartEdgeAuthIdentity(
      session: response.session,
      user: response.user,
      response: response,
    );
  }

  Map<String, String> _headersFor(RequestContext<TServices> ctx) {
    return ctx.req.headersMap;
  }

  @override
  String toString() => 'DartEdgeAuthGuard<$TServices>()';
}

/// Request-context helpers for Better Auth identities resolved by the guard.
extension DartEdgeAuthRequestContext<TServices> on RequestContext<TServices> {
  /// Returns the current authenticated identity or `null` when absent.
  DartEdgeAuthIdentity? get authIdentity => maybe<DartEdgeAuthIdentity>();

  /// Returns the current authenticated identity or throws when absent.
  DartEdgeAuthIdentity get requireAuthIdentity =>
      require<DartEdgeAuthIdentity>();
}
