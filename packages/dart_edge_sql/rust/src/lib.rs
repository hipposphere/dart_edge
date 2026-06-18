use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
use dart_edge_sql_core::{SqlColumn, SqlResult, SqlRow, SqlStatement, SqlValue};
use once_cell::sync::Lazy;
use serde::Serialize;
use sqlx::pool::PoolConnection;
use sqlx::postgres::{PgPool, PgPoolOptions, PgRow};
use sqlx::sqlite::{SqlitePool, SqlitePoolOptions, SqliteRow};
use sqlx::types::chrono::{DateTime, NaiveDate, NaiveDateTime, Utc};
use sqlx::types::{Decimal, Uuid};
use sqlx::{Column, Postgres, Row, Sqlite, TypeInfo};
use tokio::runtime::{Builder, Runtime};

const DART_EDGE_SQL_NATIVE_ABI_VERSION: i32 = 1;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("Failed to create dart_edge_sql runtime")
});
static POOLS: Lazy<Mutex<HashMap<i64, NativePool>>> = Lazy::new(|| Mutex::new(HashMap::new()));
static TRANSACTIONS: Lazy<Mutex<HashMap<i64, NativeTransaction>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

#[derive(Clone)]
enum NativePool {
    Postgres(PgPool),
    Sqlite(SqlitePool),
}

