use serde::{Deserialize, Serialize};

/// Stable SQL error categories for JSON error payloads.
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum SqlErrorKind {
    /// Unclassified database or driver error.
    Query,
    /// Schema or migration-related error.
    Migration,
    /// Constraint violation, such as a unique key conflict.
    Constraint,
    /// Connection or pool acquisition error.
    Connection,
    /// Invalid statement or parameter payload.
    InvalidRequest,
    /// Internal native bridge failure.
    Internal,
}

/// Structured SQL error payload for native SQL bridges.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SqlErrorPayload {
    /// Error category.
    pub kind: SqlErrorKind,
    /// Stable machine-readable code.
    pub code: String,
    /// Human-readable diagnostic message.
    pub message: String,
}

impl SqlErrorPayload {
    /// Creates a structured SQL error payload.
    pub fn new(kind: SqlErrorKind, code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            kind,
            code: code.into(),
            message: message.into(),
        }
    }

    /// Creates a generic query error payload.
    pub fn query(message: impl Into<String>) -> Self {
        Self::new(SqlErrorKind::Query, "query", message)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_payload_uses_camel_case_kind() {
        let payload = SqlErrorPayload::new(
            SqlErrorKind::InvalidRequest,
            "invalidPayload",
            "Invalid SQL payload.",
        );

        let json = serde_json::to_value(payload).unwrap();

        assert_eq!(
            json,
            serde_json::json!({
                "kind": "invalidRequest",
                "code": "invalidPayload",
                "message": "Invalid SQL payload."
            })
        );
    }
}
