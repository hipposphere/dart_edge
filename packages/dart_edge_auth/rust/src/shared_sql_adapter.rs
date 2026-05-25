use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};

use async_trait::async_trait;
use better_auth::types_mod::types_org::{Member, Organization};
use better_auth::types_mod::{
    ApiKey, ApiKeyOps, CreateApiKey, CreateTwoFactor, ListUsersParams, PASSWORD_HASH_KEY,
    TwoFactorOps, UpdateAccount, UpdateApiKey,
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
CREATE TABLE IF NOT EXISTS "user" (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    "emailVerified" BOOLEAN NOT NULL DEFAULT FALSE,
    image TEXT,
    role TEXT,
    banned BOOLEAN,
    "banReason" TEXT,
    "banExpires" TIMESTAMPTZ,
    "phoneNumber" TEXT UNIQUE,
    "phoneNumberVerified" BOOLEAN,
    "createdAt" TIMESTAMPTZ NOT NULL,
    "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_email ON "user" (email);

CREATE TABLE IF NOT EXISTS "session" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "expiresAt" TIMESTAMPTZ NOT NULL,
    "impersonatedBy" TEXT,
    "createdAt" TIMESTAMPTZ NOT NULL,
    "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_session_token ON "session" (token);
CREATE INDEX IF NOT EXISTS idx_session_user_id ON "session" ("userId");

CREATE TABLE IF NOT EXISTS "account" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    "accountId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "accessToken" TEXT,
    "refreshToken" TEXT,
    "idToken" TEXT,
    "accessTokenExpiresAt" TIMESTAMPTZ,
    "refreshTokenExpiresAt" TIMESTAMPTZ,
    scope TEXT,
    password TEXT,
    "createdAt" TIMESTAMPTZ NOT NULL,
    "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_account_user_id ON "account" ("userId");
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_provider ON "account" ("providerId", "accountId");

CREATE TABLE IF NOT EXISTS "verification" (
    id TEXT PRIMARY KEY NOT NULL,
    identifier TEXT NOT NULL,
    value TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL,
    "updatedAt" TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_verification_identifier ON "verification" (identifier);
CREATE INDEX IF NOT EXISTS idx_verification_value ON "verification" (value);

CREATE TABLE IF NOT EXISTS "organization" (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    logo TEXT,
    metadata JSONB,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_slug ON "organization" (slug);

CREATE TABLE IF NOT EXISTS "member" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    organization_id TEXT NOT NULL REFERENCES "organization" (id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    "createdAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_member_user_id ON "member" ("userId");
CREATE INDEX IF NOT EXISTS idx_member_org_id ON "member" (organization_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_member_user_org ON "member" ("userId", organization_id);

CREATE TABLE IF NOT EXISTS "invitation" (
    id TEXT PRIMARY KEY NOT NULL,
    organization_id TEXT NOT NULL REFERENCES "organization" (id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    status TEXT NOT NULL DEFAULT 'pending',
    inviter_id TEXT NOT NULL REFERENCES "user" (id),
    "expiresAt" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_invitation_org_id ON "invitation" (organization_id);
CREATE INDEX IF NOT EXISTS idx_invitation_email ON "invitation" (email);

CREATE TABLE IF NOT EXISTS "two_factor" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL UNIQUE REFERENCES "user" (id) ON DELETE CASCADE,
    secret TEXT NOT NULL,
    backup_codes TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_two_factor_user_id ON "two_factor" ("userId");

CREATE TABLE IF NOT EXISTS "api_keys" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
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
    "expiresAt" TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,
    permissions TEXT,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON "api_keys" ("userId");
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON "api_keys" ("key");

CREATE TABLE IF NOT EXISTS "passkeys" (
    id TEXT PRIMARY KEY NOT NULL,
    "userId" TEXT NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    counter BIGINT NOT NULL DEFAULT 0,
    device_type TEXT NOT NULL DEFAULT '',
    backed_up BOOLEAN NOT NULL DEFAULT FALSE,
    transports TEXT,
    "createdAt" TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_passkeys_user_id ON "passkeys" ("userId");
CREATE UNIQUE INDEX IF NOT EXISTS idx_passkeys_credential_id ON "passkeys" (credential_id);
"#;

const AUTH_TABLE_NAMES: &[&str] = &[
    "user",
    "session",
    "account",
    "verification",
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
    DateTime(String),
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

    fn datetime_placeholder(&self, index: usize) -> String {
        let placeholder = self.placeholder(index);
        match self.dialect {
            SharedSqlDialect::Postgres => format!("CAST({placeholder} AS TIMESTAMPTZ)"),
            SharedSqlDialect::Sqlite => placeholder,
        }
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

    fn user_select_sql(&self, where_clause: &str) -> String {
        format!(
            "SELECT u.*, \
             (SELECT a.{password_col} FROM {account_table} AS a \
              WHERE a.{account_user_col} = u.{user_id_col} \
              AND a.{provider_col} = 'credential' \
              ORDER BY a.{account_created_col} DESC LIMIT 1) AS {password_alias} \
             FROM {user_table} AS u WHERE {where_clause}",
            password_col = quoted("password"),
            account_table = self.table("account"),
            account_user_col = quoted("userId"),
            user_id_col = quoted("id"),
            provider_col = quoted("providerId"),
            account_created_col = quoted("createdAt"),
            password_alias = quoted("__passwordHash"),
            user_table = self.table("user"),
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
            Self::DateTime(value) => SqlValue::DateTime(value),
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

    fn boolean_or_default(&self, name: &str, default: bool) -> AuthResult<bool> {
        Ok(match self.values.get(name) {
            None | Some(SqlValue::Null) => default,
            Some(_) => self.boolean(name)?,
        })
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

fn now_datetime_param() -> SqlParam {
    SqlParam::DateTime(now_text())
}

fn escape_like(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('%', "\\%")
        .replace('_', "\\_")
}

fn decode_user(row: RowMap) -> AuthResult<User> {
    let row = RowReader::new(&row);
    let mut metadata = row.json_or_default("metadata")?;
    if let Some(password_hash) = row.opt_string("__passwordHash")? {
        if !metadata.is_object() {
            metadata = json!({});
        }
        if let Some(object) = metadata.as_object_mut() {
            object.insert(PASSWORD_HASH_KEY.to_string(), json!(password_hash));
        }
    }

    Ok(User {
        id: row.string("id")?,
        name: row.opt_string("name")?,
        email: row.opt_string("email")?,
        email_verified: row.boolean("emailVerified")?,
        image: row.opt_string("image")?,
        created_at: row.datetime("createdAt")?,
        updated_at: row.datetime("updatedAt")?,
        username: row.opt_string("username")?,
        display_username: row.opt_string("displayUsername")?,
        two_factor_enabled: row.boolean_or_default("twoFactorEnabled", false)?,
        role: row.opt_string("role")?,
        banned: row.boolean_or_default("banned", false)?,
        ban_reason: row.opt_string("banReason")?,
        ban_expires: row.opt_datetime("banExpires")?,
        metadata,
    })
}

fn decode_session(row: RowMap) -> AuthResult<Session> {
    let row = RowReader::new(&row);
    Ok(Session {
        id: row.string("id")?,
        expires_at: row.datetime("expiresAt")?,
        token: row.string("token")?,
        created_at: row.datetime("createdAt")?,
        updated_at: row.datetime("updatedAt")?,
        ip_address: row.opt_string("ipAddress")?,
        user_agent: row.opt_string("userAgent")?,
        user_id: row.string("userId")?,
        impersonated_by: row.opt_string("impersonatedBy")?,
        active_organization_id: row.opt_string("activeOrganizationId")?,
        active: row.boolean_or_default("active", true)?,
    })
}

fn decode_account(row: RowMap) -> AuthResult<Account> {
    let row = RowReader::new(&row);
    Ok(Account {
        id: row.string("id")?,
        account_id: row.string("accountId")?,
        provider_id: row.string("providerId")?,
        user_id: row.string("userId")?,
        access_token: row.opt_string("accessToken")?,
        refresh_token: row.opt_string("refreshToken")?,
        id_token: row.opt_string("idToken")?,
        access_token_expires_at: row.opt_datetime("accessTokenExpiresAt")?,
        refresh_token_expires_at: row.opt_datetime("refreshTokenExpiresAt")?,
        scope: row.opt_string("scope")?,
        password: row.opt_string("password")?,
        created_at: row.datetime("createdAt")?,
        updated_at: row.datetime("updatedAt")?,
    })
}

fn decode_verification(row: RowMap) -> AuthResult<Verification> {
    let row = RowReader::new(&row);
    Ok(Verification {
        id: row.string("id")?,
        identifier: row.string("identifier")?,
        value: row.string("value")?,
        expires_at: row.datetime("expiresAt")?,
        created_at: row.datetime("createdAt")?,
        updated_at: row.datetime("updatedAt")?,
    })
}

#[async_trait]
impl UserOps for SharedSqlDatabaseAdapter {
    type User = User;

    async fn create_user(&self, create_user: CreateUser) -> AuthResult<User> {
        let id = create_user.id.unwrap_or_else(|| Uuid::new_v4().to_string());
        let now = now_text();
        let password_hash = create_user
            .metadata
            .as_ref()
            .and_then(|metadata| metadata.get(PASSWORD_HASH_KEY))
            .and_then(|value| value.as_str())
            .map(ToOwned::to_owned);
        let placeholders = self.placeholders(1, 8);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {email_col}, {name_col}, {image_col}, {verified_col}, \
             {role_col}, {createdAt_col}, {updatedAt_col}) \
             VALUES ({values}) RETURNING *",
            table = self.table("user"),
            id_col = quoted("id"),
            email_col = quoted("email"),
            name_col = quoted("name"),
            image_col = quoted("image"),
            verified_col = quoted("emailVerified"),
            role_col = quoted("role"),
            createdAt_col = quoted("createdAt"),
            updatedAt_col = quoted("updatedAt"),
            values = placeholders.join(", "),
        );
        self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id.clone()),
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
                SqlParam::String(create_user.role.unwrap_or_else(|| "user".to_string())),
                SqlParam::DateTime(now.clone()),
                SqlParam::DateTime(now),
            ],
        )?;

        if let Some(password_hash) = password_hash {
            self.create_account(CreateAccount {
                user_id: id.clone(),
                account_id: id.clone(),
                provider_id: "credential".to_string(),
                access_token: None,
                refresh_token: None,
                id_token: None,
                access_token_expires_at: None,
                refresh_token_expires_at: None,
                scope: None,
                password: Some(password_hash),
            })
            .await?;
        }

        self.get_user_by_id(&id)
            .await?
            .ok_or_else(|| AuthError::not_found("User not found"))
    }

    async fn get_user_by_id(&self, id: &str) -> AuthResult<Option<User>> {
        let sql = self.user_select_sql(&format!(
            "u.{id_col} = {placeholder}",
            id_col = quoted("id"),
            placeholder = self.placeholder(1),
        ));
        self.fetch_optional_row(sql, vec![SqlParam::String(id.to_string())])?
            .map(decode_user)
            .transpose()
    }

    async fn get_user_by_email(&self, email: &str) -> AuthResult<Option<User>> {
        let sql = self.user_select_sql(&format!(
            "u.{email_col} = {placeholder}",
            email_col = quoted("email"),
            placeholder = self.placeholder(1),
        ));
        self.fetch_optional_row(sql, vec![SqlParam::String(email.to_string())])?
            .map(decode_user)
            .transpose()
    }

    async fn get_user_by_username(&self, username: &str) -> AuthResult<Option<User>> {
        let sql = self.user_select_sql(&format!(
            "u.{username_col} = {placeholder}",
            username_col = quoted("username"),
            placeholder = self.placeholder(1),
        ));
        self.fetch_optional_row(sql, vec![SqlParam::String(username.to_string())])?
            .map(decode_user)
            .transpose()
    }

    async fn update_user(&self, id: &str, update: UpdateUser) -> AuthResult<User> {
        let mut sets = vec![format!("{} = {}", quoted("updatedAt"), self.placeholder(1))];
        let mut params = vec![now_datetime_param()];

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
            push_update("emailVerified", SqlParam::Boolean(value));
        }
        if let Some(value) = update.username {
            push_update("username", SqlParam::String(value));
        }
        if let Some(value) = update.display_username {
            push_update("displayUsername", SqlParam::String(value));
        }
        if let Some(value) = update.role {
            push_update("role", SqlParam::String(value));
        }
        if let Some(value) = update.banned {
            push_update("banned", SqlParam::Boolean(value));
            if !value {
                push_update("banReason", SqlParam::Null);
                push_update("banExpires", SqlParam::Null);
            }
        }
        if let Some(value) = update.ban_reason {
            push_update("banReason", SqlParam::String(value));
        }
        if let Some(value) = update.ban_expires {
            push_update("banExpires", SqlParam::DateTime(value.to_rfc3339()));
        }
        if let Some(value) = update.two_factor_enabled {
            push_update("twoFactorEnabled", SqlParam::Boolean(value));
        }
        let _metadata = update.metadata;

        params.push(SqlParam::String(id.to_string()));
        let sql = format!(
            "UPDATE {table} SET {sets} WHERE {id_col} = {id_placeholder} RETURNING *",
            table = self.table("user"),
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
            table = self.table("user"),
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
                "createdAt" | "created_at" => "createdAt",
                _ => "email",
            });
            let direction = if params.sort_direction.as_deref() == Some("desc") {
                "DESC"
            } else {
                "ASC"
            };
            format!(" ORDER BY {column} {direction}")
        } else {
            format!(" ORDER BY {} DESC", quoted("createdAt"))
        };

        let count_sql = format!(
            "SELECT COUNT(*) AS count FROM {table}{where_clause}",
            table = self.table("user"),
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
            table = self.table("user"),
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
        let placeholders = self.placeholders(1, 8);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {userId_col}, {token_col}, {expiresAt_col}, {createdAt_col}, \
             {updatedAt_col}, {ipAddress_col}, {userAgent_col}) \
             VALUES ({values}) RETURNING *",
            table = self.table("session"),
            id_col = quoted("id"),
            userId_col = quoted("userId"),
            token_col = quoted("token"),
            expiresAt_col = quoted("expiresAt"),
            createdAt_col = quoted("createdAt"),
            updatedAt_col = quoted("updatedAt"),
            ipAddress_col = quoted("ipAddress"),
            userAgent_col = quoted("userAgent"),
            values = placeholders.join(", "),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id),
                SqlParam::String(session.user_id),
                SqlParam::String(token),
                SqlParam::DateTime(session.expires_at.to_rfc3339()),
                SqlParam::DateTime(now.clone()),
                SqlParam::DateTime(now),
                match session.ip_address {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
                match session.user_agent {
                    Some(value) => SqlParam::String(value),
                    None => SqlParam::Null,
                },
            ],
        )?;
        decode_session(row)
    }

    async fn get_session(&self, token: &str) -> AuthResult<Option<Session>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {token_col} = {placeholder}",
            table = self.table("session"),
            token_col = quoted("token"),
            placeholder = self.placeholder(1),
        );
        self.fetch_optional_row(sql, vec![SqlParam::String(token.to_string())])?
            .map(decode_session)
            .transpose()
    }

    async fn get_user_sessions(&self, user_id: &str) -> AuthResult<Vec<Session>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {userId_col} = {placeholder} ORDER BY {createdAt_col}",
            table = self.table("session"),
            userId_col = quoted("userId"),
            placeholder = self.placeholder(1),
            createdAt_col = quoted("createdAt"),
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
            "UPDATE {table} SET {expiresAt_col} = {expires_placeholder}, {updatedAt_col} = {updated_placeholder} \
             WHERE {token_col} = {token_placeholder}",
            table = self.table("session"),
            expiresAt_col = quoted("expiresAt"),
            expires_placeholder = self.placeholder(1),
            updatedAt_col = quoted("updatedAt"),
            updated_placeholder = self.placeholder(2),
            token_col = quoted("token"),
            token_placeholder = self.placeholder(3),
        );
        self.execute_affected(
            sql,
            vec![
                SqlParam::DateTime(expires_at.to_rfc3339()),
                now_datetime_param(),
                SqlParam::String(token.to_string()),
            ],
        )?;
        Ok(())
    }

    async fn delete_session(&self, token: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {token_col} = {placeholder}",
            table = self.table("session"),
            token_col = quoted("token"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(token.to_string())])?;
        Ok(())
    }

    async fn delete_user_sessions(&self, user_id: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {userId_col} = {placeholder}",
            table = self.table("session"),
            userId_col = quoted("userId"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(user_id.to_string())])?;
        Ok(())
    }

    async fn delete_expired_sessions(&self) -> AuthResult<usize> {
        let sql = format!(
            "DELETE FROM {table} WHERE {expiresAt_col} < {placeholder}",
            table = self.table("session"),
            expiresAt_col = quoted("expiresAt"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![now_datetime_param()])
    }

    async fn update_session_active_organization(
        &self,
        _token: &str,
        _organization_id: Option<&str>,
    ) -> AuthResult<Session> {
        Err(AuthError::not_implemented(
            "Shared dart_edge_sql auth databases do not support active organizations yet.",
        ))
    }
}

