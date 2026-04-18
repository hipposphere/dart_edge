//! # `better-auth-diesel-sqlite`
//!
//! A `SQLite` database adapter for [`better-auth-rs`](https://github.com/better-auth-rs/better-auth-rs)
//! using [`Diesel`](https://diesel.rs) ORM with `tokio::task::spawn_blocking`
//! for non-blocking database access.
//!
//! This crate implements the full `DatabaseAdapter` trait and all 10 operation sub-traits,
//! enabling `better-auth-rs`'s complete plugin ecosystem (API keys, organizations, admin, 2FA,
//! passkeys, OAuth, sessions, and more) to work with `SQLite` databases.
//!
//! ## Quick Start
//!
//! ```rust,no_run
//! use better_auth::{AuthBuilder, AuthConfig};
//! use better_auth::plugins::{EmailPasswordPlugin, SessionManagementPlugin, ApiKeyPlugin};
//! use better_auth::plugins::api_key::ApiKeyConfig;
//! use better_auth_diesel_sqlite::DieselSqliteAdapter;
//!
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! let adapter = DieselSqliteAdapter::new("sqlite://auth.db").await?;
//!
//! let config = AuthConfig::new("your-secret-key-at-least-32-chars-long")
//!     .base_url("http://localhost:8080");
//!
//! let auth = AuthBuilder::new(config)
//!     .database(adapter)
//!     .plugin(EmailPasswordPlugin::new().enable_signup(true))
//!     .plugin(SessionManagementPlugin::new())
//!     .plugin(ApiKeyPlugin::with_config(ApiKeyConfig {
//!         prefix: Some("sk_".to_string()),
//!         ..ApiKeyConfig::default()
//!     }))
//!     .build()
//!     .await?;
//! # Ok(())
//! # }
//! ```

// Lint configuration is in Cargo.toml [lints] sections.

pub mod adapter;
pub mod config;
pub mod error;
#[allow(missing_docs)]
pub mod models;
pub mod ops;
#[allow(missing_docs)]
pub mod schema;

mod conversions;

pub use adapter::DieselSqliteAdapter;
pub use config::PoolConfig;
pub use error::AdapterError;
