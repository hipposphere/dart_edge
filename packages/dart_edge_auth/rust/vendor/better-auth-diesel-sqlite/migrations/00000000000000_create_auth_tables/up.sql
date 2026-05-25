-- better-auth-diesel-sqlite schema
-- SQLite dialect, matching better-auth-rs entity and meta trait expectations.
-- Table names match Better Auth defaults.

CREATE TABLE IF NOT EXISTS "user" (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT,
    email TEXT NOT NULL UNIQUE,
    username TEXT UNIQUE,
    "displayUsername" TEXT,
    "emailVerified" BOOLEAN NOT NULL DEFAULT 0,
    image TEXT,
    role TEXT NOT NULL DEFAULT 'user',
    banned BOOLEAN NOT NULL DEFAULT 0,
    "banReason" TEXT,
    "banExpires" TEXT,
    "twoFactorEnabled" BOOLEAN NOT NULL DEFAULT 0,
    metadata TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_email ON "user" (email);
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_username ON "user" (username);

CREATE TABLE IF NOT EXISTS "session" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "expiresAt" TEXT NOT NULL,
    "activeOrganizationId" TEXT,
    "impersonatedBy" TEXT,
    active BOOLEAN NOT NULL DEFAULT 1,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_session_token ON "session" (token);
CREATE INDEX IF NOT EXISTS idx_session_userId ON "session" ("userId");

CREATE TABLE IF NOT EXISTS "account" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    "accountId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "accessToken" TEXT,
    "refreshToken" TEXT,
    "idToken" TEXT,
    "accessTokenExpiresAt" TEXT,
    "refreshTokenExpiresAt" TEXT,
    scope TEXT,
    password TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_account_userId ON "account" ("userId");
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_provider ON "account" ("providerId", "accountId");

CREATE TABLE IF NOT EXISTS "verification" (
    id TEXT PRIMARY KEY NOT NULL,
    identifier TEXT NOT NULL,
    value TEXT NOT NULL,
    "expiresAt" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_verification_identifier ON "verification" (identifier);
CREATE INDEX IF NOT EXISTS idx_verification_value ON "verification" (value);

CREATE TABLE IF NOT EXISTS "organization" (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    logo TEXT,
    metadata TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_slug ON "organization" (slug);

CREATE TABLE IF NOT EXISTS "member" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    organization_id TEXT NOT NULL REFERENCES "organization" (id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    "createdAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_member_userId ON "member" ("userId");
CREATE INDEX IF NOT EXISTS idx_member_org_id ON "member" (organization_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_member_user_org ON "member" ("userId", organization_id);

CREATE TABLE IF NOT EXISTS "invitation" (
    id TEXT PRIMARY KEY NOT NULL,
    organization_id TEXT NOT NULL REFERENCES "organization" (id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    status TEXT NOT NULL DEFAULT 'pending',
    inviter_id TEXT NOT NULL REFERENCES "user" (id),
    "expiresAt" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_invitation_org_id ON "invitation" (organization_id);
CREATE INDEX IF NOT EXISTS idx_invitation_email ON "invitation" (email);

CREATE TABLE IF NOT EXISTS "two_factor" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL UNIQUE REFERENCES "user" (id) ON DELETE CASCADE,
    secret TEXT NOT NULL,
    backup_codes TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_two_factor_userId ON "two_factor" ("userId");

CREATE TABLE IF NOT EXISTS "api_keys" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    name TEXT,
    start TEXT,
    prefix TEXT,
    "key" TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT 1,
    rate_limit_enabled BOOLEAN NOT NULL DEFAULT 0,
    rate_limit_time_window INTEGER,
    rate_limit_max INTEGER,
    request_count INTEGER,
    remaining INTEGER,
    refill_interval INTEGER,
    refill_amount INTEGER,
    last_refill_at TEXT,
    last_request TEXT,
    "expiresAt" TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,
    permissions TEXT,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_api_keys_userId ON "api_keys" ("userId");
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON "api_keys" ("key");

CREATE TABLE IF NOT EXISTS "passkeys" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    counter INTEGER NOT NULL DEFAULT 0,
    device_type TEXT NOT NULL DEFAULT '',
    backed_up BOOLEAN NOT NULL DEFAULT 0,
    transports TEXT,
    "createdAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_passkeys_userId ON "passkeys" ("userId");
CREATE UNIQUE INDEX IF NOT EXISTS idx_passkeys_credential_id ON "passkeys" (credential_id);
