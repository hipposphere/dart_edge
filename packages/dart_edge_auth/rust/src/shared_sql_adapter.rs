use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};

use async_trait::async_trait;
use better_auth::types_mod::types_org::{Member, Organization};
use better_auth::types_mod::{
    ApiKey, ApiKeyOps, CreateApiKey, CreateTwoFactor, ListUsersParams, TwoFactorOps, UpdateAccount,
    UpdateApiKey,
};
use better_auth::{
    Account, AccountOps, AuthError, AuthResult, CreateAccount, CreateInvitation, CreateMember,
    CreateOrganization, CreatePasskey, CreateSession, CreateUser, CreateVerification,
    DatabaseError, Invitation, InvitationOps, InvitationStatus, MemberOps, OrganizationOps,
    Passkey, PasskeyOps, Session, SessionOps, TwoFactor, UpdateOrganization, UpdateUser, User,
    UserOps, Verification, VerificationOps,
};
use chrono::{DateTime, Utc};
use dart_edge_sql_core::{SqlResult, SqlRow, SqlStatement, SqlValue};
use serde_json::{Value, json};
use uuid::Uuid;

const SQLITE_SCHEMA_SQL: &str = include_str!(
    "../vendor/better-auth-diesel-sqlite/migrations/00000000000000_create_auth_tables/up.sql"
);

