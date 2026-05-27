part of '../routes.dart';

const _signUpEmailOptions = RouteOptions(
  operationId: 'betterAuthSignUpEmail',
  summary: 'Sign up with email and password.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthSignUpEmailBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthAuthResult')),
);

const _signInEmailOptions = RouteOptions(
  operationId: 'betterAuthSignInEmail',
  summary: 'Sign in with email and password.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthSignInEmailBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthAuthResult')),
);

const _getSessionOptions = RouteOptions(
  operationId: 'betterAuthGetSession',
  summary: 'Get the current session.',
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthSessionResult')),
);

const _signOutOptions = RouteOptions(
  operationId: 'betterAuthSignOut',
  summary: 'Sign out the current session.',
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthSuccessResult')),
);

const _adminCreateUserOptions = RouteOptions(
  operationId: 'betterAuthAdminCreateUser',
  summary: 'Create a user as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminCreateUserBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(
    schema: JsonSchema.ref('BetterAuthAdminUserResult'),
  ),
);

const _adminSetRoleOptions = RouteOptions(
  operationId: 'betterAuthAdminSetRole',
  summary: 'Set a user role as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminSetRoleBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(
    schema: JsonSchema.ref('BetterAuthAdminUserResult'),
  ),
);

const _adminListUsersOptions = RouteOptions(
  operationId: 'betterAuthAdminListUsers',
  summary: 'List users as an admin.',
  success: ResponseSpec.json(
    schema: JsonSchema.ref('BetterAuthListUsersResult'),
  ),
);

const _adminUpdateUserOptions = RouteOptions(
  operationId: 'betterAuthAdminUpdateUser',
  summary: 'Update a user as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminUpdateUserBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(
    schema: JsonSchema.ref('BetterAuthAdminUserResult'),
  ),
);

const _adminBanUserOptions = RouteOptions(
  operationId: 'betterAuthAdminBanUser',
  summary: 'Ban a user as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminBanUserBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(
    schema: JsonSchema.ref('BetterAuthAdminUserResult'),
  ),
);

const _adminUnbanUserOptions = RouteOptions(
  operationId: 'betterAuthAdminUnbanUser',
  summary: 'Unban a user as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminUserIdBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(
    schema: JsonSchema.ref('BetterAuthAdminUserResult'),
  ),
);

const _adminRemoveUserOptions = RouteOptions(
  operationId: 'betterAuthAdminRemoveUser',
  summary: 'Remove a user as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminUserIdBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthSuccessResult')),
);

const _adminSetUserPasswordOptions = RouteOptions(
  operationId: 'betterAuthAdminSetUserPassword',
  summary: 'Set a user password as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminSetUserPasswordBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthSuccessResult')),
);

const _adminRevokeUserSessionOptions = RouteOptions(
  operationId: 'betterAuthAdminRevokeUserSession',
  summary: 'Revoke one user session as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminRevokeUserSessionBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthSuccessResult')),
);

const _adminRevokeUserSessionsOptions = RouteOptions(
  operationId: 'betterAuthAdminRevokeUserSessions',
  summary: 'Revoke all sessions for a user as an admin.',
  body: RequestBody.json(
    schema: JsonSchema.ref('BetterAuthAdminUserIdBody'),
    decoder: _decodeJsonObject,
  ),
  success: ResponseSpec.json(schema: JsonSchema.ref('BetterAuthSuccessResult')),
);