#[async_trait]
impl AccountOps for SharedSqlDatabaseAdapter {
    type Account = Account;

    async fn create_account(&self, account: CreateAccount) -> AuthResult<Account> {
        if let Some(existing) = self
            .get_account(&account.provider_id, &account.account_id)
            .await?
        {
            return Ok(existing);
        }

        let id = Uuid::new_v4().to_string();
        let now = now_text();
        let mut placeholders = self.placeholders(1, 13);
        placeholders[7] = self.datetime_placeholder(8);
        placeholders[8] = self.datetime_placeholder(9);
        let sql = format!(
            "INSERT INTO {table} ({id_col}, {accountId_col}, {providerId_col}, {userId_col}, {accessToken_col}, \
             {refreshToken_col}, {idToken_col}, {access_expires_col}, {refresh_expires_col}, {scope_col}, \
             {password_col}, {createdAt_col}, {updatedAt_col}) VALUES ({values}) RETURNING *",
            table = self.table("account"),
            id_col = quoted("id"),
            accountId_col = quoted("accountId"),
            providerId_col = quoted("providerId"),
            userId_col = quoted("userId"),
            accessToken_col = quoted("accessToken"),
            refreshToken_col = quoted("refreshToken"),
            idToken_col = quoted("idToken"),
            access_expires_col = quoted("accessTokenExpiresAt"),
            refresh_expires_col = quoted("refreshTokenExpiresAt"),
            scope_col = quoted("scope"),
            password_col = quoted("password"),
            createdAt_col = quoted("createdAt"),
            updatedAt_col = quoted("updatedAt"),
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
                SqlParam::DateTime(now.clone()),
                SqlParam::DateTime(now),
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
            table = self.table("account"),
            provider_col = quoted("providerId"),
            provider_placeholder = self.placeholder(1),
            account_col = quoted("accountId"),
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
            "SELECT * FROM {table} WHERE {userId_col} = {placeholder} ORDER BY {createdAt_col}",
            table = self.table("account"),
            userId_col = quoted("userId"),
            placeholder = self.placeholder(1),
            createdAt_col = quoted("createdAt"),
        );
        self.fetch_all_rows(sql, vec![SqlParam::String(user_id.to_string())])?
            .into_iter()
            .map(decode_account)
            .collect()
    }