const POSTGRES_SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS "users" (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT,
    email TEXT NOT NULL UNIQUE,
    username TEXT UNIQUE,
    display_username TEXT,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    image TEXT,
    role TEXT NOT NULL DEFAULT 'user',
    banned BOOLEAN NOT NULL DEFAULT FALSE,
    ban_reason TEXT,
    ban_expires TEXT,
    two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    metadata JSONB,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON "users" (email);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON "users" (username);

CREATE TABLE IF NOT EXISTS "sessions" (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL REFERENCES "users" (id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    ip_address TEXT,
    user_agent TEXT,
    expires_at TEXT NOT NULL,
    active_organization_id TEXT,
    impersonated_by TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_token ON "sessions" (token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON "sessions" (user_id);

CREATE TABLE IF NOT EXISTS "accounts" (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL REFERENCES "users" (id) ON DELETE CASCADE,
    account_id TEXT NOT NULL,
    provider_id TEXT NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    id_token TEXT,
    access_token_expires_at TEXT,
    refresh_token_expires_at TEXT,
    scope TEXT,
    password TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON "accounts" (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_provider ON "accounts" (provider_id, account_id);

CREATE TABLE IF NOT EXISTS "verifications" (
    id TEXT PRIMARY KEY NOT NULL,
    identifier TEXT NOT NULL,
    value TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_verifications_identifier ON "verifications" (identifier);
CREATE INDEX IF NOT EXISTS idx_verifications_value ON "verifications" (value);

CREATE TABLE IF NOT EXISTS "organization" (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    logo TEXT,
    metadata JSONB,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_slug ON "organization" (slug);

CREATE TABLE IF NOT EXISTS "member" (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL REFERENCES "users" (id) ON DELETE CASCADE,
    organization_id TEXT NOT NULL REFERENCES "organization" (id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_member_user_id ON "member" (user_id);
CREATE INDEX IF NOT EXISTS idx_member_org_id ON "member" (organization_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_member_user_org ON "member" (user_id, organization_id);

CREATE TABLE IF NOT EXISTS "invitation" (
    id TEXT PRIMARY KEY NOT NULL,
    organization_id TEXT NOT NULL REFERENCES "organization" (id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    status TEXT NOT NULL DEFAULT 'pending',
    inviter_id TEXT NOT NULL REFERENCES "users" (id),
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_invitation_org_id ON "invitation" (organization_id);
CREATE INDEX IF NOT EXISTS idx_invitation_email ON "invitation" (email);

CREATE TABLE IF NOT EXISTS "two_factor" (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL UNIQUE REFERENCES "users" (id) ON DELETE CASCADE,
    secret TEXT NOT NULL,
    backup_codes TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_two_factor_user_id ON "two_factor" (user_id);

CREATE TABLE IF NOT EXISTS "api_keys" (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL REFERENCES "users" (id) ON DELETE CASCADE,
    name TEXT,
    start TEXT,
    prefix TEXT,
    "key" TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    rate_limit_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    rate_limit_time_window BIGINT,
    rate_limit_max BIGINT,
    request_count BIGINT,
    remaining BIGINT,
    refill_interval BIGINT,
    refill_amount BIGINT,
    last_refill_at TEXT,
    last_request TEXT,
    expires_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    permissions TEXT,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON "api_keys" (user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON "api_keys" ("key");

CREATE TABLE IF NOT EXISTS "passkeys" (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL REFERENCES "users" (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    counter BIGINT NOT NULL DEFAULT 0,
    device_type TEXT NOT NULL DEFAULT '',
    backed_up BOOLEAN NOT NULL DEFAULT FALSE,
    transports TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_passkeys_user_id ON "passkeys" (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_passkeys_credential_id ON "passkeys" (credential_id);
"#;

const AUTH_TABLE_NAMES: &[&str] = &[
    "users",
    "sessions",
    "accounts",
    "verifications",
    "organization",
    "member",
    "invitation",
    "two_factor",
    "api_keys",
    "passkeys",
];

pub use dart_edge_sql_core::SqlDialect as SharedSqlDialect;

#[derive(Clone, Copy)]
pub struct SharedSqlCallbacks {
    pub database_handle: i64,
    pub execute_pool:
        unsafe extern "C" fn(handle: i64, statement_json: *const c_char) -> *mut c_char,
    pub take_last_error: unsafe extern "C" fn() -> *mut c_char,
    pub free_string: unsafe extern "C" fn(value: *mut c_char),
}

#[derive(Clone)]
pub struct SharedSqlDatabaseAdapter {
    dialect: SharedSqlDialect,
    callbacks: SharedSqlCallbacks,
    schema: Option<String>,
}

type RowMap = HashMap<String, SqlValue>;

#[derive(Clone, Debug)]
enum SqlParam {
    Null,
    Integer(i64),
    Boolean(bool),
    String(String),
    Json(Value),
}

struct RowReader<'a> {
    values: &'a RowMap,
}

impl SharedSqlDatabaseAdapter {
    pub fn new(
        dialect: SharedSqlDialect,
        callbacks: SharedSqlCallbacks,
        schema: Option<String>,
    ) -> Self {
        Self {
            dialect,
            callbacks,
            schema,
        }
    }

    pub fn run_migrations(&self) -> Result<(), DatabaseError> {
        if self.dialect == SharedSqlDialect::Sqlite && self.schema.is_some() {
            return Err(DatabaseError::Migration(
                "SQLite auth databases do not support schema-qualified tables.".to_string(),
            ));
        }

        let schema_sql = match self.dialect {
            SharedSqlDialect::Postgres => self.postgres_schema_sql(),
            SharedSqlDialect::Sqlite => SQLITE_SCHEMA_SQL.to_string(),
        };

        for statement in schema_sql
            .split(';')
            .map(str::trim)
            .filter(|statement| !statement.is_empty())
        {
            self.execute_statement(statement.to_string(), Vec::new())
                .map_err(|error| DatabaseError::Migration(error.to_string()))?;
        }

        Ok(())
    }

    fn table(&self, name: &str) -> String {
        match &self.schema {
            Some(schema) => format!("{}.{}", quoted(schema), quoted(name)),
            None => quoted(name),
        }
    }

    fn postgres_schema_sql(&self) -> String {
        let Some(schema) = &self.schema else {
            return POSTGRES_SCHEMA_SQL.to_string();
        };

        let mut sql = format!("CREATE SCHEMA IF NOT EXISTS {};\n", quoted(schema));
        sql.push_str(POSTGRES_SCHEMA_SQL);
        for table in AUTH_TABLE_NAMES {
            sql = sql.replace(&quoted(table), &self.table(table));
        }
        sql
    }

    fn execute_statement(&self, sql: String, params: Vec<SqlParam>) -> AuthResult<SqlResult> {
        let statement = SqlStatement {
            sql,
            parameters: params
                .into_iter()
                .map(SqlParam::into_native_value)
                .collect(),
        };
        let statement_json = serde_json::to_string(&statement)
            .map_err(|error| AuthError::internal(error.to_string()))?;
        let statement_json =
            CString::new(statement_json).map_err(|error| AuthError::internal(error.to_string()))?;

        let result_ptr = unsafe {
            (self.callbacks.execute_pool)(self.callbacks.database_handle, statement_json.as_ptr())
        };
        if result_ptr.is_null() {
            return Err(AuthError::Database(classify_sql_error(
                self.take_last_error_string(),
            )));
        }

        let json = unsafe { CStr::from_ptr(result_ptr) }
            .to_string_lossy()
            .into_owned();
        unsafe {
            (self.callbacks.free_string)(result_ptr);
        }

        serde_json::from_str::<SqlResult>(&json)
            .map_err(|error| AuthError::internal(error.to_string()))
    }

    fn take_last_error_string(&self) -> String {
        let error_ptr = unsafe { (self.callbacks.take_last_error)() };
        if error_ptr.is_null() {
            return "Shared dart_edge_sql call failed.".to_string();
        }

        let message = unsafe { CStr::from_ptr(error_ptr) }
            .to_string_lossy()
            .into_owned();
        unsafe {
            (self.callbacks.free_string)(error_ptr);
        }
        if message.is_empty() {
            "Shared dart_edge_sql call failed.".to_string()
        } else {
            message
        }
    }

    fn execute_affected(&self, sql: String, params: Vec<SqlParam>) -> AuthResult<usize> {
        self.execute_statement(sql, params)
            .map(|result| result.affected_rows.max(0) as usize)
    }

    fn fetch_optional_row(&self, sql: String, params: Vec<SqlParam>) -> AuthResult<Option<RowMap>> {
        let result = self.execute_statement(sql, params)?;
        Ok(result.rows.into_iter().next().map(row_payload_to_map))
    }

    fn fetch_one_row(&self, sql: String, params: Vec<SqlParam>) -> AuthResult<RowMap> {
        self.fetch_optional_row(sql, params)?
            .ok_or_else(|| AuthError::not_found("Database row not found"))
    }

    fn fetch_all_rows(&self, sql: String, params: Vec<SqlParam>) -> AuthResult<Vec<RowMap>> {
        let result = self.execute_statement(sql, params)?;
        Ok(result.rows.into_iter().map(row_payload_to_map).collect())
    }

    fn placeholder(&self, index: usize) -> String {
        self.dialect.placeholder(index)
    }

    fn placeholders(&self, start: usize, count: usize) -> Vec<String> {
        (start..start + count)
            .map(|index| self.placeholder(index))
            .collect()
    }

    fn lower_like_expression(&self, column: &str, index: usize) -> String {
        format!(
            "LOWER({column}) LIKE LOWER({placeholder}) ESCAPE '\\\\'",
            placeholder = self.placeholder(index),
        )
    }
}

impl SqlParam {
    fn into_native_value(self) -> SqlValue {
        match self {
            Self::Null => SqlValue::Null,
            Self::Integer(value) => SqlValue::Integer(value),
            Self::Boolean(value) => SqlValue::Boolean(value),
            Self::String(value) => SqlValue::String(value),
            Self::Json(value) => SqlValue::Json(value),
        }
    }
}

impl<'a> RowReader<'a> {
    fn new(values: &'a RowMap) -> Self {
        Self { values }
    }

    fn value(&self, name: &str) -> AuthResult<&SqlValue> {
        self.values.get(name).ok_or_else(|| {
            AuthError::internal(format!("Missing SQL column \"{name}\" in auth result"))
        })
    }

    fn string(&self, name: &str) -> AuthResult<String> {
        match self.value(name)? {
            SqlValue::String(value) | SqlValue::DateTime(value) | SqlValue::Bytes(value) => {
                Ok(value.clone())
            }
            SqlValue::Integer(value) => Ok(value.to_string()),
            SqlValue::Double(value) => Ok(value.to_string()),
            SqlValue::Boolean(value) => Ok(value.to_string()),
            SqlValue::Json(value) => Ok(value.to_string()),
            SqlValue::Null => Err(AuthError::internal(format!(
                "Column \"{name}\" was unexpectedly null"
            ))),
        }
    }

    fn opt_string(&self, name: &str) -> AuthResult<Option<String>> {
        Ok(match self.values.get(name) {
            None | Some(SqlValue::Null) => None,
            Some(_) => Some(self.string(name)?),
        })
    }

    fn boolean(&self, name: &str) -> AuthResult<bool> {
        match self.value(name)? {
            SqlValue::Boolean(value) => Ok(*value),
            SqlValue::Integer(value) => Ok(*value != 0),
            SqlValue::String(value) | SqlValue::DateTime(value) => match value.as_str() {
                "true" | "TRUE" | "1" => Ok(true),
                "false" | "FALSE" | "0" => Ok(false),
                _ => Err(AuthError::internal(format!(
                    "Column \"{name}\" could not be read as a boolean"
                ))),
            },
            _ => Err(AuthError::internal(format!(
                "Column \"{name}\" could not be read as a boolean"
            ))),
        }
    }

    fn integer(&self, name: &str) -> AuthResult<i64> {
        match self.value(name)? {
            SqlValue::Integer(value) => Ok(*value),
            SqlValue::Boolean(value) => Ok(if *value { 1 } else { 0 }),
            SqlValue::String(value) | SqlValue::DateTime(value) => value
                .parse::<i64>()
                .map_err(|error| AuthError::internal(error.to_string())),
            _ => Err(AuthError::internal(format!(
                "Column \"{name}\" could not be read as an integer"
            ))),
        }
    }

    fn datetime(&self, name: &str) -> AuthResult<DateTime<Utc>> {
        let text = self.string(name)?;
        DateTime::parse_from_rfc3339(&text)
            .map(|value| value.with_timezone(&Utc))
            .map_err(|error| AuthError::internal(error.to_string()))
    }

    fn opt_datetime(&self, name: &str) -> AuthResult<Option<DateTime<Utc>>> {
        Ok(match self.values.get(name) {
            None | Some(SqlValue::Null) => None,
            Some(_) => Some(self.datetime(name)?),
        })
    }

    fn json_or_default(&self, name: &str) -> AuthResult<Value> {
        Ok(self.opt_json(name)?.unwrap_or_else(|| json!({})))
    }

    fn opt_json(&self, name: &str) -> AuthResult<Option<Value>> {
        Ok(match self.values.get(name) {
            None | Some(SqlValue::Null) => None,
            Some(SqlValue::Json(value)) => Some(value.clone()),
            Some(SqlValue::String(value)) | Some(SqlValue::DateTime(value)) => {
                Some(serde_json::from_str(value).unwrap_or_else(|_| Value::String(value.clone())))
            }
            Some(_) => {
                return Err(AuthError::internal(format!(
                    "Column \"{name}\" could not be read as JSON"
                )));
            }
        })
    }
}

fn row_payload_to_map(row: SqlRow) -> RowMap {
    row.values
        .into_iter()
        .map(|column| (column.name, column.value))
        .collect()
}

fn classify_sql_error(message: String) -> DatabaseError {
    let lowered = message.to_lowercase();
    if lowered.contains("unique constraint")
        || lowered.contains("duplicate key")
        || lowered.contains("violates unique constraint")
    {
        DatabaseError::Constraint(message)
    } else if lowered.contains("no such table")
        || lowered.contains("relation")
        || lowered.contains("does not exist")
    {
        DatabaseError::Migration(message)
    } else {
        DatabaseError::Query(message)
    }
}

fn quoted(identifier: &str) -> String {
    format!("\"{}\"", identifier.replace('"', "\"\""))
}

fn now_text() -> String {
    Utc::now().to_rfc3339()
}

fn escape_like(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('%', "\\%")
        .replace('_', "\\_")
}

fn decode_user(row: RowMap) -> AuthResult<User> {
    let row = RowReader::new(&row);
    Ok(User {
        id: row.string("id")?,
        name: row.opt_string("name")?,
        email: row.opt_string("email")?,
        email_verified: row.boolean("email_verified")?,
        image: row.opt_string("image")?,
        created_at: row.datetime("created_at")?,
        updated_at: row.datetime("updated_at")?,
        username: row.opt_string("username")?,
        display_username: row.opt_string("display_username")?,
        two_factor_enabled: row.boolean("two_factor_enabled")?,
        role: row.opt_string("role")?,
        banned: row.boolean("banned")?,
        ban_reason: row.opt_string("ban_reason")?,
        ban_expires: row.opt_datetime("ban_expires")?,
        metadata: row.json_or_default("metadata")?,
    })
}

fn decode_session(row: RowMap) -> AuthResult<Session> {
    let row = RowReader::new(&row);
    Ok(Session {
        id: row.string("id")?,
        expires_at: row.datetime("expires_at")?,
        token: row.string("token")?,
        created_at: row.datetime("created_at")?,
        updated_at: row.datetime("updated_at")?,
        ip_address: row.opt_string("ip_address")?,
        user_agent: row.opt_string("user_agent")?,
        user_id: row.string("user_id")?,
        impersonated_by: row.opt_string("impersonated_by")?,
        active_organization_id: row.opt_string("active_organization_id")?,
        active: row.boolean("active")?,
    })
}

fn decode_account(row: RowMap) -> AuthResult<Account> {
    let row = RowReader::new(&row);
    Ok(Account {
        id: row.string("id")?,
        account_id: row.string("account_id")?,
        provider_id: row.string("provider_id")?,
        user_id: row.string("user_id")?,
        access_token: row.opt_string("access_token")?,
        refresh_token: row.opt_string("refresh_token")?,
        id_token: row.opt_string("id_token")?,
        access_token_expires_at: row.opt_datetime("access_token_expires_at")?,
        refresh_token_expires_at: row.opt_datetime("refresh_token_expires_at")?,
        scope: row.opt_string("scope")?,
        password: row.opt_string("password")?,
        created_at: row.datetime("created_at")?,
        updated_at: row.datetime("updated_at")?,
    })
}

fn decode_verification(row: RowMap) -> AuthResult<Verification> {
    let row = RowReader::new(&row);
    Ok(Verification {
        id: row.string("id")?,
        identifier: row.string("identifier")?,
        value: row.string("value")?,
        expires_at: row.datetime("expires_at")?,
        created_at: row.datetime("created_at")?,
        updated_at: row.datetime("updated_at")?,
    })
}

#[async_trait]
impl UserOps for SharedSqlDatabaseAdapter {
    type User = User;

    async fn create_user(&self, create_user: CreateUser) -> AuthResult<User> {
        let id = create_user.id.unwrap_or_else(|| Uuid::new_v4().to_string());
        let now = now_text();
        let placeholders = self.placeholders(1, 11);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {email_col}, {name_col}, {image_col}, {verified_col}, \
             {username_col}, {display_username_col}, {role_col}, {created_at_col}, {updated_at_col}, {metadata_col}) \
             VALUES ({values}) RETURNING *",
            table = self.table("users"),
            id_col = quoted("id"),
            email_col = quoted("email"),
            name_col = quoted("name"),
            image_col = quoted("image"),
            verified_col = quoted("email_verified"),
            username_col = quoted("username"),
            display_username_col = quoted("display_username"),
            role_col = quoted("role"),
            created_at_col = quoted("created_at"),
            updated_at_col = quoted("updated_at"),
            metadata_col = quoted("metadata"),
            values = placeholders.join(", "),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id),
                match create_user.email {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match create_user.name {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match create_user.image {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                SqlParam::Boolean(create_user.email_verified.unwrap_or(false)),
                match create_user.username {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match create_user.display_username {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                SqlParam::String(create_user.role.unwrap_or_else(|| "user".to_string())),
                SqlParam::String(now.clone()),
                SqlParam::String(now),
                SqlParam::Json(create_user.metadata.unwrap_or_else(|| json!({}))),
            ],
        )?;
        decode_user(row)
    }

    async fn get_user_by_id(&self, id: &str) -> AuthResult<Option<User>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {id_col} = {placeholder}",
            table = self.table("users"),
            id_col = quoted("id"),
            placeholder = self.placeholder(1),
        );
        self.fetch_optional_row(sql, vec![SqlParam::String(id.to_string())])?
            .map(decode_user)
            .transpose()
    }

    async fn get_user_by_email(&self, email: &str) -> AuthResult<Option<User>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {email_col} = {placeholder}",
            table = self.table("users"),
            email_col = quoted("email"),
            placeholder = self.placeholder(1),
        );
        self.fetch_optional_row(sql, vec![SqlParam::String(email.to_string())])?
            .map(decode_user)
            .transpose()
    }

    async fn get_user_by_username(&self, username: &str) -> AuthResult<Option<User>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {username_col} = {placeholder}",
            table = self.table("users"),
            username_col = quoted("username"),
            placeholder = self.placeholder(1),
        );
        self.fetch_optional_row(sql, vec![SqlParam::String(username.to_string())])?
            .map(decode_user)
            .transpose()
    }

    async fn update_user(&self, id: &str, update: UpdateUser) -> AuthResult<User> {
        let mut sets = vec![format!(
            "{} = {}",
            quoted("updated_at"),
            self.placeholder(1)
        )];
        let mut params = vec![SqlParam::String(now_text())];

        let mut push_update = |column: &str, value: SqlParam| {
            params.push(value);
            sets.push(format!(
                "{} = {}",
                quoted(column),
                self.placeholder(params.len()),
            ));
        };

        if let Some(value) = update.email {
            push_update("email", SqlParam::String(value));
        }
        if let Some(value) = update.name {
            push_update("name", SqlParam::String(value));
        }
        if let Some(value) = update.image {
            push_update("image", SqlParam::String(value));
        }
        if let Some(value) = update.email_verified {
            push_update("email_verified", SqlParam::Boolean(value));
        }
        if let Some(value) = update.username {
            push_update("username", SqlParam::String(value));
        }
        if let Some(value) = update.display_username {
            push_update("display_username", SqlParam::String(value));
        }
        if let Some(value) = update.role {
            push_update("role", SqlParam::String(value));
        }
        if let Some(value) = update.banned {
            push_update("banned", SqlParam::Boolean(value));
            if !value {
                push_update("ban_reason", SqlParam::Null);
                push_update("ban_expires", SqlParam::Null);
            }
        }
        if let Some(value) = update.ban_reason {
            push_update("ban_reason", SqlParam::String(value));
        }
        if let Some(value) = update.ban_expires {
            push_update("ban_expires", SqlParam::String(value.to_rfc3339()));
        }
        if let Some(value) = update.two_factor_enabled {
            push_update("two_factor_enabled", SqlParam::Boolean(value));
        }
        if let Some(value) = update.metadata {
            push_update("metadata", SqlParam::Json(value));
        }

        params.push(SqlParam::String(id.to_string()));
        let sql = format!(
            "UPDATE {table} SET {sets} WHERE {id_col} = {id_placeholder} RETURNING *",
            table = self.table("users"),
            sets = sets.join(", "),
            id_col = quoted("id"),
            id_placeholder = self.placeholder(params.len()),
        );
        let row = self.fetch_one_row(sql, params)?;
        decode_user(row)
    }

    async fn delete_user(&self, id: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {id_col} = {placeholder}",
            table = self.table("users"),
            id_col = quoted("id"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(id.to_string())])?;
        Ok(())
    }

    async fn list_users(&self, params: ListUsersParams) -> AuthResult<(Vec<User>, usize)> {
        let limit = params.limit.unwrap_or(100) as i64;
        let offset = params.offset.unwrap_or(0) as i64;

        let mut conditions = Vec::new();
        let mut bind_values = Vec::new();

        if let Some(search_value) = &params.search_value {
            let field = params.search_field.as_deref().unwrap_or("email");
            let column = quoted(match field {
                "name" => "name",
                _ => "email",
            });
            let operator = params.search_operator.as_deref().unwrap_or("contains");
            let escaped = escape_like(search_value);
            let pattern = match operator {
                "starts_with" => format!("{escaped}%"),
                "ends_with" => format!("%{escaped}"),
                _ => format!("%{escaped}%"),
            };
            let index = bind_values.len() + 1;
            conditions.push(self.lower_like_expression(&column, index));
            bind_values.push(SqlParam::String(pattern));
        }

        if let Some(filter_value) = &params.filter_value {
            let field = params.filter_field.as_deref().unwrap_or("email");
            let column = quoted(match field {
                "name" => "name",
                "role" => "role",
                _ => "email",
            });
            let operator = params.filter_operator.as_deref().unwrap_or("eq");
            let index = bind_values.len() + 1;
            match operator {
                "contains" => {
                    conditions.push(self.lower_like_expression(&column, index));
                    bind_values.push(SqlParam::String(format!("%{}%", escape_like(filter_value))));
                }
                "ne" => {
                    conditions.push(format!("{column} != {}", self.placeholder(index)));
                    bind_values.push(SqlParam::String(filter_value.clone()));
                }
                _ => {
                    conditions.push(format!("{column} = {}", self.placeholder(index)));
                    bind_values.push(SqlParam::String(filter_value.clone()));
                }
            }
        }

        let where_clause = if conditions.is_empty() {
            String::new()
        } else {
            format!(" WHERE {}", conditions.join(" AND "))
        };

        let order_clause = if let Some(sort_by) = &params.sort_by {
            let column = quoted(match sort_by.as_str() {
                "name" => "name",
                "createdAt" | "created_at" => "created_at",
                _ => "email",
            });
            let direction = if params.sort_direction.as_deref() == Some("desc") {
                "DESC"
            } else {
                "ASC"
            };
            format!(" ORDER BY {column} {direction}")
        } else {
            format!(" ORDER BY {} DESC", quoted("created_at"))
        };

        let count_sql = format!(
            "SELECT COUNT(*) AS count FROM {table}{where_clause}",
            table = self.table("users"),
        );
        let count_row = self.fetch_one_row(count_sql, bind_values.clone())?;
        let total = RowReader::new(&count_row).integer("count")? as usize;

        let mut data_params = bind_values;
        data_params.push(SqlParam::Integer(limit));
        data_params.push(SqlParam::Integer(offset));
        let limit_placeholder = self.placeholder(data_params.len() - 1);
        let offset_placeholder = self.placeholder(data_params.len());
        let data_sql = format!(
            "SELECT * FROM {table}{where_clause}{order_clause} LIMIT {limit_placeholder} OFFSET {offset_placeholder}",
            table = self.table("users"),
        );
        let users = self
            .fetch_all_rows(data_sql, data_params)?
            .into_iter()
            .map(decode_user)
            .collect::<AuthResult<Vec<_>>>()?;

        Ok((users, total))
    }
}

#[async_trait]
impl SessionOps for SharedSqlDatabaseAdapter {
    type Session = Session;

    async fn create_session(&self, session: CreateSession) -> AuthResult<Session> {
        let id = Uuid::new_v4().to_string();
        let token = format!("session_{}", Uuid::new_v4());
        let now = now_text();
        let placeholders = self.placeholders(1, 11);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {user_id_col}, {token_col}, {expires_at_col}, {created_at_col}, \
             {updated_at_col}, {ip_address_col}, {user_agent_col}, {impersonated_by_col}, {active_org_col}, {active_col}) \
             VALUES ({values}) RETURNING *",
            table = self.table("sessions"),
            id_col = quoted("id"),
            user_id_col = quoted("user_id"),
            token_col = quoted("token"),
            expires_at_col = quoted("expires_at"),
            created_at_col = quoted("created_at"),
            updated_at_col = quoted("updated_at"),
            ip_address_col = quoted("ip_address"),
            user_agent_col = quoted("user_agent"),
            impersonated_by_col = quoted("impersonated_by"),
            active_org_col = quoted("active_organization_id"),
            active_col = quoted("active"),
            values = placeholders.join(", "),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id),
                SqlParam::String(session.user_id),
                SqlParam::String(token),
                SqlParam::String(session.expires_at.to_rfc3339()),
                SqlParam::String(now.clone()),
                SqlParam::String(now),
                match session.ip_address {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match session.user_agent {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match session.impersonated_by {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match session.active_organization_id {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                SqlParam::Boolean(true),
            ],
        )?;
        decode_session(row)
    }

    async fn get_session(&self, token: &str) -> AuthResult<Option<Session>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {token_col} = {placeholder} AND {active_col} = {active_value}",
            table = self.table("sessions"),
            token_col = quoted("token"),
            placeholder = self.placeholder(1),
            active_col = quoted("active"),
            active_value = self.dialect.bool_literal(true),
        );
        self.fetch_optional_row(sql, vec![SqlParam::String(token.to_string())])?
            .map(decode_session)
            .transpose()
    }

    async fn get_user_sessions(&self, user_id: &str) -> AuthResult<Vec<Session>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {user_id_col} = {placeholder} AND {active_col} = {active_value} ORDER BY {created_at_col}",
            table = self.table("sessions"),
            user_id_col = quoted("user_id"),
            placeholder = self.placeholder(1),
            active_col = quoted("active"),
            active_value = self.dialect.bool_literal(true),
            created_at_col = quoted("created_at"),
        );
        self.fetch_all_rows(sql, vec![SqlParam::String(user_id.to_string())])?
            .into_iter()
            .map(decode_session)
            .collect()
    }

    async fn update_session_expiry(
        &self,
        token: &str,
        expires_at: DateTime<Utc>,
    ) -> AuthResult<()> {
        let sql = format!(
            "UPDATE {table} SET {expires_at_col} = {expires_placeholder}, {updated_at_col} = {updated_placeholder} \
             WHERE {token_col} = {token_placeholder} AND {active_col} = {active_value}",
            table = self.table("sessions"),
            expires_at_col = quoted("expires_at"),
            expires_placeholder = self.placeholder(1),
            updated_at_col = quoted("updated_at"),
            updated_placeholder = self.placeholder(2),
            token_col = quoted("token"),
            token_placeholder = self.placeholder(3),
            active_col = quoted("active"),
            active_value = self.dialect.bool_literal(true),
        );
        self.execute_affected(
            sql,
            vec![
                SqlParam::String(expires_at.to_rfc3339()),
                SqlParam::String(now_text()),
                SqlParam::String(token.to_string()),
            ],
        )?;
        Ok(())
    }

    async fn delete_session(&self, token: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {token_col} = {placeholder}",
            table = self.table("sessions"),
            token_col = quoted("token"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(token.to_string())])?;
        Ok(())
    }

    async fn delete_user_sessions(&self, user_id: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {user_id_col} = {placeholder}",
            table = self.table("sessions"),
            user_id_col = quoted("user_id"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(user_id.to_string())])?;
        Ok(())
    }

    async fn delete_expired_sessions(&self) -> AuthResult<usize> {
        let sql = format!(
            "DELETE FROM {table} WHERE {expires_at_col} < {placeholder} OR {active_col} = {inactive_value}",
            table = self.table("sessions"),
            expires_at_col = quoted("expires_at"),
            placeholder = self.placeholder(1),
            active_col = quoted("active"),
            inactive_value = self.dialect.bool_literal(false),
        );
        self.execute_affected(sql, vec![SqlParam::String(now_text())])
    }

    async fn update_session_active_organization(
        &self,
        token: &str,
        organization_id: Option<&str>,
    ) -> AuthResult<Session> {
        let sql = format!(
            "UPDATE {table} SET {active_org_col} = {org_placeholder}, {updated_at_col} = {updated_placeholder} \
             WHERE {token_col} = {token_placeholder} AND {active_col} = {active_value} RETURNING *",
            table = self.table("sessions"),
            active_org_col = quoted("active_organization_id"),
            org_placeholder = self.placeholder(1),
            updated_at_col = quoted("updated_at"),
            updated_placeholder = self.placeholder(2),
            token_col = quoted("token"),
            token_placeholder = self.placeholder(3),
            active_col = quoted("active"),
            active_value = self.dialect.bool_literal(true),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                match organization_id {
                    Some(value) => SqlParam::String(value.to_string()),
                    None => SqlParam::Null,
                },
                SqlParam::String(now_text()),
                SqlParam::String(token.to_string()),
            ],
        )?;
        decode_session(row)
    }
}

#[async_trait]
impl AccountOps for SharedSqlDatabaseAdapter {
    type Account = Account;

    async fn create_account(&self, account: CreateAccount) -> AuthResult<Account> {
        let id = Uuid::new_v4().to_string();
        let now = now_text();
        let placeholders = self.placeholders(1, 13);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {account_id_col}, {provider_id_col}, {user_id_col}, {access_token_col}, \
             {refresh_token_col}, {id_token_col}, {access_expires_col}, {refresh_expires_col}, {scope_col}, \
             {password_col}, {created_at_col}, {updated_at_col}) VALUES ({values}) RETURNING *",
            table = self.table("accounts"),
            id_col = quoted("id"),
            account_id_col = quoted("account_id"),
            provider_id_col = quoted("provider_id"),
            user_id_col = quoted("user_id"),
            access_token_col = quoted("access_token"),
            refresh_token_col = quoted("refresh_token"),
            id_token_col = quoted("id_token"),
            access_expires_col = quoted("access_token_expires_at"),
            refresh_expires_col = quoted("refresh_token_expires_at"),
            scope_col = quoted("scope"),
            password_col = quoted("password"),
            created_at_col = quoted("created_at"),
            updated_at_col = quoted("updated_at"),
            values = placeholders.join(", "),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id),
                SqlParam::String(account.account_id),
                SqlParam::String(account.provider_id),
                SqlParam::String(account.user_id),
                option_string_param(account.access_token),
                option_string_param(account.refresh_token),
                option_string_param(account.id_token),
                option_date_param(account.access_token_expires_at),
                option_date_param(account.refresh_token_expires_at),
                option_string_param(account.scope),
                option_string_param(account.password),
                SqlParam::String(now.clone()),
                SqlParam::String(now),
            ],
        )?;
        decode_account(row)
    }

    async fn get_account(
        &self,
        provider: &str,
        provider_account_id: &str,
    ) -> AuthResult<Option<Account>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {provider_col} = {provider_placeholder} AND {account_col} = {account_placeholder}",
            table = self.table("accounts"),
            provider_col = quoted("provider_id"),
            provider_placeholder = self.placeholder(1),
            account_col = quoted("account_id"),
            account_placeholder = self.placeholder(2),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(provider.to_string()),
                SqlParam::String(provider_account_id.to_string()),
            ],
        )?
        .map(decode_account)
        .transpose()
    }

    async fn get_user_accounts(&self, user_id: &str) -> AuthResult<Vec<Account>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {user_id_col} = {placeholder} ORDER BY {created_at_col}",
            table = self.table("accounts"),
            user_id_col = quoted("user_id"),
            placeholder = self.placeholder(1),
            created_at_col = quoted("created_at"),
        );
        self.fetch_all_rows(sql, vec![SqlParam::String(user_id.to_string())])?
            .into_iter()
            .map(decode_account)
            .collect()
    }

    async fn update_account(&self, id: &str, update: UpdateAccount) -> AuthResult<Account> {
        let mut sets = vec![format!(
            "{} = {}",
            quoted("updated_at"),
            self.placeholder(1)
        )];
        let mut params = vec![SqlParam::String(now_text())];

        let mut push_update = |column: &str, value: SqlParam| {
            params.push(value);
            sets.push(format!(
                "{} = {}",
                quoted(column),
                self.placeholder(params.len()),
            ));
        };

        if let Some(value) = update.access_token {
            push_update("access_token", SqlParam::String(value));
        }
        if let Some(value) = update.refresh_token {
            push_update("refresh_token", SqlParam::String(value));
        }
        if let Some(value) = update.id_token {
            push_update("id_token", SqlParam::String(value));
        }
        if let Some(value) = update.access_token_expires_at {
            push_update(
                "access_token_expires_at",
                SqlParam::String(value.to_rfc3339()),
            );
        }
        if let Some(value) = update.refresh_token_expires_at {
            push_update(
                "refresh_token_expires_at",
                SqlParam::String(value.to_rfc3339()),
            );
        }
        if let Some(value) = update.scope {
            push_update("scope", SqlParam::String(value));
        }
        if let Some(value) = update.password {
            push_update("password", SqlParam::String(value));
        }

        params.push(SqlParam::String(id.to_string()));
        let sql = format!(
            "UPDATE {table} SET {sets} WHERE {id_col} = {placeholder} RETURNING *",
            table = self.table("accounts"),
            sets = sets.join(", "),
            id_col = quoted("id"),
            placeholder = self.placeholder(params.len()),
        );
        let row = self.fetch_one_row(sql, params)?;
        decode_account(row)
    }

    async fn delete_account(&self, id: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {id_col} = {placeholder}",
            table = self.table("accounts"),
            id_col = quoted("id"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(id.to_string())])?;
        Ok(())
    }
}

