# better-auth-diesel-sqlite

[![Crates.io](https://img.shields.io/crates/v/better-auth-diesel-sqlite.svg)](https://crates.io/crates/better-auth-diesel-sqlite)
[![Documentation](https://docs.rs/better-auth-diesel-sqlite/badge.svg)](https://docs.rs/better-auth-diesel-sqlite)
[![CI](https://github.com/kryptobaseddev/better-auth-diesel-sqlite/actions/workflows/ci.yml/badge.svg)](https://github.com/kryptobaseddev/better-auth-diesel-sqlite/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![MSRV](https://img.shields.io/badge/MSRV-1.88-brightgreen.svg)](https://blog.rust-lang.org/)
[![Ferrous Forge](https://img.shields.io/badge/standards-ferrous--forge-orange.svg)](https://github.com/kryptobaseddev/ferrous-forge)

A **SQLite database adapter** for [better-auth-rs](https://github.com/better-auth-rs/better-auth-rs) using [Diesel ORM](https://diesel.rs) for compile-time verified queries. Implements all 10 `DatabaseAdapter` operation traits (65 methods) so every better-auth-rs plugin works out of the box with SQLite.

## Why?

[better-auth-rs](https://github.com/better-auth-rs/better-auth-rs) is the most comprehensive authentication framework for Rust — 11 plugins covering email/password, OAuth, organizations, RBAC, 2FA, passkeys, API keys, and admin. It ships with a PostgreSQL adapter. This crate adds **SQLite support**, enabling:

- **Zero-infrastructure auth** — no database server to deploy or manage
- **Edge and embedded** — runs on Raspberry Pi, WASM edge functions, IoT
- **Local-first apps** — offline-capable authentication
- **Rapid prototyping** — start with SQLite, migrate to Postgres when ready

## Installation

```toml
[dependencies]
better-auth = { version = "0.9", features = ["axum"] }
better-auth-diesel-sqlite = "0.1"
```

## Quick Start

```rust,no_run
use axum::Router;
use better_auth::{AuthBuilder, AuthConfig};
use better_auth::plugins::{EmailPasswordPlugin, SessionManagementPlugin};
use better_auth_diesel_sqlite::DieselSqliteAdapter;
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Connect to SQLite (file-based or in-memory)
    let adapter = DieselSqliteAdapter::new("sqlite://auth.db").await?;

    let auth = Arc::new(
        AuthBuilder::new(
            AuthConfig::new("your-secret-key-at-least-32-chars-long")
                .base_url("http://localhost:8080"),
        )
        .database(adapter)
        .plugin(EmailPasswordPlugin::new().enable_signup(true))
        .plugin(SessionManagementPlugin::new())
        .build()
        .await?,
    );

    let app = Router::new()
        .nest("/auth", auth.clone().axum_router())
        .with_state(auth);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    axum::serve(listener, app).await?;
    Ok(())
}
```

## Supported Plugins

All better-auth-rs plugins work identically with this adapter:

| Plugin | Trait | Methods |
|--------|-------|---------|
| Email/Password | `UserOps` | 7 |
| Sessions | `SessionOps` | 8 |
| Account Linking / OAuth | `AccountOps` | 5 |
| Email Verification | `VerificationOps` | 7 |
| Organizations (RBAC) | `OrganizationOps` | 6 |
| Membership | `MemberOps` | 8 |
| Invitations | `InvitationOps` | 6 |
| Two-Factor Auth (TOTP) | `TwoFactorOps` | 4 |
| API Keys | `ApiKeyOps` | 7 |
| WebAuthn Passkeys | `PasskeyOps` | 7 |
| **Total** | **10 traits** | **65 methods** |

## Feature Flags

| Feature | Default | Description |
|---------|---------|-------------|
| `migrations` | Yes | Embed and optionally run schema migrations on startup |
| `bundled-sqlite` | No | Bundle libsqlite3 via `libsqlite3-sys` (no system SQLite needed) |

## Configuration

```rust,no_run
use better_auth_diesel_sqlite::{DieselSqliteAdapter, PoolConfig};
use std::time::Duration;

# async fn example() -> Result<(), Box<dyn std::error::Error>> {
let config = PoolConfig::default()
    .max_connections(16)
    .acquire_timeout(Duration::from_secs(10))
    .run_migrations(true);

let adapter = DieselSqliteAdapter::with_config("sqlite://auth.db", config).await?;
# Ok(())
# }
```

### In-Memory (for testing)

```rust,no_run
# async fn example() -> Result<(), Box<dyn std::error::Error>> {
use better_auth_diesel_sqlite::DieselSqliteAdapter;
let adapter = DieselSqliteAdapter::in_memory().await?;
# Ok(())
# }
```

## Architecture

- **Diesel ORM** for compile-time query verification (no SQL injection possible)
- **`Arc<Mutex<SqliteConnection>>`** with `tokio::task::spawn_blocking` — SQLite is single-writer, so mutex-based access avoids pool contention while keeping the async runtime unblocked
- **SQLite WAL mode** enabled by default for concurrent read performance
- Performance pragmas applied automatically: `busy_timeout`, `synchronous = NORMAL`, `foreign_keys = ON`, `cache_size = 64MB`
- **`#![forbid(unsafe_code)]`** — zero unsafe code in this crate

See [ARCHITECTURE.md](ARCHITECTURE.md) for full technical details.

## Why Diesel?

| Concern | SQLx | Diesel |
|---------|------|--------|
| Query safety | Runtime SQL strings | **Compile-time verified** |
| Schema management | Raw SQL migrations | `diesel_migrations` (embeddable) |
| Type mapping | Manual `FromRow` | Automatic via `Queryable`, `Insertable` |
| SQLite dialect | Manual handling | Native `diesel::sqlite` backend |

## Development Standards

This project enforces [Ferrous Forge](https://github.com/kryptobaseddev/ferrous-forge) ([crates.io](https://crates.io/crates/ferrous-forge)) standards:

- Strict Clippy lints (`unwrap_used = deny`, `expect_used = deny`)
- `#![forbid(unsafe_code)]`
- Enforced formatting via `rustfmt`
- Pre-commit and pre-push git hooks
- Automated CI with security audit

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines and [PLAN.md](PLAN.md) for the implementation roadmap.

## Author

Created by [kryptobaseddev](https://github.com/kryptobaseddev), developer of [Ferrous Forge](https://github.com/kryptobaseddev/ferrous-forge).

## Related Projects

- [better-auth-rs](https://github.com/better-auth-rs/better-auth-rs) — The authentication framework this adapter integrates with
- [better-auth](https://better-auth.com) — The original TypeScript Better Auth project
- [Ferrous Forge](https://github.com/kryptobaseddev/ferrous-forge) — Rust development standards enforcer used in this project
- [Diesel](https://diesel.rs) — The ORM powering this adapter

## License

MIT License. See [LICENSE](LICENSE) for details.