    async fn update_account(&self, id: &str, update: UpdateAccount) -> AuthResult<Account> {
        let mut sets = vec![format!("{} = {}", quoted("updatedAt"), self.placeholder(1))];
        let mut params = vec![now_datetime_param()];

        let mut push_update = |column: &str, value: SqlParam| {
            params.push(value);
            sets.push(format!(
                "{} = {}",
                quoted(column),
                self.placeholder(params.len()),
            ));
        };

        if let Some(value) = update.access_token {
            push_update("accessToken", SqlParam::String(value));
        }
        if let Some(value) = update.refresh_token {
            push_update("refreshToken", SqlParam::String(value));
        }
        if let Some(value) = update.id_token {
            push_update("idToken", SqlParam::String(value));
        }
        if let Some(value) = update.access_token_expires_at {
            push_update(
                "accessTokenExpiresAt",
                SqlParam::DateTime(value.to_rfc3339()),
            );
        }
        if let Some(value) = update.refresh_token_expires_at {
            push_update(
                "refreshTokenExpiresAt",
                SqlParam::DateTime(value.to_rfc3339()),
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
            table = self.table("account"),
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
            table = self.table("account"),
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
            table = self.table("verification"),
            id_col = quoted("id"),
            identifier_col = quoted("identifier"),
            value_col = quoted("value"),
            expires_col = quoted("expiresAt"),
            created_col = quoted("createdAt"),
            updated_col = quoted("updatedAt"),
            values = placeholders.join(", "),
        );
        let row = self.fetch_one_row(
            sql,
            vec![
                SqlParam::String(id),
                SqlParam::String(verification.identifier),
                SqlParam::String(verification.value),
                SqlParam::DateTime(verification.expires_at.to_rfc3339()),
                SqlParam::DateTime(now.clone()),
                SqlParam::DateTime(now),
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
            table = self.table("verification"),
            identifier_col = quoted("identifier"),
            identifier_placeholder = self.placeholder(1),
            value_col = quoted("value"),
            value_placeholder = self.placeholder(2),
            expires_col = quoted("expiresAt"),
            expires_placeholder = self.placeholder(3),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(identifier.to_string()),
                SqlParam::String(value.to_string()),
                now_datetime_param(),
            ],
        )?
        .map(decode_verification)
        .transpose()
    }

    async fn get_verification_by_value(&self, value: &str) -> AuthResult<Option<Verification>> {
        let sql = format!(
            "SELECT * FROM {table} WHERE {value_col} = {value_placeholder} AND {expires_col} > {expires_placeholder}",
            table = self.table("verification"),
            value_col = quoted("value"),
            value_placeholder = self.placeholder(1),
            expires_col = quoted("expiresAt"),
            expires_placeholder = self.placeholder(2),
        );
        self.fetch_optional_row(
            sql,
            vec![SqlParam::String(value.to_string()), now_datetime_param()],
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
            table = self.table("verification"),
            identifier_col = quoted("identifier"),
            identifier_placeholder = self.placeholder(1),
            expires_col = quoted("expiresAt"),
            expires_placeholder = self.placeholder(2),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(identifier.to_string()),
                now_datetime_param(),
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
            table = self.table("verification"),
            identifier_col = quoted("identifier"),
            identifier_placeholder = self.placeholder(1),
            value_col = quoted("value"),
            value_placeholder = self.placeholder(2),
            expires_col = quoted("expiresAt"),
            expires_placeholder = self.placeholder(3),
        );
        self.fetch_optional_row(
            sql,
            vec![
                SqlParam::String(identifier.to_string()),
                SqlParam::String(value.to_string()),
                now_datetime_param(),
            ],
        )?
        .map(decode_verification)
        .transpose()
    }

    async fn delete_verification(&self, id: &str) -> AuthResult<()> {
        let sql = format!(
            "DELETE FROM {table} WHERE {id_col} = {placeholder}",
            table = self.table("verification"),
            id_col = quoted("id"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![SqlParam::String(id.to_string())])?;
        Ok(())
    }

    async fn delete_expired_verifications(&self) -> AuthResult<usize> {
        let sql = format!(
            "DELETE FROM {table} WHERE {expires_col} < {placeholder}",
            table = self.table("verification"),
            expires_col = quoted("expiresAt"),
            placeholder = self.placeholder(1),
        );
        self.execute_affected(sql, vec![now_datetime_param()])
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
        Some(value) => SqlParam::DateTime(value.to_rfc3339()),
        None => SqlParam::Null,
    }
}