#[async_trait]
impl VerificationOps for SharedSqlDatabaseAdapter {
    type Verification = Verification;

    async fn create_verification(
        &self,
        verification: CreateVerification,
    ) -> AuthResult<Verification> {
        let id = Uuid::new_v4().to_string();
        let now = now_text();
        let placeholders = self.placeholders(1, 6);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {identifier_col}, {value_col}, {expires_col}, {created_col}, {updated_col}) \
             VALUES ({values}) RETURNING *",
            table = self.table("verifications"),
            id_col = quoted("id"),
            identifier_col = quoted("identifier"),
            value_col = quoted("value"),
            expires_col = quoted("expires_at"),
            created_col = quoted("created_at"),
            updated_col = quoted("updated_at"),
            values = placeholders.join(", "),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id),
                SqlParam::String(verification.identifier),
                SqlParam::String(verification.value),
                SqlParam::String(verification.expires_at.to_rfc3339()),
                SqlParam::String(now.clone()),
                SqlParam::String(now),
            ],
        )?;
        decode_verification(row)
    }

    async fn get_verification(
        &self,
        identifier: &str,
        value: &str,
    ) -> AuthResult<Option<Verification>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {identifier_col} = {identifier_placeholder} \
             AND {value_col} = {value_placeholder} AND {expires_col} > {expires_placeholder}",
            table = self.table("verifications"),
            identifier_col = quoted("identifier"),
            identifier_placeholder = self.placeholder(1),
            value_col = quoted("value"),
            value_placeholder = self.placeholder(2),
            expires_col = quoted("expires_at"),
            expires_placeholder = self.placeholder(3),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(identifier.to_string()),
                SqlParam::String(value.to_string()),
                SqlParam::String(now_text()),
            ],
        )?
        .map(decode_verification)
        .transpose()
    }

    async fn get_verification_by_value(&self, value: &str) -> AuthResult<Option<Verification>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {value_col} = {value_placeholder} AND {expires_col} > {expires_placeholder}",
            table = self.table("verifications"),
            value_col = quoted("value"),
            value_placeholder = self.placeholder(1),
            expires_col = quoted("expires_at"),
            expires_placeholder = self.placeholder(2),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(value.to_string()),
                SqlParam::String(now_text()),
            ],
        )?
        .map(decode_verification)
        .transpose()
    }

    async fn get_verification_by_identifier(
        &self,
        identifier: &str,
    ) -> AuthResult<Option<Verification>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {identifier_col} = {identifier_placeholder} \
             AND {expires_col} > {expires_placeholder}",
            table = self.table("verifications"),
            identifier_col = quoted("identifier"),
            identifier_placeholder = self.placeholder(1),
            expires_col = quoted("expires_at"),
            expires_placeholder = self.placeholder(2),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(identifier.to_string()),
                SqlParam::String(now_text()),
            ],
        )?
        .map(decode_verification)
        .transpose()
    }

    async fn consume_verification(
        &self,
        identifier: &str,
        value: &str,
    ) -> AuthResult<Option<Verification>> {
        let sql = format!(
            "DELETE FROM {table} WHERE {identifier_col} = {identifier_placeholder} \
             AND {value_col} = {value_placeholder} AND {expires_col} > {expires_placeholder} RETURNING *",
            table = self.table("verifications"),
            identifier_col = quoted("identifier"),
            identifier_placeholder = self.placeholder(1),
            value_col = quoted("value"),
            value_placeholder = self.placeholder(2),
            expires_col = quoted("expires_at"),
            expires_placeholder = self.placeholder(3),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(identifier.to_string()),
                SqlParam::String(value.to_string()),
                SqlParam::String(now_text()),
            ],
        )?
        .map(decode_verification)
        .transpose()
    }

    async fn delete_verification(&self, id: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {id_col} = {placeholder}",
            table = self.table("verifications"),
            id_col = quoted("id"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(id.to_string())])?;
        Ok(())
    }

    async fn delete_expired_verifications(&self) -> AuthResult<usize> {
        let sql = format!(
            "DELETE FROM {table} WHERE {expires_col} < {placeholder}",
            table = self.table("verifications"),
            expires_col = quoted("expires_at"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(now_text())])
    }
}

