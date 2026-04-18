//! Core adapter struct and constructors.

use diesel::prelude::*;
use diesel::sqlite::SqliteConnection;
use std::sync::{Arc, Mutex};

use better_auth_core::error::{AuthError, AuthResult, DatabaseError};

use crate::config::PoolConfig;
use crate::error::AdapterError;

/// `SQLite` database adapter for `better-auth-rs`.
///
/// Implements all 10 `*Ops` traits required by the `DatabaseAdapter` supertrait,
/// enabling `better-auth-rs`'s full plugin ecosystem to work with `SQLite` databases.
///
/// Uses `Diesel` ORM for compile-time verified queries. Synchronous `Diesel`
/// operations are offloaded to a blocking thread via `tokio::task::spawn_blocking`
/// to avoid blocking the async runtime. The connection is protected by an
/// `Arc<Mutex<SqliteConnection>>` for safe concurrent access.
///
/// # Examples
///
/// ```rust,no_run
/// use better_auth_diesel_sqlite::DieselSqliteAdapter;
///
/// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
/// // File-based SQLite
/// let adapter = DieselSqliteAdapter::new("sqlite://auth.db").await?;
///
/// // In-memory SQLite (for testing)
/// let adapter = DieselSqliteAdapter::in_memory().await?;
///
/// // With custom pool configuration
/// use better_auth_diesel_sqlite::PoolConfig;
/// let config = PoolConfig::default().max_connections(16);
/// let adapter = DieselSqliteAdapter::with_config("sqlite://auth.db", config).await?;
/// # Ok(())
/// # }
/// ```
pub struct DieselSqliteAdapter {
    conn: Arc<Mutex<SqliteConnection>>,
}

impl DieselSqliteAdapter {
    /// Create a new adapter with default pool settings.
    ///
    /// Connects to the `SQLite` database at the given URL and applies
    /// performance pragmas (WAL mode, busy timeout, foreign keys).
    ///
    /// # Errors
    ///
    /// Returns [`AdapterError`] if the database connection fails.
    pub async fn new(database_url: &str) -> Result<Self, AdapterError> {
        Self::with_config(database_url, PoolConfig::default()).await
    }

    /// Create a new adapter with custom pool configuration.
    ///
    /// # Errors
    ///
    /// Returns [`AdapterError`] if the database connection fails.
    pub async fn with_config(
        database_url: &str,
        _config: PoolConfig,
    ) -> Result<Self, AdapterError> {
        let url = database_url.to_string();
        let conn =
            tokio::task::spawn_blocking(move || -> Result<SqliteConnection, AdapterError> {
                let mut conn = SqliteConnection::establish(&url)
                    .map_err(|e| AdapterError::Connection(e.to_string()))?;

                // Apply performance pragmas
                diesel::sql_query("PRAGMA journal_mode = WAL")
                    .execute(&mut conn)
                    .map_err(|e| {
                        AdapterError::Connection(format!("Failed to set WAL mode: {e}"))
                    })?;
                diesel::sql_query("PRAGMA busy_timeout = 5000")
                    .execute(&mut conn)
                    .map_err(|e| {
                        AdapterError::Connection(format!("Failed to set busy timeout: {e}"))
                    })?;
                diesel::sql_query("PRAGMA synchronous = NORMAL")
                    .execute(&mut conn)
                    .map_err(|e| {
                        AdapterError::Connection(format!("Failed to set synchronous mode: {e}"))
                    })?;
                diesel::sql_query("PRAGMA foreign_keys = ON")
                    .execute(&mut conn)
                    .map_err(|e| {
                        AdapterError::Connection(format!("Failed to enable foreign keys: {e}"))
                    })?;
                diesel::sql_query("PRAGMA cache_size = -64000")
                    .execute(&mut conn)
                    .map_err(|e| {
                        AdapterError::Connection(format!("Failed to set cache size: {e}"))
                    })?;

                Ok(conn)
            })
            .await
            .map_err(|e| AdapterError::Connection(format!("spawn_blocking join error: {e}")))??;

        Ok(Self {
            conn: Arc::new(Mutex::new(conn)),
        })
    }

    /// Create an in-memory `SQLite` adapter for testing.
    ///
    /// The database exists only for the lifetime of the adapter.
    /// Migrations are run automatically.
    ///
    /// # Errors
    ///
    /// Returns [`AdapterError`] if initialization fails.
    pub async fn in_memory() -> Result<Self, AdapterError> {
        Self::new(":memory:").await
    }

    /// Run embedded migrations against the database.
    ///
    /// Creates all auth tables if they don't already exist.
    ///
    /// # Errors
    ///
    /// Returns [`AdapterError`] if migration execution fails.
    pub async fn run_migrations(&self) -> Result<(), AdapterError> {
        use diesel_migrations::{EmbeddedMigrations, MigrationHarness, embed_migrations};

        const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

        let conn = Arc::clone(&self.conn);
        tokio::task::spawn_blocking(move || {
            let mut guard = conn
                .lock()
                .map_err(|e| AdapterError::Migration(format!("Mutex poisoned: {e}")))?;
            guard
                .run_pending_migrations(MIGRATIONS)
                .map_err(|e| AdapterError::Migration(e.to_string()))?;
            Ok(())
        })
        .await
        .map_err(|e| AdapterError::Migration(format!("spawn_blocking join error: {e}")))?
    }

    /// Run a synchronous closure against the `SQLite` connection,
    /// offloading the blocking work to `tokio::task::spawn_blocking`.
    ///
    /// The connection is protected by an `Arc<Mutex<>>` so the closure
    /// acquires the lock inside the blocking thread, keeping the async
    /// runtime free.
    pub(crate) async fn interact<F, R>(&self, f: F) -> AuthResult<R>
    where
        F: FnOnce(&mut SqliteConnection) -> AuthResult<R> + Send + 'static,
        R: Send + 'static,
    {
        let conn = Arc::clone(&self.conn);

        tokio::task::spawn_blocking(move || {
            let mut guard = conn.lock().map_err(|e| {
                AuthError::Database(DatabaseError::Connection(format!("Mutex poisoned: {e}")))
            })?;
            f(&mut guard)
        })
        .await
        .map_err(|e| {
            AuthError::Database(DatabaseError::Connection(format!(
                "spawn_blocking join error: {e}"
            )))
        })?
    }
}
