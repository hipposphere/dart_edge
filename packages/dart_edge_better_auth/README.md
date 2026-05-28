# dart_edge_better_auth

Pure Dart Better Auth-compatible authentication for Dart Edge.

This package is intentionally independent from the Rust-backed
`dart_edge_auth` package. It currently implements the Better Auth-compatible
foundation: email/password users, credential accounts, sessions, explicit
migrations, route mounting, and trusted server-side admin bootstrapping.

## Example

```dart
final pool = PostgresPool.withUrl(connectionString);

await DartEdgeBetterAuthMigrator(pool: pool).migrateToLatest();

final auth = DartEdgeBetterAuth.withPool(
  options: const BetterAuthOptions(
    secret: 'replace-with-a-long-secret',
    baseUrl: 'https://example.com',
  ),
  pool: pool,
);

await auth.trusted.admin.createUser(
  email: 'admin@example.com',
  password: 'password123',
  name: 'Admin',
);

final router = auth.router();
```

For application services, construct `DartEdgeBetterAuth<TServices>` with a
`SqlPool Function(TServices)` and mount it into the app router.

## Gateways

The package exposes one operation boundary for each auth domain:

- `auth.gateways.credentials` for email/password sign up and sign in
- `auth.gateways.sessions` for lookup, sign out, and revocation
- `auth.gateways.users` for trusted user writes and lookups
- `auth.gateways.admin` for token-guarded admin operations

The HTTP routes, trusted API, and direct server API all call through these
gateways. That keeps route parsing, trusted bootstrapping, and SQL persistence
separate while preserving one implementation path for validation, hashing, and
session behavior.

## Parity Status

Target upstream baseline: Better Auth `1.6.11`.

The upstream parity matrix lives at
`test/better_auth_harness/parity_matrix.json`. It lists the currently enabled
compatibility coverage and the upstream suites still pending.

Implemented:

- email/password sign up and sign in
- Better Auth scrypt password hash verification and generation
- Better Auth-compatible `user`, `account`, `session`, `verification`, and
  `passkey` table migrations
- generated `dart_edge_sql` models in `lib/generated`
- session lookup and sign out
- trusted server-side user/admin creation, role setting, list users, and session
  revocation
- admin create, update, remove, ban, unban, role, password, list, and session
  revocation APIs guarded by an admin session
- admin impersonation sessions with Better Auth-compatible `impersonatedBy`
  persistence and admin-target protection
- operation gateways for credentials, sessions, users, and admin workflows
- TypeScript Better Auth database interop tests for TS-created and Dart-created
  accounts

Not implemented yet:

- full admin access-control statement parity
- OAuth social providers
- generic OAuth
- OAuth/OIDC provider
- passkey/WebAuthn behavior beyond schema creation
- phone number flows
- remaining Better Auth first-party plugins

## Harness

Regenerate the checked-in database models:

```sh
dart run tool/generate_better_auth_models.dart
```

Run the Dart tests only:

```sh
dart test
```

Run the pinned TypeScript Better Auth bridge as well:

```sh
dart run tool/run_better_auth_harness.dart
```

The harness installs the Node fixture with `npm ci` and then runs the package
tests with the TypeScript interop cases enabled.