#[async_trait]
impl OrganizationOps for SharedSqlDatabaseAdapter {
    type Organization = Organization;

    async fn create_organization(&self, _org: CreateOrganization) -> AuthResult<Organization> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn get_organization_by_id(&self, _id: &str) -> AuthResult<Option<Organization>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn get_organization_by_slug(&self, _slug: &str) -> AuthResult<Option<Organization>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn update_organization(
        &self,
        _id: &str,
        _update: UpdateOrganization,
    ) -> AuthResult<Organization> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn delete_organization(&self, _id: &str) -> AuthResult<()> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn list_user_organizations(&self, _user_id: &str) -> AuthResult<Vec<Organization>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }
}

#[async_trait]
impl MemberOps for SharedSqlDatabaseAdapter {
    type Member = Member;

    async fn create_member(&self, _member: CreateMember) -> AuthResult<Member> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn get_member(
        &self,
        _organization_id: &str,
        _user_id: &str,
    ) -> AuthResult<Option<Member>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn get_member_by_id(&self, _id: &str) -> AuthResult<Option<Member>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn update_member_role(&self, _member_id: &str, _role: &str) -> AuthResult<Member> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn delete_member(&self, _member_id: &str) -> AuthResult<()> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn list_organization_members(&self, _organization_id: &str) -> AuthResult<Vec<Member>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn count_organization_members(&self, _organization_id: &str) -> AuthResult<usize> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }

    async fn count_organization_owners(&self, _organization_id: &str) -> AuthResult<usize> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support organizations yet.",
        ))
    }
}

