use serde::{Deserialize, Serialize};

use crate::value::SqlValue;

/// SQL execution result payload returned by a native SQL executor.
#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SqlResult {
    /// Number of affected rows for non-query statements.
    pub affected_rows: i64,
    /// Result rows for query statements.
    #[serde(default)]
    pub rows: Vec<SqlRow>,
}

/// Single SQL result row.
#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
pub struct SqlRow {
    /// Column values in result order.
    pub values: Vec<SqlColumn>,
}

/// Single SQL result column.
#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct SqlColumn {
    /// Column name reported by the database.
    pub name: String,
    /// Column value.
    pub value: SqlValue,
}

impl SqlResult {
    /// Creates a result for a statement that affected rows and returned no row
    /// data.
    pub const fn affected_rows(affected_rows: i64) -> Self {
        Self {
            affected_rows,
            rows: Vec::new(),
        }
    }

    /// Creates a result for a query that returned rows.
    pub fn rows(rows: Vec<SqlRow>) -> Self {
        Self {
            affected_rows: 0,
            rows,
        }
    }
}

impl SqlRow {
    /// Creates a row from columns.
    pub fn new(values: Vec<SqlColumn>) -> Self {
        Self { values }
    }
}

impl SqlColumn {
    /// Creates a named result column.
    pub fn new(name: impl Into<String>, value: SqlValue) -> Self {
        Self {
            name: name.into(),
            value,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn result_deserializes_from_existing_wire_shape() {
        let result: SqlResult = serde_json::from_value(serde_json::json!({
            "affectedRows": 0,
            "rows": [
                {
                    "values": [
                        {"name": "id", "value": {"kind": "string", "value": "abc"}}
                    ]
                }
            ]
        }))
        .unwrap();

        assert_eq!(
            result,
            SqlResult::rows(vec![SqlRow::new(vec![SqlColumn::new(
                "id",
                SqlValue::String("abc".to_string()),
            )])])
        );
    }

    #[test]
    fn missing_rows_default_to_empty() {
        let result: SqlResult = serde_json::from_value(serde_json::json!({
            "affectedRows": 1
        }))
        .unwrap();

        assert!(result.rows.is_empty());
    }

    #[test]
    fn result_deserializes_vector_values() {
        let result: SqlResult = serde_json::from_value(serde_json::json!({
            "affectedRows": 0,
            "rows": [
                {
                    "values": [
                        {"name": "embedding", "value": {"kind": "vector", "value": [1.0, 2.0]}}
                    ]
                }
            ]
        }))
        .unwrap();

        assert_eq!(
            result,
            SqlResult::rows(vec![SqlRow::new(vec![SqlColumn::new(
                "embedding",
                SqlValue::Vector(vec![1.0, 2.0]),
            )])])
        );
    }

    #[test]
    fn result_deserializes_decimal_values() {
        let result: SqlResult = serde_json::from_value(serde_json::json!({
            "affectedRows": 0,
            "rows": [
                {
                    "values": [
                        {"name": "amount", "value": {"kind": "decimal", "value": "123.45"}}
                    ]
                }
            ]
        }))
        .unwrap();

        assert_eq!(
            result,
            SqlResult::rows(vec![SqlRow::new(vec![SqlColumn::new(
                "amount",
                SqlValue::Decimal("123.45".to_string()),
            )])])
        );
    }
}
