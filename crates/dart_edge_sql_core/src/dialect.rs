use serde::{Deserialize, Serialize};

/// SQL dialects supported by Dart Edge native SQL bridges.
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum SqlDialect {
    /// PostgreSQL.
    Postgres,
    /// SQLite.
    Sqlite,
}

impl SqlDialect {
    /// Decodes the stable native dialect code used by Dart FFI callbacks.
    pub const fn from_native_code(value: i32) -> Option<Self> {
        match value {
            0 => Some(Self::Postgres),
            1 => Some(Self::Sqlite),
            _ => None,
        }
    }

    /// Returns the stable native dialect code used by Dart FFI callbacks.
    pub const fn native_code(self) -> i32 {
        match self {
            Self::Postgres => 0,
            Self::Sqlite => 1,
        }
    }

    /// Returns a positional placeholder for a one-based parameter index.
    pub fn placeholder(self, index: usize) -> String {
        match self {
            Self::Postgres => format!("${index}"),
            Self::Sqlite => "?".to_string(),
        }
    }

    /// Returns the dialect-specific SQL boolean literal.
    pub const fn bool_literal(self, value: bool) -> &'static str {
        match (self, value) {
            (Self::Postgres, true) => "TRUE",
            (Self::Postgres, false) => "FALSE",
            (Self::Sqlite, true) => "1",
            (Self::Sqlite, false) => "0",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dialect_codes_are_stable() {
        assert_eq!(SqlDialect::from_native_code(0), Some(SqlDialect::Postgres));
        assert_eq!(SqlDialect::from_native_code(1), Some(SqlDialect::Sqlite));
        assert_eq!(SqlDialect::Postgres.native_code(), 0);
        assert_eq!(SqlDialect::Sqlite.native_code(), 1);
    }

    #[test]
    fn placeholders_match_dialects() {
        assert_eq!(SqlDialect::Postgres.placeholder(2), "$2");
        assert_eq!(SqlDialect::Sqlite.placeholder(2), "?");
    }
}