#[async_trait]
impl InvitationOps for SharedSqlDatabaseAdapter {
    type Invitation = Invitation;

    async fn create_invitation(&self, _invitation: CreateInvitation) -> AuthResult<Invitation> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support invitations yet.",
        ))
    }

    async fn get_invitation_by_id(&self, _id: &str) -> AuthResult<Option<Invitation>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support invitations yet.",
        ))
    }

    async fn get_pending_invitation(
        &self,
        _organization_id: &str,
        _email: &str,
    ) -> AuthResult<Option<Invitation>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support invitations yet.",
        ))
    }

    async fn update_invitation_status(
        &self,
        _id: &str,
        _status: InvitationStatus,
    ) -> AuthResult<Invitation> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support invitations yet.",
        ))
    }

    async fn list_organization_invitations(
        &self,
        _organization_id: &str,
    ) -> AuthResult<Vec<Invitation>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support invitations yet.",
        ))
    }

    async fn list_user_invitations(&self, _email: &str) -> AuthResult<Vec<Invitation>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support invitations yet.",
        ))
    }
}

#[async_trait]
impl TwoFactorOps for SharedSqlDatabaseAdapter {
    type TwoFactor = TwoFactor;

    async fn create_two_factor(&self, _two_factor: CreateTwoFactor) -> AuthResult<TwoFactor> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support two-factor auth yet.",
        ))
    }

    async fn get_two_factor_by_user_id(&self, _user_id: &str) -> AuthResult<Option<TwoFactor>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support two-factor auth yet.",
        ))
    }

    async fn update_two_factor_backup_codes(
        &self,
        _user_id: &str,
        _backup_codes: &str,
    ) -> AuthResult<TwoFactor> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support two-factor auth yet.",
        ))
    }

    async fn delete_two_factor(&self, _user_id: &str) -> AuthResult<()> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support two-factor auth yet.",
        ))
    }
}