enum NativeTransaction {
    Postgres(PoolConnection<Postgres>),
    Sqlite(PoolConnection<Sqlite>),
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_native_abi_version() -> i32 {
    DART_EDGE_SQL_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_open_postgres_pool(connection_string: *const c_char) -> i64 {
    open_postgres_pool(connection_string, 10)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_open_postgres_pool_with_max_sessions(
    connection_string: *const c_char,
    max_sessions: i32,
) -> i64 {
    open_postgres_pool(connection_string, max_sessions)
}

fn open_postgres_pool(connection_string: *const c_char, max_sessions: i32) -> i64 {
    let Some(connection_string) = (unsafe { read_c_string(connection_string) }) else {
        set_last_error("Missing PostgreSQL connection string.");
        return 0;
    };

    let max_sessions = normalize_max_sessions(max_sessions);
    let handle = reserve_handle();
    match RUNTIME.block_on(async {
        PgPoolOptions::new()
            .max_connections(max_sessions)
            .connect(&connection_string)
            .await
    }) {
        Ok(pool) => {
            POOLS
                .lock()
                .unwrap()
                .insert(handle, NativePool::Postgres(pool));
            clear_last_error();
            handle
        }
        Err(error) => {
            set_last_error(format!("Failed to open PostgreSQL pool: {error}"));
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_open_sqlite_pool(path: *const c_char, max_sessions: i32) -> i64 {
    let Some(path) = (unsafe { read_c_string(path) }) else {
        set_last_error("Missing SQLite database path.");
        return 0;
    };

    let max_sessions = normalize_max_sessions(max_sessions);
    let database_url = format!("sqlite://{path}");
    let handle = reserve_handle();

    match RUNTIME.block_on(async {
        SqlitePoolOptions::new()
            .max_connections(max_sessions)
            .connect(&database_url)
            .await
    }) {
        Ok(pool) => {
            POOLS
                .lock()
                .unwrap()
                .insert(handle, NativePool::Sqlite(pool));
            clear_last_error();
            handle
        }
        Err(error) => {
            set_last_error(format!("Failed to open SQLite pool: {error}"));
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_open_sqlite_in_memory_pool(max_sessions: i32) -> i64 {
    let handle = reserve_handle();
    let _ = normalize_max_sessions(max_sessions);

    match RUNTIME.block_on(async {
        SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await
    }) {
        Ok(pool) => {
            POOLS
                .lock()
                .unwrap()
                .insert(handle, NativePool::Sqlite(pool));
            clear_last_error();
            handle
        }
        Err(error) => {
            set_last_error(format!("Failed to open in-memory SQLite pool: {error}"));
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_close_pool(handle: i64) {
    let pool = POOLS.lock().unwrap().remove(&handle);
    if let Some(pool) = pool {
        RUNTIME.block_on(async move {
            match pool {
                NativePool::Postgres(pool) => pool.close().await,
                NativePool::Sqlite(pool) => pool.close().await,
            }
        });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_execute_pool(
    handle: i64,
    statement_json: *const c_char,
) -> *mut c_char {
    let Some(statement_json) = (unsafe { read_c_string(statement_json) }) else {
        set_last_error("Missing SQL statement payload.");
        return std::ptr::null_mut();
    };

    let statement = match parse_statement(&statement_json) {
        Ok(statement) => statement,
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    let result = {
        let pools = POOLS.lock().unwrap();
        match pools.get(&handle) {
            Some(NativePool::Postgres(pool)) => {
                RUNTIME.block_on(execute_postgres_pool(pool, &statement))
            }
            Some(NativePool::Sqlite(pool)) => {
                RUNTIME.block_on(execute_sqlite_pool(pool, &statement))
            }
            None => {
                set_last_error("Unknown SQL pool handle.");
                return std::ptr::null_mut();
            }
        }
    };

    encode_result(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_begin_transaction(pool_handle: i64) -> i64 {
    let handle = reserve_handle();
    let transaction = {
        let pools = POOLS.lock().unwrap();
        match pools.get(&pool_handle) {
            Some(NativePool::Postgres(pool)) => {
                match RUNTIME.block_on(begin_postgres_transaction(pool)) {
                    Ok(connection) => NativeTransaction::Postgres(connection),
                    Err(error) => {
                        set_last_error(error);
                        return 0;
                    }
                }
            }
            Some(NativePool::Sqlite(pool)) => {
                match RUNTIME.block_on(begin_sqlite_transaction(pool)) {
                    Ok(connection) => NativeTransaction::Sqlite(connection),
                    Err(error) => {
                        set_last_error(error);
                        return 0;
                    }
                }
            }
            None => {
                set_last_error("Unknown SQL pool handle.");
                return 0;
            }
        }
    };

    TRANSACTIONS.lock().unwrap().insert(handle, transaction);
    clear_last_error();
    handle
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_execute_transaction(
    handle: i64,
    statement_json: *const c_char,
) -> *mut c_char {
    let Some(statement_json) = (unsafe { read_c_string(statement_json) }) else {
        set_last_error("Missing SQL statement payload.");
        return std::ptr::null_mut();
    };

    let statement = match parse_statement(&statement_json) {
        Ok(statement) => statement,
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    let result = {
        let mut transactions = TRANSACTIONS.lock().unwrap();
        match transactions.get_mut(&handle) {
            Some(NativeTransaction::Postgres(connection)) => {
                RUNTIME.block_on(execute_postgres_connection(connection, &statement))
            }
            Some(NativeTransaction::Sqlite(connection)) => {
                RUNTIME.block_on(execute_sqlite_connection(connection, &statement))
            }
            None => Err("Unknown SQL transaction handle.".to_string()),
        }
    };

    encode_result(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_commit_transaction(handle: i64) -> bool {
    let transaction = TRANSACTIONS.lock().unwrap().remove(&handle);
    let Some(transaction) = transaction else {
        set_last_error("Unknown SQL transaction handle.");
        return false;
    };

    let result = RUNTIME.block_on(async move {
        match transaction {
            NativeTransaction::Postgres(mut connection) => sqlx::query("COMMIT")
                .execute(&mut *connection)
                .await
                .map(|_| ()),
            NativeTransaction::Sqlite(mut connection) => sqlx::query("COMMIT")
                .execute(&mut *connection)
                .await
                .map(|_| ()),
        }
    });

    match result {
        Ok(_) => {
            clear_last_error();
            true
        }
        Err(error) => {
            set_last_error(format!("Failed to commit SQL transaction: {error}"));
            false
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_rollback_transaction(handle: i64) {
    let transaction = TRANSACTIONS.lock().unwrap().remove(&handle);
    if let Some(transaction) = transaction {
        let _ = RUNTIME.block_on(async move {
            match transaction {
                NativeTransaction::Postgres(mut connection) => sqlx::query("ROLLBACK")
                    .execute(&mut *connection)
                    .await
                    .map(|_| ()),
                NativeTransaction::Sqlite(mut connection) => sqlx::query("ROLLBACK")
                    .execute(&mut *connection)
                    .await
                    .map(|_| ()),
            }
        });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_take_last_error() -> *mut c_char {
    LAST_ERROR
        .lock()
        .unwrap()
        .take()
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

fn reserve_handle() -> i64 {
    NEXT_HANDLE.fetch_add(1, Ordering::Relaxed)
}

fn normalize_max_sessions(value: i32) -> u32 {
    if value <= 0 {
        return 1;
    }
    value as u32
}

fn parse_statement(json: &str) -> Result<SqlStatement, String> {
    serde_json::from_str(json).map_err(|error| format!("Invalid SQL statement payload: {error}"))
}

fn encode_result(result: Result<SqlResult, String>) -> *mut c_char {
    match result {
        Ok(result) => match serde_json::to_string(&result) {
            Ok(json) => match CString::new(json) {
                Ok(value) => {
                    clear_last_error();
                    value.into_raw()
                }
                Err(error) => {
                    set_last_error(format!("Failed to encode SQL result: {error}"));
                    std::ptr::null_mut()
                }
            },
            Err(error) => {
                set_last_error(format!("Failed to serialize SQL result: {error}"));
                std::ptr::null_mut()
            }
        },
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

async fn begin_postgres_transaction(pool: &PgPool) -> Result<PoolConnection<Postgres>, String> {
    let mut connection = pool
        .acquire()
        .await
        .map_err(|error| format!("Failed to acquire PostgreSQL connection: {error}"))?;
    sqlx::query("BEGIN")
        .execute(&mut *connection)
        .await
        .map_err(|error| format!("Failed to start PostgreSQL transaction: {error}"))?;
    Ok(connection)
}

async fn begin_sqlite_transaction(pool: &SqlitePool) -> Result<PoolConnection<Sqlite>, String> {
    let mut connection = pool
        .acquire()
        .await
        .map_err(|error| format!("Failed to acquire SQLite connection: {error}"))?;
    sqlx::query("BEGIN")
        .execute(&mut *connection)
        .await
        .map_err(|error| format!("Failed to start SQLite transaction: {error}"))?;
    Ok(connection)
}

async fn execute_postgres_pool(
    pool: &PgPool,
    statement: &SqlStatement,
) -> Result<SqlResult, String> {
    validate_postgres_statement(statement)?;

    if statement_returns_rows(&statement.sql) {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_postgres_value(query, value);
        }
        let rows = query
            .fetch_all(pool)
            .await
            .map_err(|error| format!("Failed to execute PostgreSQL query: {error}"))?;
        Ok(SqlResult {
            affected_rows: 0,
            rows: encode_postgres_rows(rows)?,
        })
    } else {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_postgres_value(query, value);
        }
        let result = query
            .execute(pool)
            .await
            .map_err(|error| format!("Failed to execute PostgreSQL statement: {error}"))?;
        Ok(SqlResult {
            affected_rows: result.rows_affected() as i64,
            rows: Vec::new(),
        })
    }
}

async fn execute_sqlite_pool(
    pool: &SqlitePool,
    statement: &SqlStatement,
) -> Result<SqlResult, String> {
    if statement_returns_rows(&statement.sql) {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_sqlite_value(query, value);
        }
        let rows = query
            .fetch_all(pool)
            .await
            .map_err(|error| format!("Failed to execute SQLite query: {error}"))?;
        Ok(SqlResult {
            affected_rows: 0,
            rows: encode_sqlite_rows(rows)?,
        })
    } else {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_sqlite_value(query, value);
        }
        let result = query
            .execute(pool)
            .await
            .map_err(|error| format!("Failed to execute SQLite statement: {error}"))?;
        Ok(SqlResult {
            affected_rows: result.rows_affected() as i64,
            rows: Vec::new(),
        })
    }
}

async fn execute_postgres_connection(
    connection: &mut PoolConnection<Postgres>,
    statement: &SqlStatement,
) -> Result<SqlResult, String> {
    validate_postgres_statement(statement)?;

    if statement_returns_rows(&statement.sql) {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_postgres_value(query, value);
        }
        let rows = query
            .fetch_all(&mut **connection)
            .await
            .map_err(|error| format!("Failed to execute PostgreSQL query: {error}"))?;
        Ok(SqlResult {
            affected_rows: 0,
            rows: encode_postgres_rows(rows)?,
        })
    } else {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_postgres_value(query, value);
        }
        let result = query
            .execute(&mut **connection)
            .await
            .map_err(|error| format!("Failed to execute PostgreSQL statement: {error}"))?;
        Ok(SqlResult {
            affected_rows: result.rows_affected() as i64,
            rows: Vec::new(),
        })
    }
}

async fn execute_sqlite_connection(
    connection: &mut PoolConnection<Sqlite>,
    statement: &SqlStatement,
) -> Result<SqlResult, String> {
    if statement_returns_rows(&statement.sql) {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_sqlite_value(query, value);
        }
        let rows = query
            .fetch_all(&mut **connection)
            .await
            .map_err(|error| format!("Failed to execute SQLite query: {error}"))?;
        Ok(SqlResult {
            affected_rows: 0,
            rows: encode_sqlite_rows(rows)?,
        })
    } else {
        let mut query = sqlx::query(&statement.sql);
        for value in &statement.parameters {
            query = bind_sqlite_value(query, value);
        }
        let result = query
            .execute(&mut **connection)
            .await
            .map_err(|error| format!("Failed to execute SQLite statement: {error}"))?;
        Ok(SqlResult {
            affected_rows: result.rows_affected() as i64,
            rows: Vec::new(),
        })
    }
}

fn bind_postgres_value<'q>(
    query: sqlx::query::Query<'q, Postgres, sqlx::postgres::PgArguments>,
    value: &SqlValue,
) -> sqlx::query::Query<'q, Postgres, sqlx::postgres::PgArguments> {
    match value {
        SqlValue::Null => query.bind(Option::<String>::None),
        SqlValue::Integer(value) => query.bind(*value),
        SqlValue::Double(value) => query.bind(*value),
        SqlValue::Boolean(value) => query.bind(*value),
        SqlValue::String(value) => query.bind(value.clone()),
        SqlValue::Bytes(value) => query.bind(BASE64.decode(value).unwrap_or_default()),
        SqlValue::DateTime(value) => match parse_datetime_value(value) {
            Some(value) => query.bind(value),
            None => query.bind(value.clone()),
        },
        SqlValue::Json(value) => query.bind(sqlx::types::Json(value.clone())),
    }
}

fn validate_postgres_statement(statement: &SqlStatement) -> Result<(), String> {
    for (index, value) in statement.parameters.iter().enumerate() {
        validate_postgres_value(value, &format!("parameter {}", index + 1))?;
    }
    Ok(())
}

fn validate_postgres_value(value: &SqlValue, location: &str) -> Result<(), String> {
    match value {
        SqlValue::String(value) | SqlValue::DateTime(value) => {
            validate_postgres_text(value, location)
        }
        SqlValue::Json(value) => validate_postgres_json(value, location),
        _ => Ok(()),
    }
}

fn validate_postgres_json(value: &serde_json::Value, location: &str) -> Result<(), String> {
    match value {
        serde_json::Value::String(value) => validate_postgres_text(value, location),
        serde_json::Value::Array(values) => {
            for (index, value) in values.iter().enumerate() {
                validate_postgres_json(value, &format!("{location}[{index}]"))?;
            }
            Ok(())
        }
        serde_json::Value::Object(values) => {
            for (key, value) in values {
                validate_postgres_text(key, &format!("{location} key"))?;
                validate_postgres_json(value, &format!("{location}.{key}"))?;
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

fn validate_postgres_text(value: &str, location: &str) -> Result<(), String> {
    if value.contains('\0') {
        return Err(format!(
            "PostgreSQL text/json value contains NUL byte at {location}."
        ));
    }
    Ok(())
}

fn parse_datetime_value(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .map(|value| value.with_timezone(&Utc))
        .ok()
}

fn bind_sqlite_value<'q>(
    query: sqlx::query::Query<'q, Sqlite, sqlx::sqlite::SqliteArguments<'q>>,
    value: &SqlValue,
) -> sqlx::query::Query<'q, Sqlite, sqlx::sqlite::SqliteArguments<'q>> {
    match value {
        SqlValue::Null => query.bind(Option::<String>::None),
        SqlValue::Integer(value) => query.bind(*value),
        SqlValue::Double(value) => query.bind(*value),
        SqlValue::Boolean(value) => query.bind(*value),
        SqlValue::String(value) => query.bind(value.clone()),
        SqlValue::Bytes(value) => query.bind(BASE64.decode(value).unwrap_or_default()),
        SqlValue::DateTime(value) => query.bind(value.clone()),
        SqlValue::Json(value) => query.bind(serde_json::to_string(value).unwrap_or_default()),
    }
}

fn encode_postgres_rows(rows: Vec<PgRow>) -> Result<Vec<SqlRow>, String> {
    rows.into_iter().map(encode_postgres_row).collect()
}

fn encode_postgres_row(row: PgRow) -> Result<SqlRow, String> {
    let mut values = Vec::with_capacity(row.len());
    for index in 0..row.len() {
        let column = &row.columns()[index];
        let column_name = column.name();
        let type_name = column.type_info().name();
        values.push(SqlColumn {
            name: column_name.to_string(),
            value: decode_postgres_value(&row, index, column_name, type_name)?,
        });
    }
    Ok(SqlRow { values })
}

fn decode_postgres_value(
    row: &PgRow,
    index: usize,
    column_name: &str,
    type_name: &str,
) -> Result<SqlValue, String> {
    let value = match type_name {
        "BOOL" => match row.try_get::<Option<bool>, usize>(index) {
            Ok(Some(value)) => SqlValue::Boolean(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL bool: {error}")),
        },
        "INT2" => match row.try_get::<Option<i16>, usize>(index) {
            Ok(Some(value)) => SqlValue::Integer(value as i64),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL int2: {error}")),
        },
        "INT4" => match row.try_get::<Option<i32>, usize>(index) {
            Ok(Some(value)) => SqlValue::Integer(value as i64),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL int4: {error}")),
        },
        "INT8" | "OID" => match row.try_get::<Option<i64>, usize>(index) {
            Ok(Some(value)) => SqlValue::Integer(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL int8: {error}")),
        },
        "\"CHAR\"" => match row.try_get::<Option<i8>, usize>(index) {
            Ok(Some(value)) => SqlValue::String(postgres_char_to_string(value)),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL char: {error}")),
        },
        "FLOAT4" => match row.try_get::<Option<f32>, usize>(index) {
            Ok(Some(value)) => SqlValue::Double(value as f64),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL float4: {error}")),
        },
        "FLOAT8" => match row.try_get::<Option<f64>, usize>(index) {
            Ok(Some(value)) => SqlValue::Double(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL float8: {error}")),
        },
        "NUMERIC" => match row.try_get::<Option<Decimal>, usize>(index) {
            Ok(Some(value)) => SqlValue::Double(postgres_decimal_to_f64(value, "numeric")?),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL numeric: {error}")),
        },
        "MONEY" => match row.try_get::<Option<sqlx::postgres::types::PgMoney>, usize>(index) {
            Ok(Some(value)) => SqlValue::Double(postgres_money_to_f64(value)?),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL money: {error}")),
        },
        "JSON" | "JSONB" => {
            match row.try_get::<Option<sqlx::types::Json<serde_json::Value>>, usize>(index) {
                Ok(Some(value)) => SqlValue::Json(value.0),
                Ok(None) => SqlValue::Null,
                Err(error) => return Err(format!("Failed to decode PostgreSQL json: {error}")),
            }
        }
        "BYTEA" => match row.try_get::<Option<Vec<u8>>, usize>(index) {
            Ok(Some(value)) => SqlValue::Bytes(BASE64.encode(value)),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL bytea: {error}")),
        },
        "TIMESTAMPTZ" => match row.try_get::<Option<DateTime<Utc>>, usize>(index) {
            Ok(Some(value)) => SqlValue::DateTime(value.to_rfc3339()),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL timestamptz: {error}")),
        },
        "TIMESTAMP" => match row.try_get::<Option<NaiveDateTime>, usize>(index) {
            Ok(Some(value)) => SqlValue::DateTime(value.and_utc().to_rfc3339()),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL timestamp: {error}")),
        },
        "DATE" => match row.try_get::<Option<NaiveDate>, usize>(index) {
            Ok(Some(value)) => {
                let value = value
                    .and_hms_opt(0, 0, 0)
                    .ok_or_else(|| "Failed to decode PostgreSQL date.".to_string())?;
                SqlValue::DateTime(value.and_utc().to_rfc3339())
            }
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL date: {error}")),
        },
        "UUID" => match row.try_get::<Option<Uuid>, usize>(index) {
            Ok(Some(value)) => SqlValue::String(value.to_string()),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL uuid: {error}")),
        },
        "BOOL[]" => decode_postgres_array::<bool>(row, index, "bool array")?,
        "INT2[]" => decode_postgres_array::<i16>(row, index, "int2 array")?,
        "INT4[]" => decode_postgres_array::<i32>(row, index, "int4 array")?,
        "INT8[]" | "OID[]" => decode_postgres_array::<i64>(row, index, "int8 array")?,
        "\"CHAR\"[]" => match row.try_get::<Option<Vec<Option<i8>>>, usize>(index) {
            Ok(Some(value)) => SqlValue::Json(
                value
                    .into_iter()
                    .map(|value| value.map(postgres_char_to_string))
                    .collect(),
            ),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL char array: {error}")),
        },
        "FLOAT4[]" => match row.try_get::<Option<Vec<Option<f32>>>, usize>(index) {
            Ok(Some(value)) => SqlValue::Json(
                value
                    .into_iter()
                    .map(|value| value.map(f64::from))
                    .collect(),
            ),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode PostgreSQL float4 array: {error}")),
        },
        "FLOAT8[]" => decode_postgres_array::<f64>(row, index, "float8 array")?,
        "NUMERIC[]" => decode_postgres_numeric_array(row, index)?,
        "MONEY[]" => decode_postgres_money_array(row, index)?,
        "TEXT[]" | "VARCHAR[]" | "CHAR[]" | "NAME[]" => {
            decode_postgres_array::<String>(row, index, "text array")?
        }
        "UUID[]" => decode_postgres_uuid_array(row, index)?,
        "JSON[]" | "JSONB[]" => {
            match row
                .try_get::<Option<Vec<Option<sqlx::types::Json<serde_json::Value>>>>, usize>(index)
            {
                Ok(Some(value)) => SqlValue::Json(
                    value
                        .into_iter()
                        .map(|value| value.map(|json| json.0))
                        .collect(),
                ),
                Ok(None) => SqlValue::Null,
                Err(error) => {
                    return Err(format!("Failed to decode PostgreSQL json array: {error}"));
                }
            }
        }
        _ => {
            if matches!(type_name, "TIME" | "TEXT" | "VARCHAR" | "BPCHAR" | "NAME") {
                match row.try_get::<Option<String>, usize>(index) {
                    Ok(Some(value)) => SqlValue::String(value),
                    Ok(None) => SqlValue::Null,
                    Err(_) => fallback_postgres_value(row, index, column_name, type_name)?,
                }
            } else {
                fallback_postgres_value(row, index, column_name, type_name)?
            }
        }
    };

    Ok(value)
}

fn decode_postgres_numeric_array(row: &PgRow, index: usize) -> Result<SqlValue, String> {
    match row.try_get::<Option<Vec<Option<Decimal>>>, usize>(index) {
        Ok(Some(value)) => Ok(SqlValue::Json(
            value
                .into_iter()
                .map(|value| {
                    value
                        .map(|value| postgres_decimal_to_f64(value, "numeric array"))
                        .transpose()
                })
                .collect::<Result<Vec<_>, _>>()?
                .into(),
        )),
        Ok(None) => Ok(SqlValue::Null),
        Err(error) => Err(format!(
            "Failed to decode PostgreSQL numeric array: {error}"
        )),
    }
}

fn decode_postgres_money_array(row: &PgRow, index: usize) -> Result<SqlValue, String> {
    match row.try_get::<Option<Vec<Option<sqlx::postgres::types::PgMoney>>>, usize>(index) {
        Ok(Some(value)) => Ok(SqlValue::Json(
            value
                .into_iter()
                .map(|value| value.map(postgres_money_to_f64).transpose())
                .collect::<Result<Vec<_>, _>>()?
                .into(),
        )),
        Ok(None) => Ok(SqlValue::Null),
        Err(error) => Err(format!("Failed to decode PostgreSQL money array: {error}")),
    }
}

fn decode_postgres_uuid_array(row: &PgRow, index: usize) -> Result<SqlValue, String> {
    match row.try_get::<Option<Vec<Option<Uuid>>>, usize>(index) {
        Ok(Some(value)) => Ok(SqlValue::Json(
            value
                .into_iter()
                .map(|value| value.map(|uuid| uuid.to_string()))
                .collect(),
        )),
        Ok(None) => Ok(SqlValue::Null),
        Err(error) => Err(format!("Failed to decode PostgreSQL uuid array: {error}")),
    }
}

fn decode_postgres_array<T>(row: &PgRow, index: usize, label: &str) -> Result<SqlValue, String>
where
    T: for<'r> sqlx::Decode<'r, Postgres> + sqlx::Type<Postgres> + Serialize,
    Option<T>: sqlx::postgres::PgHasArrayType,
{
    match row.try_get::<Option<Vec<Option<T>>>, usize>(index) {
        Ok(Some(value)) => Ok(SqlValue::Json(
            serde_json::to_value(value)
                .map_err(|error| format!("Failed to encode PostgreSQL {label}: {error}"))?,
        )),
        Ok(None) => Ok(SqlValue::Null),
        Err(error) => Err(format!("Failed to decode PostgreSQL {label}: {error}")),
    }
}

fn postgres_char_to_string(value: i8) -> String {
    if value == 0 {
        String::new()
    } else {
        char::from(value as u8).to_string()
    }
}

fn postgres_decimal_to_f64(value: Decimal, label: &str) -> Result<f64, String> {
    let value = value
        .to_string()
        .parse::<f64>()
        .map_err(|error| format!("Failed to convert PostgreSQL {label} to double: {error}"))?;
    if !value.is_finite() {
        return Err(format!(
            "Failed to convert PostgreSQL {label} to double: value is not finite."
        ));
    }
    Ok(value)
}

fn postgres_money_to_f64(value: sqlx::postgres::types::PgMoney) -> Result<f64, String> {
    postgres_decimal_to_f64(value.to_decimal(2), "money")
}

fn fallback_postgres_value(
    row: &PgRow,
    index: usize,
    column_name: &str,
    type_name: &str,
) -> Result<SqlValue, String> {
    if let Ok(value) = row.try_get::<Option<String>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::String));
    }
    if let Ok(value) = row.try_get::<Option<i64>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::Integer));
    }
    if let Ok(value) = row.try_get::<Option<f64>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::Double));
    }
    if let Ok(value) = row.try_get::<Option<bool>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::Boolean));
    }
    if let Ok(value) = row.try_get::<Option<Vec<u8>>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, |bytes| {
            SqlValue::Bytes(BASE64.encode(bytes))
        }));
    }

    Err(format!(
        "Unsupported PostgreSQL column type in SQL result: column \"{column_name}\" at index {index} has type {type_name}."
    ))
}

fn encode_sqlite_rows(rows: Vec<SqliteRow>) -> Result<Vec<SqlRow>, String> {
    rows.into_iter().map(encode_sqlite_row).collect()
}

fn encode_sqlite_row(row: SqliteRow) -> Result<SqlRow, String> {
    let mut values = Vec::with_capacity(row.len());
    for index in 0..row.len() {
        let column = &row.columns()[index];
        values.push(SqlColumn {
            name: column.name().to_string(),
            value: decode_sqlite_value(&row, index, column.type_info().name())?,
        });
    }
    Ok(SqlRow { values })
}

fn decode_sqlite_value(row: &SqliteRow, index: usize, type_name: &str) -> Result<SqlValue, String> {
    let value = match type_name {
        "NULL" => fallback_sqlite_value(row, index)?,
        "BOOLEAN" => match row.try_get::<Option<bool>, usize>(index) {
            Ok(Some(value)) => SqlValue::Boolean(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode SQLite boolean: {error}")),
        },
        "INTEGER" => match row.try_get::<Option<i64>, usize>(index) {
            Ok(Some(value)) => SqlValue::Integer(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode SQLite integer: {error}")),
        },
        "REAL" => match row.try_get::<Option<f64>, usize>(index) {
            Ok(Some(value)) => SqlValue::Double(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode SQLite real: {error}")),
        },
        "TEXT" => match row.try_get::<Option<String>, usize>(index) {
            Ok(Some(value)) => SqlValue::String(value),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode SQLite text: {error}")),
        },
        "BLOB" => match row.try_get::<Option<Vec<u8>>, usize>(index) {
            Ok(Some(value)) => SqlValue::Bytes(BASE64.encode(value)),
            Ok(None) => SqlValue::Null,
            Err(error) => return Err(format!("Failed to decode SQLite blob: {error}")),
        },
        _ => fallback_sqlite_value(row, index)?,
    };

    Ok(value)
}

fn fallback_sqlite_value(row: &SqliteRow, index: usize) -> Result<SqlValue, String> {
    if let Ok(value) = row.try_get::<Option<i64>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::Integer));
    }
    if let Ok(value) = row.try_get::<Option<f64>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::Double));
    }
    if let Ok(value) = row.try_get::<Option<String>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::String));
    }
    if let Ok(value) = row.try_get::<Option<Vec<u8>>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, |bytes| {
            SqlValue::Bytes(BASE64.encode(bytes))
        }));
    }
    if let Ok(value) = row.try_get::<Option<bool>, usize>(index) {
        return Ok(value.map_or(SqlValue::Null, SqlValue::Boolean));
    }

    Err("Unsupported SQLite column type in SQL result.".to_string())
}

fn statement_returns_rows(sql: &str) -> bool {
    let normalized = sql.trim_start().to_ascii_lowercase();
    normalized.starts_with("select")
        || normalized.starts_with("with")
        || normalized.starts_with("pragma")
        || normalized.starts_with("show")
        || normalized.starts_with("explain")
        || normalized.contains(" returning ")
}

unsafe fn read_c_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }

    unsafe { CStr::from_ptr(value) }
        .to_str()
        .ok()
        .map(ToOwned::to_owned)
}

fn set_last_error(message: impl ToString) {
    *LAST_ERROR.lock().unwrap() = CString::new(message.to_string()).ok();
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_rfc3339_datetime_values_for_postgres_binding() {
        let value =
            parse_datetime_value("2026-05-07T10:11:12.123456Z").expect("valid RFC 3339 timestamp");

        assert_eq!(value.to_rfc3339(), "2026-05-07T10:11:12.123456+00:00");
    }

    #[test]
    fn rejects_malformed_datetime_values() {
        assert!(parse_datetime_value("not-a-date").is_none());
    }

    #[test]
    fn rejects_postgres_text_parameters_with_nul_bytes() {
        let statement = SqlStatement::with_parameters(
            "INSERT INTO calls (caller_number) VALUES ($1)",
            vec![SqlValue::String("123\0".to_string())],
        );

        let error = validate_postgres_statement(&statement).expect_err("NUL byte rejected");

        assert_eq!(
            error,
            "PostgreSQL text/json value contains NUL byte at parameter 1."
        );
    }

    #[test]
    fn rejects_nested_postgres_json_strings_with_nul_bytes() {
        let statement = SqlStatement::with_parameters(
            "INSERT INTO calls (metadata) VALUES ($1::jsonb)",
            vec![SqlValue::Json(serde_json::json!({
                "from_uri": "sip:1000\0@pbx.example.com",
            }))],
        );

        let error = validate_postgres_statement(&statement).expect_err("NUL byte rejected");

        assert_eq!(
            error,
            "PostgreSQL text/json value contains NUL byte at parameter 1.from_uri."
        );
    }

    #[test]
    fn allows_postgres_byte_parameters_with_nul_bytes() {
        let statement = SqlStatement::with_parameters(
            "INSERT INTO blobs (payload) VALUES ($1)",
            vec![SqlValue::Bytes(BASE64.encode([0, 1, 2]))],
        );

        validate_postgres_statement(&statement).expect("bytes are not text");
    }

    #[test]
    fn converts_postgres_decimal_values_to_finite_doubles() {
        let value = "12345.6789".parse::<Decimal>().expect("valid decimal");

        assert_eq!(
            postgres_decimal_to_f64(value, "numeric").expect("finite double"),
            12345.6789
        );
    }
}
