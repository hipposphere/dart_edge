import 'package:dart_edge_core/dart_edge_core.dart';

import 'dart_edge_better_auth.dart';
import 'error.dart';

part 'routes/admin_moderation_routes.dart';
part 'routes/admin_schema.dart';
part 'routes/admin_session_routes.dart';
part 'routes/admin_user_routes.dart';
part 'routes/core_routes.dart';
part 'routes/core_schema.dart';
part 'routes/result_schema.dart';
part 'routes/route_base.dart';
part 'routes/route_options.dart';
part 'routes/schema.dart';

const betterAuthSchemaRegistry = JsonSchemaRegistry(
  schemas: <JsonSchema>[
    _signUpEmailBodySchema,
    _signInEmailBodySchema,
    _adminCreateUserBodySchema,
    _adminSetRoleBodySchema,
    _adminUpdateUserBodySchema,
    _adminUserIdBodySchema,
    _adminBanUserBodySchema,
    _adminSetUserPasswordBodySchema,
    _adminRevokeUserSessionBodySchema,
    _userSchema,
    _sessionSchema,
    _authResultSchema,
    _adminUserResultSchema,
    _listUsersResultSchema,
    _sessionResultSchema,
    _successResultSchema,
  ],
);

void mountBetterAuthRoutes<TServices>(
  Router<TServices> router,
  DartEdgeBetterAuth<TServices> auth,
) {
  final scoped = router.router(auth.options.basePath);
  scoped.routePost('/sign-up/email', _SignUpEmailRoute<TServices>(auth));
  scoped.routePost('/sign-in/email', _SignInEmailRoute<TServices>(auth));
  scoped.routeGet('/get-session', _GetSessionRoute<TServices>(auth));
  scoped.routePost('/sign-out', _SignOutRoute<TServices>(auth));
  scoped.routePost(
    '/admin/create-user',
    _AdminCreateUserRoute<TServices>(auth),
  );
  scoped.routePost('/admin/set-role', _AdminSetRoleRoute<TServices>(auth));
  scoped.routeGet('/admin/list-users', _AdminListUsersRoute<TServices>(auth));
  scoped.routePost(
    '/admin/update-user',
    _AdminUpdateUserRoute<TServices>(auth),
  );
  scoped.routePost('/admin/ban-user', _AdminBanUserRoute<TServices>(auth));
  scoped.routePost('/admin/unban-user', _AdminUnbanUserRoute<TServices>(auth));
  scoped.routePost(
    '/admin/remove-user',
    _AdminRemoveUserRoute<TServices>(auth),
  );
  scoped.routePost(
    '/admin/set-user-password',
    _AdminSetUserPasswordRoute<TServices>(auth),
  );
  scoped.routePost(
    '/admin/revoke-user-session',
    _AdminRevokeUserSessionRoute<TServices>(auth),
  );
  scoped.routePost(
    '/admin/revoke-user-sessions',
    _AdminRevokeUserSessionsRoute<TServices>(auth),
  );
}