#[async_trait]
impl ApiKeyOps for SharedSqlDatabaseAdapter {
    type ApiKey = ApiKey;

    async fn create_api_key(&self, _input: CreateApiKey) -> AuthResult<ApiKey> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }

    async fn get_api_key_by_id(&self, _id: &str) -> AuthResult<Option<ApiKey>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }

    async fn get_api_key_by_hash(&self, _hash: &str) -> AuthResult<Option<ApiKey>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }

    async fn list_api_keys_by_user(&self, _user_id: &str) -> AuthResult<Vec<ApiKey>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }

    async fn update_api_key(&self, _id: &str, _update: UpdateApiKey) -> AuthResult<ApiKey> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }

    async fn delete_api_key(&self, _id: &str) -> AuthResult<()> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }

    async fn delete_expired_api_keys(&self) -> AuthResult<usize> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support API keys yet.",
        ))
    }
}

#[async_trait]
impl PasskeyOps for SharedSqlDatabaseAdapter {
    type Passkey = Passkey;

    async fn create_passkey(&self, _input: CreatePasskey) -> AuthResult<Passkey> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }

    async fn get_passkey_by_id(&self, _id: &str) -> AuthResult<Option<Passkey>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }

    async fn get_passkey_by_credential_id(
        &self,
        _credential_id: &str,
    ) -> AuthResult<Option<Passkey>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }

    async fn list_passkeys_by_user(&self, _user_id: &str) -> AuthResult<Vec<Passkey>> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }

    async fn update_passkey_counter(&self, _id: &str, _counter: u64) -> AuthResult<Passkey> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }

    async fn update_passkey_name(&self, _id: &str, _name: &str) -> AuthResult<Passkey> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }

    async fn delete_passkey(&self, _id: &str) -> AuthResult<()> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support passkeys yet.",
        ))
    }
}

fn option_string_param(value: Option<String>) -> SqlParam {
    match value {
        Some(value) => SqlParam::String(value),
        None => SqlParam::Null,
    }
}

fn option_date_param(value: Option<DateTime<Utc>>) -> SqlParam {
    match value {
        Some(value) => SqlParam::String(value.to_rfc3339()),
        None => SqlParam::Null,
    }
}
