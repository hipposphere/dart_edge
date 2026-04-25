//! Shared SQL JSON wire contracts for Dart Edge native crates.
//!
//! The SQL native asset exposes a compact C ABI where statements and result
//! sets are passed as JSON strings. This crate defines the serializable Rust
//! payloads for that JSON contract so independent native crates can share the
//! same schema.

#![deny(missing_docs)]

mod dialect;
mod error;
mod result;
mod statement;
mod value;

/// Current JSON wire contract version for Dart Edge SQL payloads.
pub const SQL_WIRE_VERSION: u32 = 1;

pub use dialect::SqlDialect;
pub use error::{SqlErrorKind, SqlErrorPayload};
pub use result::{SqlColumn, SqlResult, SqlRow};
pub use statement::SqlStatement;
pub use value::SqlValue;
