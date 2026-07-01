use serde::{Deserialize, Serialize};

/// JSON-compatible SQL value used for both parameters and result columns.
#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(tag = "kind", content = "value", rename_all = "camelCase")]
pub enum SqlValue {
    /// SQL `NULL`.
    Null,
    /// Signed 64-bit integer.
    Integer(i64),
    /// 64-bit floating point value.
    Double(f64),
    /// Boolean value.
    Boolean(bool),
    /// UTF-8 text value.
    String(String),
    /// Lossless decimal value encoded as database decimal text.
    Decimal(String),
    /// Base64-encoded bytes.
    Bytes(String),
    /// Date/time value encoded as text, normally RFC 3339.
    DateTime(String),
    /// Arbitrary JSON value.
    Json(serde_json::Value),
    /// PostgreSQL pgvector value.
    Vector(Vec<f64>),
}
