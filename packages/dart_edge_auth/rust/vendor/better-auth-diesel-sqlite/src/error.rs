//! Error types and conversion to `better-auth-core`'s `AuthError`.

use better_auth_core::error::{AuthError, DatabaseError};

/// Errors specific to the `Diesel` `SQLite` adapter.
#[derive(Debug, thiserror::Error)]
pub enum AdapterError {
    /// Database query or connection error from `Diesel`.
    #[error("database error: {0}")]
    Database(#[from] diesel::result::Error),

    /// Connection pool error.
    #[error("pool error: {0}")]
    Pool(String),

    /// Migration execution error.
    #[error("migration error: {0}")]
    Migration(String),

    /// Data conversion error (e.g., invalid UUID, timestamp, JSON).
    #[error("conversion error: {0}")]
    Conversion(String),

    /// Connection setup error (pragmas, initialization).
    #[error("connection error: {0}")]
    Connection(String),
}

impl From<AdapterError> for AuthError {
    fn from(err: AdapterError) -> Self {
        match err {
            AdapterError::Database(diesel_err) => {
                AuthError::Database(diesel_to_database_error(diesel_err))
            }
            AdapterError::Pool(msg) => AuthError::Database(DatabaseError::Connection(msg)),
            AdapterError::Migration(msg) => AuthError::Database(DatabaseError::Migration(msg)),
            AdapterError::Conversion(msg) => AuthError::Database(DatabaseError::Query(msg)),
            AdapterError::Connection(msg) => AuthError::Database(DatabaseError::Connection(msg)),
        }
    }
}

/// Convert a `Diesel` error into a `better-auth-core` `DatabaseError`.
///
/// This is a free function rather than a `From` impl because both types
/// are defined in external crates (orphan rule).
pub(crate) fn diesel_to_database_error(err: diesel::result::Error) -> DatabaseError {
    match err {
        diesel::result::Error::NotFound => DatabaseError::Query("Record not found".to_string()),
        diesel::result::Error::DatabaseError(
            diesel::result::DatabaseErrorKind::UniqueViolation,
            info,
        ) => DatabaseError::Constraint(info.message().to_string()),
        diesel::result::Error::DatabaseError(
            diesel::result::DatabaseErrorKind::ForeignKeyViolation,
            info,
        ) => DatabaseError::Constraint(info.message().to_string()),
        diesel::result::Error::DatabaseError(_, info) => {
            DatabaseError::Query(info.message().to_string())
        }
        diesel::result::Error::RollbackTransaction => {
            DatabaseError::Transaction("Transaction rolled back".to_string())
        }
        other => DatabaseError::Query(other.to_string()),
    }
}

/// Helper to convert a `Diesel` error directly into an `AuthError`.
pub(crate) fn diesel_to_auth_error(err: diesel::result::Error) -> AuthError {
    AuthError::Database(diesel_to_database_error(err))
}
