part of '../routes.dart';

const _adminCreateUserBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminCreateUserBody',
  required: ['email', 'password', 'name'],
  properties: <String, JsonSchema>{
    'email': JsonSchema.string(format: 'email'),
    'password': JsonSchema.string(),
    'name': JsonSchema.string(),
    'role': JsonSchema.string(),
  },
);

const _adminSetRoleBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminSetRoleBody',
  required: ['userId', 'role'],
  properties: <String, JsonSchema>{
    'userId': JsonSchema.string(),
    'role': JsonSchema.string(),
  },
);

const _adminUpdateUserBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminUpdateUserBody',
  required: ['userId'],
  properties: <String, JsonSchema>{
    'userId': JsonSchema.string(),
    'name': JsonSchema.string(),
    'email': JsonSchema.string(format: 'email'),
    'role': JsonSchema.string(),
  },
);

const _adminUserIdBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminUserIdBody',
  required: ['userId'],
  properties: <String, JsonSchema>{'userId': JsonSchema.string()},
);

const _adminBanUserBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminBanUserBody',
  required: ['userId'],
  properties: <String, JsonSchema>{
    'userId': JsonSchema.string(),
    'banReason': JsonSchema.string(),
    'banExpires': JsonSchema.string(format: 'date-time'),
  },
);

const _adminSetUserPasswordBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminSetUserPasswordBody',
  required: ['userId', 'password'],
  properties: <String, JsonSchema>{
    'userId': JsonSchema.string(),
    'password': JsonSchema.string(),
  },
);

const _adminRevokeUserSessionBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminRevokeUserSessionBody',
  required: ['sessionToken'],
  properties: <String, JsonSchema>{'sessionToken': JsonSchema.string()},
);

const _adminImpersonateUserBodySchema = JsonSchema.object(
  id: 'BetterAuthAdminImpersonateUserBody',
  required: ['userId'],
  properties: <String, JsonSchema>{'userId': JsonSchema.string()},
);
