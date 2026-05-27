part of '../routes.dart';

const _authResultSchema = JsonSchema.object(
  id: 'BetterAuthAuthResult',
  required: ['user', 'session', 'token'],
  properties: <String, JsonSchema>{
    'user': JsonSchema.ref('BetterAuthUser'),
    'session': JsonSchema.ref('BetterAuthSession'),
    'token': JsonSchema.string(),
  },
);

const _adminUserResultSchema = JsonSchema.object(
  id: 'BetterAuthAdminUserResult',
  required: ['user'],
  properties: <String, JsonSchema>{'user': JsonSchema.ref('BetterAuthUser')},
);

const _listUsersResultSchema = JsonSchema.object(
  id: 'BetterAuthListUsersResult',
  required: ['users', 'total'],
  properties: <String, JsonSchema>{
    'users': JsonSchema.array(items: JsonSchema.ref('BetterAuthUser')),
    'total': JsonSchema.integer(),
  },
);

const _sessionResultSchema = JsonSchema.object(
  id: 'BetterAuthSessionResult',
  required: ['user', 'session'],
  properties: <String, JsonSchema>{
    'user': JsonSchema.ref('BetterAuthUser'),
    'session': JsonSchema.ref('BetterAuthSession'),
  },
);

const _successResultSchema = JsonSchema.object(
  id: 'BetterAuthSuccessResult',
  required: ['success'],
  properties: <String, JsonSchema>{'success': JsonSchema.boolean()},
);
