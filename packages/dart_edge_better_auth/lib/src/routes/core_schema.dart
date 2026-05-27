part of '../routes.dart';

const _signUpEmailBodySchema = JsonSchema.object(
  id: 'BetterAuthSignUpEmailBody',
  required: ['email', 'password', 'name'],
  properties: <String, JsonSchema>{
    'email': JsonSchema.string(format: 'email'),
    'password': JsonSchema.string(),
    'name': JsonSchema.string(),
  },
);

const _signInEmailBodySchema = JsonSchema.object(
  id: 'BetterAuthSignInEmailBody',
  required: ['email', 'password'],
  properties: <String, JsonSchema>{
    'email': JsonSchema.string(format: 'email'),
    'password': JsonSchema.string(),
  },
);

const _userSchema = JsonSchema.object(
  id: 'BetterAuthUser',
  required: ['id', 'name', 'email', 'emailVerified', 'createdAt', 'updatedAt'],
  properties: <String, JsonSchema>{
    'id': JsonSchema.string(),
    'name': JsonSchema.string(),
    'email': JsonSchema.string(format: 'email'),
    'emailVerified': JsonSchema.boolean(),
    'image': JsonSchema.string(),
    'createdAt': JsonSchema.string(format: 'date-time'),
    'updatedAt': JsonSchema.string(format: 'date-time'),
    'role': JsonSchema.string(),
  },
);

const _sessionSchema = JsonSchema.object(
  id: 'BetterAuthSession',
  required: ['id', 'expiresAt', 'token', 'createdAt', 'updatedAt', 'userId'],
  properties: <String, JsonSchema>{
    'id': JsonSchema.string(),
    'expiresAt': JsonSchema.string(format: 'date-time'),
    'token': JsonSchema.string(),
    'createdAt': JsonSchema.string(format: 'date-time'),
    'updatedAt': JsonSchema.string(format: 'date-time'),
    'userId': JsonSchema.string(),
  },
);
