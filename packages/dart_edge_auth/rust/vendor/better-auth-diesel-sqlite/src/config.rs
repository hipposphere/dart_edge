//! Adapter configuration types.

use std::time::Duration;

/// Connection pool configuration for the `SQLite` adapter.
///
/// Controls pool sizing, timeouts, and connection lifecycle.
#[derive(Debug, Clone)]
pub struct PoolConfig {
    /// Maximum number of connections in the pool.
    pub max_connections: u32,
    /// Minimum number of idle connections to maintain.
    pub min_connections: u32,
    /// Maximum time to wait for a connection from the pool.
    pub acquire_timeout: Duration,
    /// Maximum idle time before a connection is closed.
    pub idle_timeout: Duration,
    /// Maximum lifetime of a connection.
    pub max_lifetime: Duration,
    /// Whether to run embedded migrations on adapter construction.
    pub run_migrations: bool,
}

impl Default for PoolConfig {
    fn default() -> Self {
        Self {
            max_connections: 8,
            min_connections: 1,
            acquire_timeout: Duration::from_secs(30),
            idle_timeout: Duration::from_secs(600),
            max_lifetime: Duration::from_secs(1800),
            run_migrations: true,
        }
    }
}

impl PoolConfig {
    /// Set the maximum number of connections.
    #[must_use]
    pub fn max_connections(mut self, n: u32) -> Self {
        self.max_connections = n;
        self
    }

    /// Set the minimum number of idle connections.
    #[must_use]
    pub fn min_connections(mut self, n: u32) -> Self {
        self.min_connections = n;
        self
    }

    /// Set the connection acquisition timeout.
    #[must_use]
    pub fn acquire_timeout(mut self, duration: Duration) -> Self {
        self.acquire_timeout = duration;
        self
    }

    /// Set the idle connection timeout.
    #[must_use]
    pub fn idle_timeout(mut self, duration: Duration) -> Self {
        self.idle_timeout = duration;
        self
    }

    /// Set the maximum connection lifetime.
    #[must_use]
    pub fn max_lifetime(mut self, duration: Duration) -> Self {
        self.max_lifetime = duration;
        self
    }

    /// Set whether to run migrations on construction.
    #[must_use]
    pub fn run_migrations(mut self, enabled: bool) -> Self {
        self.run_migrations = enabled;
        self
    }
}
