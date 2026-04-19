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

  /// Raw Better Auth session object.
  final Map<String, Object?> session;

  /// Raw Better Auth user object.
  final Map<String, Object?> user;

  /// Original Better Auth API response.
  final DartEdgeAuthApiResponse response;

  /// Resolved user id when present.
  String? get userId => user['id'] as String?;

  /// Resolved user email when present.
  String? get email => user['email'] as String?;

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
    print('AuthGuard: Authorization header: $authorizationHeader');
    final hasBearer =
        authorizationHeader != null &&
        authorizationHeader.startsWith('Bearer ');

    if (!hasBearer && !headers.containsKey('cookie')) {
      return GuardResult.deny(_unauthorized(ctx));
    }

    final response = auth.api.callOperationSync(
      operationId: 'get_session',
      headers: headers,
    );
    final identity = _identityFrom(response);
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

  DartEdgeAuthIdentity? _identityFrom(DartEdgeAuthApiResponse response) {
    if (!response.isSuccess) {
      return null;
    }

    final jsonBody = response.jsonBody;
    if (jsonBody is! Map<String, Object?>) {
      return null;
    }

    final session = jsonBody['session'];
    final user = jsonBody['user'];
    if (session is! Map<String, Object?> || user is! Map<String, Object?>) {
      return null;
    }

    return DartEdgeAuthIdentity(
      session: session,
      user: user,
      response: response,
    );
  }

  Map<String, String> _headersFor(RequestContext<TServices> ctx) {
    final value = ctx.input.headerValue;
    if (value is Map<String, String>) {
      return value;
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': switch (entry.value) {
            final String text => text,
            final Object raw => '$raw',
            null => '',
          },
      };
    }
    return const <String, String>{};
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
