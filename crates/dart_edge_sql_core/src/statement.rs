use serde::{Deserialize, Serialize};

use crate::value::SqlValue;

/// SQL statement payload sent to a native SQL executor.
#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SqlStatement {
    /// SQL text with positional placeholders appropriate for the selected
    /// database dialect.
    pub sql: String,
    /// Positional parameter values.
    #[serde(default)]
    pub parameters: Vec<SqlValue>,
}

impl SqlStatement {
    /// Creates a statement with no parameters.
    pub fn new(sql: impl Into<String>) -> Self {
        Self {
            sql: sql.into(),
            parameters: Vec::new(),
        }
    }

    /// Creates a statement with positional parameters.
    pub fn with_parameters(sql: impl Into<String>, parameters: Vec<SqlValue>) -> Self {
        Self {
            sql: sql.into(),
            parameters,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn statement_serializes_to_expected_wire_shape() {
        let statement = SqlStatement::with_parameters(
            "select * from users where id = ?",
            vec![SqlValue::Integer(42)],
        );

        let json = serde_json::to_value(statement).unwrap();

        assert_eq!(
            json,
            serde_json::json!({
                "sql": "select * from users where id = ?",
                "parameters": [
                    {"kind": "integer", "value": 42}
                ]
            })
        );
    }

    #[test]
    fn missing_parameters_default_to_empty() {
        let statement: SqlStatement = serde_json::from_value(serde_json::json!({
            "sql": "select 1"
        }))
        .unwrap();

        assert!(statement.parameters.is_empty());
    }
}
