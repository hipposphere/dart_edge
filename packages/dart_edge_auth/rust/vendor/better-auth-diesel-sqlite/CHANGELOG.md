# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-03-22

### Added

- Full `DatabaseAdapter` implementation — all 10 `*Ops` traits (65 async methods)
  - `UserOps`: CRUD, search/filter/pagination via `list_users`, ban/unban logic
  - `SessionOps`: token-based sessions, expiry management, org context switching
  - `AccountOps`: OAuth provider linking with dual token expiry fields
  - `VerificationOps`: atomic `consume_verification` (select+delete), expired cleanup
  - `OrganizationOps`: CRUD with member join for `list_user_organizations`
  - `MemberOps`: membership CRUD, role updates, member/owner counting
  - `InvitationOps`: invitation lifecycle with status transitions
  - `TwoFactorOps`: TOTP secret and backup code management
  - `ApiKeyOps`: key lifecycle with hash-based lookup, expired key cleanup
  - `PasskeyOps`: WebAuthn credential CRUD with counter/name updates
- Conversion layer (`conversions.rs`) with `From` impls for all entity types
  - `parse_datetime()` / `format_datetime()` / `now_iso()` timestamp helpers
  - `invitation_status_to_string()` enum mapper
  - JSON metadata serialization/deserialization
  - `u64` <-> `i64` counter casting for passkeys
- Error mapping (`error.rs`)
  - `diesel_to_database_error()` — maps Diesel errors to `DatabaseError` variants
  - `diesel_to_auth_error()` — convenience wrapper for `AuthError::Database`
  - `From<AdapterError> for AuthError` implementation
  - Handles UniqueViolation, ForeignKeyViolation, RollbackTransaction, NotFound
- `DieselSqliteAdapter` core implementation
  - `Arc<Mutex<SqliteConnection>>` with `tokio::task::spawn_blocking`
  - `interact()` method — async bridge that locks mutex inside blocking thread
  - SQLite pragmas: WAL mode, busy_timeout=5000, synchronous=NORMAL, foreign_keys=ON, cache_size=64MB
  - `run_migrations()` with embedded `diesel_migrations`
- 61 integration tests across 10 test modules + 2 doctests (63 total)
- `tests/common/mod.rs` with `test_adapter()` helper for in-memory testing

### Changed

- Schema updated to match actual `better-auth-core` 0.9.0 entity types
  - Table names match `Auth*Meta` defaults (`users`, `sessions`, `accounts`, `api_keys`, `passkeys`)
  - Account fields: `account_id`/`provider_id` (not `provider`/`provider_account_id`)
  - ApiKey: column `key` for hash, full rate limiting fields, permissions, metadata
  - Passkey: `name` field (not `authenticator_name`), `counter` as `i64`
- Models updated with all fields from upstream types
- Connection strategy: `Arc<Mutex<SqliteConnection>>` instead of connection pool

### Fixed

- ARCHITECTURE.md: diagram corrected to show `Arc<Mutex<SqliteConnection>>`
- ARCHITECTURE.md: file structure updated to match actual test layout
- ARCHITECTURE.md: testing strategy rewritten to reflect 61 integration tests
- PLAN.md: all Phase 1-3 checkboxes updated to reflect completion
- PLAN.md: method names corrected to match `better-auth-core` trait signatures
- VISION.md: async strategy description corrected
- `src/ops/mod.rs`: VerificationOps count 5->7, PasskeyOps count 6->7
- `src/lib.rs`: crate doc corrected to reference `spawn_blocking`

## [0.1.0] - 2026-03-22

### Added

- Project scaffolding with full Diesel ORM schema for better-auth-rs
- `DieselSqliteAdapter` struct with constructor stubs (`new`, `with_config`, `in_memory`)
- `PoolConfig` builder for connection pool configuration
- `AdapterError` enum with Diesel error mapping foundation
- Diesel `table!` macro definitions for all 10 auth tables
- Diesel model structs (`*Row`, `New*Row`, `Update*Row`) for all entities
- SQLite migration (`up.sql` / `down.sql`) creating the full auth schema
- ferrous-forge integration with strict lint enforcement
- CI workflow via GitHub Actions
- `bundled-sqlite` feature flag for bundling libsqlite3

[Unreleased]: https://github.com/kryptobaseddev/better-auth-diesel-sqlite/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/kryptobaseddev/better-auth-diesel-sqlite/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/kryptobaseddev/better-auth-diesel-sqlite/releases/tag/v0.1.0
