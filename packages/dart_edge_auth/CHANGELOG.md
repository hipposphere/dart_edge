## 0.3.34

- Update SQL package constraints for `dart_edge_sql` 0.3.28 and
  `dart_edge_sql_codegen` 0.3.34.

## 0.3.16

- Use Better Auth's singular default table names and camelCase default columns
  for generated auth schemas, migrations, and native shared database queries.
- Bump the native artifact version to 0.1.9.
- Allow generic OAuth providers to omit `clientSecret`; native token exchange
  omits `client_secret` for public-client PKCE flows when no secret is set.
- Allow generic OIDC providers to omit `userInfoUrl`; native callback handling
  maps the user profile from `id_token` claims when no endpoint is configured.
- Improve generic OAuth user-info mapping for Microsoft Entra and Graph fields.
- Expose internal Better Auth OAuth errors on native 500 responses for
  debugging.

## 0.3.12

- Bump the native artifact version to 0.1.4 for Rust 1.95 and dependency
  updates.

## 0.3.10

- Add `DartEdgeAuth.trustedAdmin` for deliberately trusted server-side admin
  calls that do not require an admin session token.
- Bump the native artifact version to 0.1.3 for the trusted admin ABI.

## 0.3.9

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2 and `dart_edge_sql` 0.3.8.

## 0.3.7

- Publish Linux arm64 native artifacts.
- Update Dart Edge native package constraints.

## 0.3.6

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.
- Update Dart Edge native package constraints.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
