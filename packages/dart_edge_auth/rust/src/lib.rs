use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use better_auth::adapters::{DatabaseAdapter, MemoryDatabaseAdapter, SqlxAdapter};
use better_auth::plugins::OAuthPlugin;
use better_auth::plugins::oauth::{OAuthConfig, OAuthProvider, OAuthUserInfo};
use better_auth::plugins::{
    AccountManagementPlugin, AdminPlugin, EmailPasswordPlugin, EmailVerificationPlugin,
    PasswordHasher, PasswordManagementConfig, PasswordManagementPlugin, SessionManagementPlugin,
};
use better_auth::types_mod::{ListUsersParams, PASSWORD_HASH_KEY, UpdateAccount, extract_origin};
use better_auth::{AuthAccount, AuthSession, AuthUser};
use better_auth::{
    AuthBuilder, AuthConfig, AuthError, AuthRequest, AuthResponse, AuthResult, BetterAuth,
    CreateAccount, CreateSession, HttpMethod, RateLimitConfig, TypedAuthBuilder, UpdateUser,
};
use better_auth_diesel_sqlite::DieselSqliteAdapter;
use chrono::{Duration, Utc};
use dart_edge_core::{
    NativePair, OwnedBytes, OwnedPair, boxed_pairs_ptr, native_pairs_from_owned, read_native_bytes,
    read_pairs_map,
};
use dart_edge_http_server_core::{
    NativeHttpMethod, NativeHttpRequest, NativeHttpResponse, native_http_routes_to_json,
};
use hmac::{Hmac, Mac};
use once_cell::sync::Lazy;
use scrypt::{Params as ScryptParams, scrypt};
use serde::Deserialize;
use serde_json::json;
use sha2::Sha256;
use shared_sql_adapter::{SharedSqlCallbacks, SharedSqlDatabaseAdapter, SharedSqlDialect};
use tokio::runtime::Runtime;
use tracing::field::{Field, Visit};
use tracing::{Event, Subscriber};
use tracing_subscriber::layer::{Context, SubscriberExt};
use tracing_subscriber::{Layer, Registry};
use unicode_normalization::UnicodeNormalization;
use uuid::Uuid;

mod routes;
mod shared_sql_adapter;

use routes::{join_path, normalize_base_path};

const DART_EDGE_AUTH_NATIVE_ABI_VERSION: i32 = 2;
const TRUSTED_CALLBACK_URL_ERROR_MESSAGE: &str =
    "callbackURL must be an absolute http(s) URL on a trusted origin";
const NODE_SESSION_COOKIE_NAME: &str = "better-auth.session_token";
const NODE_DASH_SESSION_COOKIE_NAME: &str = "better-auth-session_token";
const RUST_SESSION_COOKIE_NAME: &str = "better-auth.session-token";
const SECURE_COOKIE_PREFIX: &str = "__Secure-";
const HOST_COOKIE_PREFIX: &str = "__Host-";

type HmacSha256 = Hmac<Sha256>;

static NEXT_INSTANCE_ID: AtomicI64 = AtomicI64::new(1);
static INSTANCES: Lazy<Mutex<HashMap<i64, AuthInstance>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));
static PASSWORD_HASHER: Lazy<Arc<dyn PasswordHasher>> =
    Lazy::new(|| Arc::new(BetterAuthTsPasswordHasher));

struct AuthInstance {
    base_path: String,
    secret: String,
    session_cookie_name: String,
    admin_config: NativeAdminConfig,
    runtime: Runtime,
    auth: NativeAuthBackend,
}

struct BetterAuthTsPasswordHasher;

#[async_trait]
impl PasswordHasher for BetterAuthTsPasswordHasher {
    async fn hash(&self, password: &str) -> AuthResult<String> {
        better_auth_ts_hash_password(password)
    }

    async fn verify(&self, hash: &str, password: &str) -> AuthResult<bool> {
        if is_better_auth_ts_hash(hash) {
            return better_auth_ts_verify_password(hash, password);
        }

        // Keep already-created Rust Better Auth Argon2 accounts sign-inable
        // after switching new hashes to Better Auth TS' scrypt format.
        match better_auth::types_mod::verify_password(None, password, hash).await {
            Ok(()) => Ok(true),
            Err(AuthError::InvalidCredentials) => Ok(false),
            Err(error) => Err(error),
        }
    }
}

fn better_auth_ts_hash_password(password: &str) -> AuthResult<String> {
    let salt = hex_encode(Uuid::new_v4().as_bytes());
    let key = better_auth_ts_scrypt_key(password, &salt)?;
    Ok(format!("{salt}:{}", hex_encode(&key)))
}

fn better_auth_ts_verify_password(hash: &str, password: &str) -> AuthResult<bool> {
    let Some((salt, expected_key)) = hash.split_once(':') else {
        return Ok(false);
    };
    if salt.is_empty() || expected_key.is_empty() || expected_key.len() % 2 != 0 {
        return Ok(false);
    }

    let key = better_auth_ts_scrypt_key(password, salt)?;
    Ok(hex_encode(&key).eq_ignore_ascii_case(expected_key))
}

fn better_auth_ts_scrypt_key(password: &str, salt: &str) -> AuthResult<[u8; 64]> {
    let normalized_password = password.nfkc().collect::<String>();
    let mut key = [0u8; 64];
    let params = ScryptParams::new(14, 16, 1, key.len())
        .map_err(|error| AuthError::internal(format!("Invalid scrypt parameters: {error}")))?;
    scrypt(
        normalized_password.as_bytes(),
        salt.as_bytes(),
        &params,
        &mut key,
    )
    .map_err(|error| AuthError::internal(format!("Failed to hash password: {error}")))?;
    Ok(key)
}

fn is_better_auth_ts_hash(hash: &str) -> bool {
    let Some((salt, key)) = hash.split_once(':') else {
        return false;
    };
    !salt.is_empty()
        && salt.bytes().all(|byte| byte.is_ascii_hexdigit())
        && key.len() == 128
        && key.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn hex_encode(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push(DIGITS[(byte >> 4) as usize] as char);
        output.push(DIGITS[(byte & 0x0f) as usize] as char);
    }
    output
}

enum NativeAuthBackend {
    Memory(BetterAuth<MemoryDatabaseAdapter>),
    Postgres(BetterAuth<SqlxAdapter>),
    Sqlite(BetterAuth<DieselSqliteAdapter>),
    Shared(BetterAuth<SharedSqlDatabaseAdapter>),
}

type SharedExecutePoolFn =
    unsafe extern "C" fn(handle: i64, statement_json: *const c_char) -> *mut c_char;
type SharedTakeLastErrorFn = unsafe extern "C" fn() -> *mut c_char;
type SharedFreeStringFn = unsafe extern "C" fn(value: *mut c_char);

#[repr(C)]
struct NativeAuthResponseHandle {
    response: NativeHttpResponse,
    content_type: OwnedBytes,
    headers: Vec<OwnedPair>,
    header_pairs: Box<[NativePair]>,
    body: OwnedBytes,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeAuthConfig {
    secret: String,
    base_url: String,
    #[serde(default = "default_database")]
    database: NativeDatabaseConfig,
    base_path: String,
    app_name: String,
    password_min_length: usize,
    trusted_origins: Vec<String>,
    enable_email_password: bool,
    enable_signup: bool,
    enable_session_management: bool,
    enable_password_management: bool,
    enable_account_management: bool,
    enable_email_verification: bool,
    enable_rate_limit: bool,
    #[serde(default)]
    oauth_providers: Vec<NativeOAuthProviderConfig>,
    admin: Option<NativeAdminConfig>,
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeOAuthProviderConfig {
    provider_id: String,
    client_id: String,
    #[serde(default)]
    client_secret: String,
    authorization_url: String,
    token_url: String,
    #[serde(default)]
    user_info_url: String,
    #[serde(default = "default_oauth_scopes")]
    scopes: Vec<String>,
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeAdminConfig {
    admin_role: String,
    default_user_role: String,
    allow_ban_admin: bool,
    default_page_limit: usize,
    max_page_limit: usize,
}

impl Default for NativeAdminConfig {
    fn default() -> Self {
        Self {
            admin_role: "admin".to_string(),
            default_user_role: "user".to_string(),
            allow_ban_admin: false,
            default_page_limit: 100,
            max_page_limit: 500,
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedCreateUserRequest {
    email: String,
    password: String,
    name: String,
    role: Option<String>,
    data: Option<serde_json::Value>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedSetRoleRequest {
    user_id: String,
    role: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedUserIdRequest {
    user_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedBanUserRequest {
    user_id: String,
    ban_reason: Option<String>,
    ban_expires_in: Option<i64>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedImpersonateUserRequest {
    user_id: String,
    impersonated_by_user_id: String,
    ip_address: Option<String>,
    user_agent: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedStopImpersonatingRequest {
    session_token: String,
    ip_address: Option<String>,
    user_agent: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedRevokeSessionRequest {
    session_token: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedSetUserPasswordRequest {
    user_id: String,
    new_password: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrustedHasPermissionRequest {
    user_id: String,
    permission: Option<serde_json::Value>,
    permissions: Option<serde_json::Value>,
}

#[derive(Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
enum NativeDatabaseConfig {
    Memory,
    Postgres {
        connection_string: String,
    },
    Sqlite {
        path: String,
        #[serde(rename = "inMemory")]
        in_memory: bool,
        #[serde(rename = "manageMigrations")]
        #[serde(default = "default_manage_migrations")]
        manage_migrations: bool,
    },
    Shared {
        dialect: NativeSharedSqlDialect,
        schema: Option<String>,
        #[serde(rename = "manageMigrations")]
        #[serde(default = "default_manage_migrations")]
        manage_migrations: bool,
    },
}

#[derive(Clone, Copy, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "lowercase")]
enum NativeSharedSqlDialect {
    Postgres,
    Sqlite,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_native_abi_version() -> i32 {
    DART_EDGE_AUTH_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_create(config_json: *const c_char) -> i64 {
    let Some(config_json) = (unsafe { read_c_string(config_json) }) else {
        set_last_error("Missing dart_edge_auth config JSON.");
        return 0;
    };

    create_instance(&config_json, None)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_create_with_shared_database(
    config_json: *const c_char,
    dialect: i32,
    database_handle: i64,
    execute_pool: Option<SharedExecutePoolFn>,
    take_last_error: Option<SharedTakeLastErrorFn>,
    free_string: Option<SharedFreeStringFn>,
) -> i64 {
    let Some(config_json) = (unsafe { read_c_string(config_json) }) else {
        set_last_error("Missing dart_edge_auth config JSON.");
        return 0;
    };

    let callbacks = match (execute_pool, take_last_error, free_string) {
        (Some(execute_pool), Some(take_last_error), Some(free_string)) => SharedSqlCallbacks {
            database_handle,
            execute_pool,
            take_last_error,
            free_string,
        },
        _ => {
            set_last_error("Missing shared dart_edge_sql callbacks.");
            return 0;
        }
    };

    let dialect = match decode_shared_dialect(dialect) {
        Some(dialect) => dialect,
        None => {
            set_last_error(format!(
                "Unsupported shared database dialect code: {dialect}"
            ));
            return 0;
        }
    };

    create_instance(&config_json, Some((dialect, callbacks)))
}

fn create_instance(
    config_json: &str,
    shared_database: Option<(SharedSqlDialect, SharedSqlCallbacks)>,
) -> i64 {
    let config: NativeAuthConfig = match serde_json::from_str(config_json) {
        Ok(config) => config,
        Err(error) => {
            set_last_error(format!("Invalid dart_edge_auth config: {error}"));
            return 0;
        }
    };

    let runtime = match build_runtime() {
        Ok(runtime) => runtime,
        Err(error) => {
            set_last_error(format!("Failed to create auth runtime: {error}"));
            return 0;
        }
    };

    let base_path = normalize_base_path(&config.base_path);
    let session_cookie_name = node_session_cookie_name(&config.base_url);
    let auth = match runtime.block_on(build_auth(&config, &base_path, shared_database)) {
        Ok(auth) => auth,
        Err(error) => {
            set_last_error(error);
            return 0;
        }
    };

    let handle = NEXT_INSTANCE_ID.fetch_add(1, Ordering::Relaxed);
    INSTANCES.lock().unwrap().insert(
        handle,
        AuthInstance {
            base_path,
            secret: config.secret.clone(),
            session_cookie_name,
            admin_config: config.admin.clone().unwrap_or_default(),
            runtime,
            auth,
        },
    );
    clear_last_error();
    handle
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_dispose(handle: i64) {
    INSTANCES.lock().unwrap().remove(&handle);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_list_routes(handle: i64) -> *mut c_char {
    let instances = INSTANCES.lock().unwrap();
    let Some(instance) = instances.get(&handle) else {
        set_last_error("Unknown dart_edge_auth handle.");
        return std::ptr::null_mut();
    };

    let spec = instance.auth.openapi_spec();
    let routes = routes::list_routes(&spec, &instance.base_path);
    let json = match native_http_routes_to_json(&routes) {
        Ok(json) => json,
        Err(error) => {
            set_last_error(format!("Failed to encode auth routes: {error}"));
            return std::ptr::null_mut();
        }
    };

    match CString::new(json) {
        Ok(value) => {
            clear_last_error();
            value.into_raw()
        }
        Err(error) => {
            set_last_error(format!("Failed to serialize auth routes: {error}"));
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_handle_request(
    handle: i64,
    request: *const NativeHttpRequest,
) -> *mut NativeHttpResponse {
    let Some(request) = (unsafe { request.as_ref() }) else {
        set_last_error("Missing auth request.");
        return std::ptr::null_mut();
    };

    let Some(path) = (unsafe { read_c_string(request.path) }) else {
        set_last_error("Missing auth request path.");
        return std::ptr::null_mut();
    };

    let Some(native_method) = NativeHttpMethod::from_code(request.method) else {
        set_last_error(format!(
            "Unsupported auth request method code: {}",
            request.method
        ));
        return std::ptr::null_mut();
    };
    let method = decode_method(native_method);

    let query = unsafe { read_pairs_map(request.query, request.query_count) };
    let mut headers = unsafe { read_pairs_map(request.headers, request.header_count) };
    let body = unsafe { read_native_bytes(request.body) }.map(|body| body.to_vec());
    let callback_detail = trusted_callback_url_rejection_detail(&query, body.as_deref());
    let internal_auth_error = Arc::new(Mutex::new(None));

    let mut instances = INSTANCES.lock().unwrap();
    let Some(instance) = instances.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_auth handle.");
        return std::ptr::null_mut();
    };
    normalize_session_auth_headers(
        &mut headers,
        &instance.session_cookie_name,
        &instance.secret,
    );

    let response = if method == HttpMethod::Get && path == join_path(&instance.base_path, "/health")
    {
        better_auth::AuthResponse::json(
            200,
            &json!({
                "status": "ok",
                "service": "better-auth",
            }),
        )
        .map_err(|error| error.to_string())
    } else {
        let request = AuthRequest::from_parts(method, path, headers, body, query);
        let subscriber = Registry::default().with(BetterAuthInternalErrorLayer {
            error: Arc::clone(&internal_auth_error),
        });
        tracing::subscriber::with_default(subscriber, || {
            instance
                .runtime
                .block_on(instance.auth.handle_request(request))
        })
    };

    match response {
        Ok(mut response) => {
            annotate_trusted_callback_url_error(&mut response, callback_detail.as_deref());
            if response.status >= 500 {
                if let Some(error) = internal_auth_error.lock().unwrap().clone() {
                    annotate_internal_auth_error(&mut response, &error);
                }
            }
            sign_session_cookie_response(
                &mut response,
                &instance.session_cookie_name,
                &instance.secret,
            );
            clear_last_error();
            Box::into_raw(Box::new(NativeAuthResponseHandle::from_response(response)))
                .cast::<NativeHttpResponse>()
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

struct BetterAuthInternalErrorLayer {
    error: Arc<Mutex<Option<String>>>,
}

impl<S> Layer<S> for BetterAuthInternalErrorLayer
where
    S: Subscriber,
{
    fn on_event(&self, event: &Event<'_>, _ctx: Context<'_, S>) {
        let mut visitor = InternalErrorVisitor::default();
        event.record(&mut visitor);

        let message_is_internal = visitor
            .message
            .as_deref()
            .is_some_and(|message| message == "Internal server error");
        if !message_is_internal {
            return;
        }

        let Some(error) = visitor.error.or(visitor.message) else {
            return;
        };
        *self.error.lock().unwrap() = Some(error);
    }
}

#[derive(Default)]
struct InternalErrorVisitor {
    error: Option<String>,
    message: Option<String>,
}

impl Visit for InternalErrorVisitor {
    fn record_debug(&mut self, field: &Field, value: &dyn std::fmt::Debug) {
        self.record_value(field, format!("{value:?}"));
    }

    fn record_str(&mut self, field: &Field, value: &str) {
        self.record_value(field, value.to_string());
    }
}

impl InternalErrorVisitor {
    fn record_value(&mut self, field: &Field, value: String) {
        match field.name() {
            "error" => self.error = Some(value),
            "message" => self.message = Some(value),
            _ => {}
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_trusted_admin_call(
    handle: i64,
    operation: *const c_char,
    query_count: usize,
    query: *const NativePair,
    body_ptr: *const u8,
    body_len: usize,
) -> *mut NativeHttpResponse {
    let Some(operation) = (unsafe { read_c_string(operation) }) else {
        set_last_error("Missing trusted admin operation.");
        return std::ptr::null_mut();
    };

    let query = unsafe { read_pairs_map(query, query_count as isize) };
    let body = if body_ptr.is_null() || body_len == 0 {
        None
    } else {
        Some(unsafe { std::slice::from_raw_parts(body_ptr, body_len) }.to_vec())
    };

    let mut instances = INSTANCES.lock().unwrap();
    let Some(instance) = instances.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_auth handle.");
        return std::ptr::null_mut();
    };

    let response = instance.runtime.block_on(instance.auth.trusted_admin_call(
        &instance.admin_config,
        &operation,
        query,
        body,
    ));

    match response {
        Ok(response) => {
            clear_last_error();
            Box::into_raw(Box::new(NativeAuthResponseHandle::from_response(response)))
                .cast::<NativeHttpResponse>()
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_free_response(value: *mut NativeHttpResponse) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = Box::from_raw(value.cast::<NativeAuthResponseHandle>());
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_take_last_error() -> *mut c_char {
    LAST_ERROR
        .lock()
        .unwrap()
        .take()
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

async fn build_auth(
    config: &NativeAuthConfig,
    base_path: &str,
    shared_database: Option<(SharedSqlDialect, SharedSqlCallbacks)>,
) -> Result<NativeAuthBackend, String> {
    let mut auth_config = AuthConfig::new(config.secret.clone())
        .app_name(config.app_name.clone())
        .base_url(config.base_url.clone())
        .base_path(base_path.to_string())
        .password_min_length(config.password_min_length);
    auth_config.session.cookie_name = node_session_cookie_name(&config.base_url);
    auth_config.session.cookie_secure = node_session_cookie_secure(&config.base_url);

    if !config.trusted_origins.is_empty() {
        auth_config = auth_config.trusted_origins(config.trusted_origins.clone());
    }

    let rate_limit = RateLimitConfig::new().enabled(config.enable_rate_limit);

    match &config.database {
        NativeDatabaseConfig::Memory => {
            let builder = configure_builder(
                AuthBuilder::new(auth_config)
                    .database(MemoryDatabaseAdapter::new())
                    .rate_limit(rate_limit.clone()),
                config,
            );
            builder
                .build()
                .await
                .map(NativeAuthBackend::Memory)
                .map_err(|error| error.to_string())
        }
        NativeDatabaseConfig::Postgres { connection_string } => {
            let adapter = SqlxAdapter::new(connection_string)
                .await
                .map_err(|error| error.to_string())?;
            let builder = configure_builder(
                AuthBuilder::new(auth_config)
                    .database(adapter)
                    .rate_limit(rate_limit.clone()),
                config,
            );
            builder
                .build()
                .await
                .map(NativeAuthBackend::Postgres)
                .map_err(|error| error.to_string())
        }
        NativeDatabaseConfig::Sqlite {
            path,
            in_memory,
            manage_migrations,
        } => {
            let adapter = if *in_memory {
                DieselSqliteAdapter::in_memory()
                    .await
                    .map_err(|error| error.to_string())?
            } else {
                let database_url = format!("sqlite://{path}");
                DieselSqliteAdapter::new(&database_url)
                    .await
                    .map_err(|error| error.to_string())?
            };

            if *manage_migrations {
                adapter
                    .run_migrations()
                    .await
                    .map_err(|error| error.to_string())?;
            }

            let builder = configure_builder(
                AuthBuilder::new(auth_config)
                    .database(adapter)
                    .rate_limit(rate_limit.clone()),
                config,
            );
            builder
                .build()
                .await
                .map(NativeAuthBackend::Sqlite)
                .map_err(|error| error.to_string())
        }
        NativeDatabaseConfig::Shared {
            dialect,
            schema,
            manage_migrations,
        } => {
            let Some((shared_dialect, callbacks)) = shared_database else {
                return Err("Missing shared dart_edge_sql callbacks.".to_string());
            };
            if *dialect != native_shared_dialect(shared_dialect) {
                return Err(
                    "Shared database dialect did not match the requested callbacks.".to_string(),
                );
            }
            if shared_dialect == SharedSqlDialect::Sqlite && schema.is_some() {
                return Err(
                    "SQLite auth databases do not support schema-qualified tables.".to_string(),
                );
            }

            let adapter = SharedSqlDatabaseAdapter::new(
                shared_dialect,
                callbacks,
                normalize_database_schema(schema)?,
            );
            if *manage_migrations {
                adapter
                    .run_migrations()
                    .map_err(|error| error.to_string())?;
            }

            let builder = configure_builder(
                AuthBuilder::new(auth_config)
                    .database(adapter)
                    .rate_limit(rate_limit),
                config,
            );
            builder
                .build()
                .await
                .map(NativeAuthBackend::Shared)
                .map_err(|error| error.to_string())
        }
    }
}

fn build_runtime() -> Result<Runtime, std::io::Error> {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
}

impl NativeAuthBackend {
    async fn handle_request(
        &self,
        request: AuthRequest,
    ) -> Result<better_auth::AuthResponse, String> {
        match self {
            NativeAuthBackend::Memory(auth) => auth
                .handle_request(request)
                .await
                .map_err(|error| error.to_string()),
            NativeAuthBackend::Postgres(auth) => auth
                .handle_request(request)
                .await
                .map_err(|error| error.to_string()),
            NativeAuthBackend::Sqlite(auth) => auth
                .handle_request(request)
                .await
                .map_err(|error| error.to_string()),
            NativeAuthBackend::Shared(auth) => auth
                .handle_request(request)
                .await
                .map_err(|error| error.to_string()),
        }
    }

    async fn trusted_admin_call(
        &self,
        config: &NativeAdminConfig,
        operation: &str,
        query: HashMap<String, String>,
        body: Option<Vec<u8>>,
    ) -> Result<AuthResponse, String> {
        let result = match self {
            NativeAuthBackend::Memory(auth) => {
                trusted_admin_call(auth, config, operation, query, body).await
            }
            NativeAuthBackend::Postgres(auth) => {
                trusted_admin_call(auth, config, operation, query, body).await
            }
            NativeAuthBackend::Sqlite(auth) => {
                trusted_admin_call(auth, config, operation, query, body).await
            }
            NativeAuthBackend::Shared(auth) => {
                trusted_admin_call(auth, config, operation, query, body).await
            }
        };

        Ok(match result {
            Ok(response) => response,
            Err(error) => error.into_response(),
        })
    }

    fn openapi_spec(&self) -> better_auth::OpenApiSpec {
        match self {
            NativeAuthBackend::Memory(auth) => auth.openapi_spec(),
            NativeAuthBackend::Postgres(auth) => auth.openapi_spec(),
            NativeAuthBackend::Sqlite(auth) => auth.openapi_spec(),
            NativeAuthBackend::Shared(auth) => auth.openapi_spec(),
        }
    }
}

async fn trusted_admin_call<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    config: &NativeAdminConfig,
    operation: &str,
    query: HashMap<String, String>,
    body: Option<Vec<u8>>,
) -> AuthResult<AuthResponse> {
    match operation {
        "setRole" => {
            let body: TrustedSetRoleRequest = decode_trusted_body(body)?;
            let user = trusted_set_role(auth, &body).await?;
            AuthResponse::json(200, &json!({ "user": user })).map_err(AuthError::from)
        }
        "createUser" => {
            let body: TrustedCreateUserRequest = decode_trusted_body(body)?;
            let user = trusted_create_user(auth, config, &body).await?;
            AuthResponse::json(200, &json!({ "user": user })).map_err(AuthError::from)
        }
        "listUsers" => {
            let response = trusted_list_users(auth, config, query).await?;
            AuthResponse::json(200, &response).map_err(AuthError::from)
        }
        "listUserSessions" => {
            let body: TrustedUserIdRequest = decode_trusted_body(body)?;
            let sessions = trusted_list_user_sessions(auth, &body.user_id).await?;
            AuthResponse::json(200, &json!({ "sessions": sessions })).map_err(AuthError::from)
        }
        "banUser" => {
            let body: TrustedBanUserRequest = decode_trusted_body(body)?;
            let user = trusted_ban_user(auth, config, &body).await?;
            AuthResponse::json(200, &json!({ "user": user })).map_err(AuthError::from)
        }
        "unbanUser" => {
            let body: TrustedUserIdRequest = decode_trusted_body(body)?;
            let user = trusted_unban_user(auth, &body.user_id).await?;
            AuthResponse::json(200, &json!({ "user": user })).map_err(AuthError::from)
        }
        "impersonateUser" => {
            let body: TrustedImpersonateUserRequest = decode_trusted_body(body)?;
            let response = trusted_impersonate_user(auth, &body).await?;
            AuthResponse::json(200, &response).map_err(AuthError::from)
        }
        "stopImpersonating" => {
            let body: TrustedStopImpersonatingRequest = decode_trusted_body(body)?;
            let response = trusted_stop_impersonating(auth, &body).await?;
            AuthResponse::json(200, &response).map_err(AuthError::from)
        }
        "revokeUserSession" => {
            let body: TrustedRevokeSessionRequest = decode_trusted_body(body)?;
            auth.session_manager()
                .delete_session(&body.session_token)
                .await?;
            AuthResponse::json(200, &json!({ "success": true })).map_err(AuthError::from)
        }
        "revokeUserSessions" => {
            let body: TrustedUserIdRequest = decode_trusted_body(body)?;
            let _target = auth
                .database()
                .get_user_by_id(&body.user_id)
                .await?
                .ok_or_else(|| AuthError::not_found("User not found"))?;
            auth.session_manager()
                .revoke_all_user_sessions(&body.user_id)
                .await?;
            AuthResponse::json(200, &json!({ "success": true })).map_err(AuthError::from)
        }
        "removeUser" => {
            let body: TrustedUserIdRequest = decode_trusted_body(body)?;
            trusted_remove_user(auth, &body.user_id).await?;
            AuthResponse::json(200, &json!({ "success": true })).map_err(AuthError::from)
        }
        "setUserPassword" => {
            let body: TrustedSetUserPasswordRequest = decode_trusted_body(body)?;
            trusted_set_user_password(auth, &body).await?;
            AuthResponse::json(200, &json!({ "status": true })).map_err(AuthError::from)
        }
        "hasPermission" => {
            let body: TrustedHasPermissionRequest = decode_trusted_body(body)?;
            let response = trusted_has_permission(auth, config, &body).await?;
            AuthResponse::json(200, &response).map_err(AuthError::from)
        }
        _ => Err(AuthError::not_found(format!(
            "Unknown trusted admin operation: {operation}"
        ))),
    }
}

fn decode_trusted_body<T: for<'de> Deserialize<'de>>(body: Option<Vec<u8>>) -> AuthResult<T> {
    let Some(body) = body else {
        return Err(AuthError::bad_request("Missing trusted admin request body"));
    };
    serde_json::from_slice(&body).map_err(|error| {
        AuthError::bad_request(format!("Invalid trusted admin request body: {error}"))
    })
}

async fn trusted_set_role<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    body: &TrustedSetRoleRequest,
) -> AuthResult<DB::User> {
    let _target = auth
        .database()
        .get_user_by_id(&body.user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;

    auth.database()
        .update_user(
            &body.user_id,
            UpdateUser {
                role: Some(body.role.clone()),
                ..Default::default()
            },
        )
        .await
}

async fn trusted_create_user<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    config: &NativeAdminConfig,
    body: &TrustedCreateUserRequest,
) -> AuthResult<DB::User> {
    if auth
        .database()
        .get_user_by_email(&body.email)
        .await?
        .is_some()
    {
        return Err(AuthError::conflict("A user with this email already exists"));
    }

    if body.password.len() < auth.config().password.min_length {
        return Err(AuthError::bad_request(format!(
            "Password must be at least {} characters long",
            auth.config().password.min_length
        )));
    }

    let password_hash = PASSWORD_HASHER.hash(&body.password).await?;
    let role = body
        .role
        .clone()
        .unwrap_or_else(|| config.default_user_role.clone());
    let metadata = metadata_with_password_hash(body.data.clone(), &password_hash);

    let user = auth
        .database()
        .create_user(
            better_auth::CreateUser::new()
                .with_email(&body.email)
                .with_name(&body.name)
                .with_role(role)
                .with_email_verified(true)
                .with_metadata(metadata),
        )
        .await?;

    auth.database()
        .create_account(CreateAccount {
            user_id: user.id().to_string(),
            account_id: user.id().to_string(),
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

    Ok(user)
}

async fn trusted_list_users<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    config: &NativeAdminConfig,
    query: HashMap<String, String>,
) -> AuthResult<serde_json::Value> {
    let limit = query
        .get("limit")
        .and_then(|value| value.parse().ok())
        .unwrap_or(config.default_page_limit)
        .min(config.max_page_limit);
    let offset = query
        .get("offset")
        .and_then(|value| value.parse().ok())
        .unwrap_or(0);

    let (users, total) = auth
        .database()
        .list_users(ListUsersParams {
            limit: Some(limit),
            offset: Some(offset),
            search_field: query.get("searchField").cloned(),
            search_value: query.get("searchValue").cloned(),
            search_operator: query.get("searchOperator").cloned(),
            sort_by: query.get("sortBy").cloned(),
            sort_direction: query.get("sortDirection").cloned(),
            filter_field: query.get("filterField").cloned(),
            filter_value: query.get("filterValue").cloned(),
            filter_operator: query.get("filterOperator").cloned(),
        })
        .await?;

    Ok(json!({
        "users": users,
        "total": total,
        "limit": limit,
        "offset": offset,
    }))
}

async fn trusted_list_user_sessions<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    user_id: &str,
) -> AuthResult<Vec<DB::Session>> {
    let _target = auth
        .database()
        .get_user_by_id(user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;
    auth.session_manager().list_user_sessions(user_id).await
}

async fn trusted_ban_user<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    config: &NativeAdminConfig,
    body: &TrustedBanUserRequest,
) -> AuthResult<DB::User> {
    let target = auth
        .database()
        .get_user_by_id(&body.user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;

    if !config.allow_ban_admin && target.role().unwrap_or("user") == config.admin_role {
        return Err(AuthError::forbidden("Cannot ban an admin user"));
    }

    let ban_expires = body
        .ban_expires_in
        .and_then(Duration::try_seconds)
        .map(|duration| Utc::now() + duration);

    let updated_user = auth
        .database()
        .update_user(
            &body.user_id,
            UpdateUser {
                banned: Some(true),
                ban_reason: body.ban_reason.clone(),
                ban_expires,
                ..Default::default()
            },
        )
        .await?;

    auth.session_manager()
        .revoke_all_user_sessions(&body.user_id)
        .await?;

    Ok(updated_user)
}

async fn trusted_unban_user<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    user_id: &str,
) -> AuthResult<DB::User> {
    let _target = auth
        .database()
        .get_user_by_id(user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;

    auth.database()
        .update_user(
            user_id,
            UpdateUser {
                banned: Some(false),
                ban_reason: None,
                ban_expires: None,
                ..Default::default()
            },
        )
        .await
}

async fn trusted_impersonate_user<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    body: &TrustedImpersonateUserRequest,
) -> AuthResult<serde_json::Value> {
    if body.user_id == body.impersonated_by_user_id {
        return Err(AuthError::bad_request("Cannot impersonate yourself"));
    }

    let target = auth
        .database()
        .get_user_by_id(&body.user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;
    let _admin = auth
        .database()
        .get_user_by_id(&body.impersonated_by_user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("Impersonating user not found"))?;

    let session = auth
        .database()
        .create_session(CreateSession {
            user_id: target.id().to_string(),
            expires_at: Utc::now() + auth.config().session.expires_in,
            ip_address: body.ip_address.clone(),
            user_agent: body.user_agent.clone(),
            impersonated_by: Some(body.impersonated_by_user_id.clone()),
            active_organization_id: None,
        })
        .await?;

    Ok(json!({ "session": session, "user": target }))
}

async fn trusted_stop_impersonating<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    body: &TrustedStopImpersonatingRequest,
) -> AuthResult<serde_json::Value> {
    let session = auth
        .database()
        .get_session(&body.session_token)
        .await?
        .ok_or(AuthError::Unauthenticated)?;
    let admin_id = session
        .impersonated_by()
        .ok_or_else(|| AuthError::bad_request("Current session is not an impersonation session"))?
        .to_string();

    auth.session_manager()
        .delete_session(&body.session_token)
        .await?;

    let admin_user = auth
        .database()
        .get_user_by_id(&admin_id)
        .await?
        .ok_or(AuthError::UserNotFound)?;
    let admin_session = auth
        .database()
        .create_session(CreateSession {
            user_id: admin_id,
            expires_at: Utc::now() + auth.config().session.expires_in,
            ip_address: body.ip_address.clone(),
            user_agent: body.user_agent.clone(),
            impersonated_by: None,
            active_organization_id: None,
        })
        .await?;

    Ok(json!({ "session": admin_session, "user": admin_user }))
}

async fn trusted_remove_user<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    user_id: &str,
) -> AuthResult<()> {
    let _target = auth
        .database()
        .get_user_by_id(user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;

    auth.database().delete_user_sessions(user_id).await?;
    let accounts = auth.database().get_user_accounts(user_id).await?;
    for account in &accounts {
        auth.database().delete_account(account.id()).await?;
    }
    auth.database().delete_user(user_id).await
}

async fn trusted_set_user_password<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    body: &TrustedSetUserPasswordRequest,
) -> AuthResult<()> {
    if body.new_password.len() < auth.config().password.min_length {
        return Err(AuthError::bad_request(format!(
            "Password must be at least {} characters long",
            auth.config().password.min_length
        )));
    }

    let user = auth
        .database()
        .get_user_by_id(&body.user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;
    let password_hash = PASSWORD_HASHER.hash(&body.new_password).await?;

    auth.database()
        .update_user(
            &body.user_id,
            UpdateUser {
                metadata: Some(metadata_with_password_hash(
                    Some(user.metadata().clone()),
                    &password_hash,
                )),
                ..Default::default()
            },
        )
        .await?;

    let accounts = auth.database().get_user_accounts(&body.user_id).await?;
    if let Some(account) = accounts
        .iter()
        .find(|account| account.provider_id() == "credential")
    {
        auth.database()
            .update_account(
                account.id(),
                UpdateAccount {
                    password: Some(password_hash),
                    ..Default::default()
                },
            )
            .await?;
    } else {
        auth.database()
            .create_account(CreateAccount {
                user_id: body.user_id.clone(),
                account_id: body.user_id.clone(),
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

    Ok(())
}

async fn trusted_has_permission<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    config: &NativeAdminConfig,
    body: &TrustedHasPermissionRequest,
) -> AuthResult<serde_json::Value> {
    let _permissions = body.permissions.clone().or(body.permission.clone());
    let user = auth
        .database()
        .get_user_by_id(&body.user_id)
        .await?
        .ok_or_else(|| AuthError::not_found("User not found"))?;

    if user.role().unwrap_or("user") == config.admin_role {
        Ok(json!({ "success": true, "error": null }))
    } else {
        Ok(json!({
            "success": false,
            "error": "User does not have the required permissions",
        }))
    }
}

fn metadata_with_password_hash(
    metadata: Option<serde_json::Value>,
    password_hash: &str,
) -> serde_json::Value {
    let mut obj = match metadata {
        Some(serde_json::Value::Object(obj)) => obj,
        _ => serde_json::Map::new(),
    };
    obj.insert(
        PASSWORD_HASH_KEY.to_string(),
        serde_json::json!(password_hash),
    );
    serde_json::Value::Object(obj)
}

fn decode_shared_dialect(value: i32) -> Option<SharedSqlDialect> {
    SharedSqlDialect::from_native_code(value)
}

fn native_shared_dialect(value: SharedSqlDialect) -> NativeSharedSqlDialect {
    match value {
        SharedSqlDialect::Postgres => NativeSharedSqlDialect::Postgres,
        SharedSqlDialect::Sqlite => NativeSharedSqlDialect::Sqlite,
    }
}

fn configure_builder<DB: DatabaseAdapter>(
    mut builder: TypedAuthBuilder<DB>,
    config: &NativeAuthConfig,
) -> TypedAuthBuilder<DB> {
    if config.enable_email_password {
        builder = builder.plugin(
            EmailPasswordPlugin::new()
                .enable_signup(config.enable_signup)
                .password_hasher(PASSWORD_HASHER.clone()),
        );
    }
    if config.enable_session_management {
        builder = builder.plugin(SessionManagementPlugin::new());
    }
    if config.enable_password_management {
        builder = builder.plugin(PasswordManagementPlugin::with_config(
            PasswordManagementConfig {
                password_hasher: Some(PASSWORD_HASHER.clone()),
                ..Default::default()
            },
        ));
    }
    if config.enable_account_management {
        builder = builder.plugin(AccountManagementPlugin::new());
    }
    if config.enable_email_verification {
        builder = builder.plugin(EmailVerificationPlugin::new());
    }
    builder = builder.plugin(OAuthPlugin::with_config(oauth_config(
        &config.oauth_providers,
    )));
    if let Some(admin) = &config.admin {
        builder = builder.plugin(
            AdminPlugin::new()
                .admin_role(admin.admin_role.clone())
                .default_user_role(admin.default_user_role.clone())
                .allow_ban_admin(admin.allow_ban_admin)
                .default_page_limit(admin.default_page_limit)
                .max_page_limit(admin.max_page_limit),
        );
    }
    builder
}

fn oauth_config(providers: &[NativeOAuthProviderConfig]) -> OAuthConfig {
    let mut config = OAuthConfig::default();
    for provider in providers {
        config.providers.insert(
            provider.provider_id.clone(),
            OAuthProvider {
                client_id: provider.client_id.clone(),
                client_secret: provider.client_secret.clone(),
                auth_url: provider.authorization_url.clone(),
                token_url: provider.token_url.clone(),
                user_info_url: provider.user_info_url.clone(),
                scopes: provider.scopes.clone(),
                map_user_info: map_generic_oauth_user_info,
            },
        );
    }
    config
}

fn map_generic_oauth_user_info(value: serde_json::Value) -> Result<OAuthUserInfo, String> {
    Ok(OAuthUserInfo {
        id: json_string_field(&value, "sub")
            .or_else(|| json_string_field(&value, "oid"))
            .or_else(|| json_string_field(&value, "id"))
            .ok_or_else(|| "missing sub, oid, or id".to_string())?,
        email: json_string_field(&value, "email")
            .or_else(|| json_string_field(&value, "mail"))
            .or_else(|| json_string_field(&value, "userPrincipalName"))
            .or_else(|| json_string_field(&value, "preferred_username"))
            .or_else(|| json_string_field(&value, "upn"))
            .ok_or_else(|| {
                "missing email, mail, userPrincipalName, preferred_username, or upn".to_string()
            })?,
        name: json_string_field(&value, "name")
            .or_else(|| json_string_field(&value, "displayName"))
            .or_else(|| json_string_field(&value, "given_name")),
        image: json_string_field(&value, "picture")
            .or_else(|| json_string_field(&value, "avatar_url")),
        email_verified: json_bool_field(&value, "email_verified")
            .or_else(|| json_bool_field(&value, "verified"))
            .unwrap_or(false),
    })
}

fn json_string_field(value: &serde_json::Value, field: &str) -> Option<String> {
    value
        .get(field)
        .and_then(|raw| raw.as_str().map(str::to_string))
        .or_else(|| {
            value
                .get(field)
                .and_then(|raw| raw.as_i64().map(|id| id.to_string()))
        })
}

fn json_bool_field(value: &serde_json::Value, field: &str) -> Option<bool> {
    value.get(field).and_then(|raw| raw.as_bool())
}

fn default_oauth_scopes() -> Vec<String> {
    vec![
        "openid".to_string(),
        "email".to_string(),
        "profile".to_string(),
    ]
}

fn default_database() -> NativeDatabaseConfig {
    NativeDatabaseConfig::Memory
}

fn default_manage_migrations() -> bool {
    false
}

fn normalize_database_schema(value: &Option<String>) -> Result<Option<String>, String> {
    let Some(value) = value else {
        return Ok(None);
    };

    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }

    if !trimmed
        .chars()
        .all(|char| char == '_' || char.is_ascii_alphanumeric())
    {
        return Err(format!(
            "Unsupported database schema name \"{trimmed}\". Use only ASCII letters, digits, and underscores."
        ));
    }

    Ok(Some(trimmed.to_string()))
}

fn node_session_cookie_secure(base_url: &str) -> bool {
    base_url.trim_start().starts_with("https://")
}

fn node_session_cookie_name(base_url: &str) -> String {
    if node_session_cookie_secure(base_url) {
        format!("{SECURE_COOKIE_PREFIX}{NODE_SESSION_COOKIE_NAME}")
    } else {
        NODE_SESSION_COOKIE_NAME.to_string()
    }
}

fn normalize_session_cookie_header(
    headers: &mut HashMap<String, String>,
    session_cookie_name: &str,
    secret: &str,
) {
    let Some(cookie_header) = header_value(headers, "cookie").map(str::to_string) else {
        return;
    };
    let Some(value) = session_cookie_aliases(session_cookie_name)
        .into_iter()
        .find_map(|name| cookie_value(&cookie_header, &name))
    else {
        return;
    };

    let token = normalize_node_session_cookie_value(&value, secret);
    let token = encode_cookie_value(&token);
    headers.insert(
        "cookie".to_string(),
        format!("{session_cookie_name}={token}; {cookie_header}"),
    );
}

fn normalize_session_auth_headers(
    headers: &mut HashMap<String, String>,
    session_cookie_name: &str,
    secret: &str,
) {
    normalize_session_authorization_header(headers, secret);
    normalize_session_cookie_header(headers, session_cookie_name, secret);
}

fn normalize_session_authorization_header(headers: &mut HashMap<String, String>, secret: &str) {
    let Some(header_name) = headers
        .keys()
        .find(|name| name.eq_ignore_ascii_case("authorization"))
        .cloned()
    else {
        return;
    };
    let Some(value) = headers.get(&header_name).cloned() else {
        return;
    };
    let trimmed = value.trim();
    let Some(token) = trimmed
        .strip_prefix("Bearer ")
        .or_else(|| trimmed.strip_prefix("bearer "))
    else {
        return;
    };

    let normalized = normalize_node_session_cookie_value(token.trim(), secret);
    headers.insert(header_name, format!("Bearer {normalized}"));
}

fn sign_session_cookie_response(
    response: &mut better_auth::AuthResponse,
    session_cookie_name: &str,
    secret: &str,
) {
    let Some(header_name) = response
        .headers
        .keys()
        .find(|name| name.eq_ignore_ascii_case("set-cookie"))
        .cloned()
    else {
        return;
    };

    let Some(header) = response.headers.get(&header_name).cloned() else {
        return;
    };
    let Some((name_value, attributes)) = header.split_once(';') else {
        rewrite_session_cookie_response_header(
            response,
            header_name,
            &header,
            "",
            session_cookie_name,
            secret,
        );
        return;
    };

    rewrite_session_cookie_response_header(
        response,
        header_name,
        name_value,
        attributes,
        session_cookie_name,
        secret,
    );
}

fn rewrite_session_cookie_response_header(
    response: &mut better_auth::AuthResponse,
    header_name: String,
    name_value: &str,
    attributes: &str,
    session_cookie_name: &str,
    secret: &str,
) {
    let Some((name, value)) = name_value.split_once('=') else {
        return;
    };
    let name = name.trim();
    if !is_session_cookie_name(name, session_cookie_name) {
        return;
    }

    let value = value.trim();
    let encoded_value = if value.is_empty() {
        String::new()
    } else {
        let token = normalize_node_session_cookie_value(value, secret);
        let signed = sign_node_session_cookie_value(&token, secret);
        encode_cookie_value(&signed)
    };

    let rewritten = if attributes.is_empty() {
        format!("{session_cookie_name}={encoded_value}")
    } else {
        format!("{session_cookie_name}={encoded_value};{attributes}")
    };
    response.headers.insert(header_name, rewritten);
}

fn header_value<'a>(headers: &'a HashMap<String, String>, name: &str) -> Option<&'a str> {
    headers
        .iter()
        .find(|(key, _)| key.eq_ignore_ascii_case(name))
        .map(|(_, value)| value.as_str())
}

fn cookie_value(cookie_header: &str, name: &str) -> Option<String> {
    for part in cookie_header.split(';') {
        let trimmed = part.trim();
        let Some((cookie_name, value)) = trimmed.split_once('=') else {
            continue;
        };
        if cookie_name.trim() == name && !value.trim().is_empty() {
            return Some(value.trim().to_string());
        }
    }

    None
}

fn normalize_node_session_cookie_value(value: &str, secret: &str) -> String {
    let decoded = percent_decode(value).unwrap_or_else(|| value.to_string());
    verify_node_signed_cookie_value(&decoded, secret).unwrap_or(decoded)
}

fn sign_node_session_cookie_value(value: &str, secret: &str) -> String {
    let mut mac =
        HmacSha256::new_from_slice(secret.as_bytes()).expect("HMAC accepts keys of any size");
    mac.update(value.as_bytes());
    let signature = BASE64_STANDARD.encode(mac.finalize().into_bytes());
    format!("{value}.{signature}")
}

fn verify_node_signed_cookie_value(value: &str, secret: &str) -> Option<String> {
    let signature_start = value.rfind('.')?;
    if signature_start < 1 {
        return None;
    }

    let signed_value = &value[..signature_start];
    let signature = &value[signature_start + 1..];
    if signature.len() != 44 || !signature.ends_with('=') {
        return None;
    }

    let signature = BASE64_STANDARD.decode(signature).ok()?;
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes()).ok()?;
    mac.update(signed_value.as_bytes());
    mac.verify_slice(&signature).ok()?;
    Some(signed_value.to_string())
}

fn session_cookie_aliases(session_cookie_name: &str) -> Vec<String> {
    let mut names = Vec::new();
    push_unique(&mut names, session_cookie_name);
    for name in [
        NODE_SESSION_COOKIE_NAME,
        NODE_DASH_SESSION_COOKIE_NAME,
        RUST_SESSION_COOKIE_NAME,
    ] {
        push_unique(&mut names, name);
        push_unique(&mut names, &format!("{SECURE_COOKIE_PREFIX}{name}"));
        push_unique(&mut names, &format!("{HOST_COOKIE_PREFIX}{name}"));
    }
    names
}

fn is_session_cookie_name(name: &str, session_cookie_name: &str) -> bool {
    session_cookie_aliases(session_cookie_name)
        .into_iter()
        .any(|candidate| candidate == name)
}

fn push_unique(values: &mut Vec<String>, value: &str) {
    if !values.iter().any(|candidate| candidate == value) {
        values.push(value.to_string());
    }
}

fn encode_cookie_value(value: &str) -> String {
    let mut encoded = String::with_capacity(value.len());
    for byte in value.bytes() {
        if is_encode_uri_component_unescaped(byte) {
            encoded.push(byte as char);
        } else {
            encoded.push_str(&format!("%{byte:02X}"));
        }
    }
    encoded
}

fn is_encode_uri_component_unescaped(byte: u8) -> bool {
    byte.is_ascii_alphanumeric()
        || matches!(
            byte,
            b'-' | b'_' | b'.' | b'!' | b'~' | b'*' | b'\'' | b'(' | b')'
        )
}

fn trusted_callback_url_rejection_detail(
    query: &HashMap<String, String>,
    body: Option<&[u8]>,
) -> Option<String> {
    let callback_url =
        trusted_callback_url_from_body(body).or_else(|| query.get("callbackURL").cloned())?;
    let callback_url = callback_url.trim();
    if callback_url.is_empty() {
        return Some("callbackURL is empty".to_string());
    }
    if let Some(origin) = extract_origin(callback_url) {
        return Some(format!("rejected origin: {origin}"));
    }

    if let Some(decoded_callback_url) = percent_decode(callback_url)
        && let Some(origin) = extract_origin(&decoded_callback_url)
    {
        return Some(format!(
            "callbackURL appears to be URL-encoded; decoded origin would be {origin}; received callbackURL: {}",
            debug_callback_url(callback_url),
        ));
    }

    Some(format!(
        "callbackURL did not contain an absolute http(s) origin; received callbackURL: {}",
        debug_callback_url(callback_url),
    ))
}

fn trusted_callback_url_from_body(body: Option<&[u8]>) -> Option<String> {
    let value = serde_json::from_slice::<serde_json::Value>(body?).ok()?;
    value.get("callbackURL")?.as_str().map(str::to_string)
}

fn percent_decode(value: &str) -> Option<String> {
    if !value.contains('%') {
        return None;
    }

    let mut decoded = Vec::with_capacity(value.len());
    let bytes = value.as_bytes();
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%'
            && index + 2 < bytes.len()
            && let (Some(high), Some(low)) =
                (hex_value(bytes[index + 1]), hex_value(bytes[index + 2]))
        {
            decoded.push((high << 4) | low);
            index += 3;
            continue;
        }
        decoded.push(bytes[index]);
        index += 1;
    }

    Some(String::from_utf8_lossy(&decoded).into_owned())
}

fn hex_value(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}

fn debug_callback_url(value: &str) -> String {
    const MAX_DEBUG_CALLBACK_URL_LEN: usize = 160;
    let sanitized = value
        .chars()
        .map(|char| if char.is_control() { ' ' } else { char })
        .collect::<String>();
    if sanitized.chars().count() <= MAX_DEBUG_CALLBACK_URL_LEN {
        return format!("\"{sanitized}\"");
    }

    let truncated = sanitized
        .chars()
        .take(MAX_DEBUG_CALLBACK_URL_LEN)
        .collect::<String>();
    format!("\"{truncated}...\"")
}

fn annotate_trusted_callback_url_error(
    response: &mut better_auth::AuthResponse,
    detail: Option<&str>,
) {
    let Some(detail) = detail else {
        return;
    };
    if response.status != 400 {
        return;
    }

    let Ok(mut value) = serde_json::from_slice::<serde_json::Value>(&response.body) else {
        return;
    };
    let Some(object) = value.as_object_mut() else {
        return;
    };
    if object.get("message").and_then(serde_json::Value::as_str)
        != Some(TRUSTED_CALLBACK_URL_ERROR_MESSAGE)
    {
        return;
    }

    object.insert(
        "message".to_string(),
        serde_json::Value::String(format!("{TRUSTED_CALLBACK_URL_ERROR_MESSAGE} ({detail}).")),
    );
    if let Ok(body) = serde_json::to_vec(&value) {
        response.body = body;
    }
}

fn annotate_internal_auth_error(response: &mut better_auth::AuthResponse, error: &str) {
    let Ok(mut value) = serde_json::from_slice::<serde_json::Value>(&response.body) else {
        return;
    };
    let Some(object) = value.as_object_mut() else {
        return;
    };

    object.insert(
        "internal_error".to_string(),
        serde_json::Value::String(error.to_string()),
    );
    if let Ok(body) = serde_json::to_vec(&value) {
        response.body = body;
    }
}

impl NativeAuthResponseHandle {
    fn from_response(response: better_auth::AuthResponse) -> Self {
        let content_type = response_content_type(&response.headers);
        let body = OwnedBytes::from_vec(response.body);
        let headers = response
            .headers
            .into_iter()
            .filter(|(name, _)| !name.eq_ignore_ascii_case("content-type"))
            .map(|(name, value)| OwnedPair::new(name, value))
            .collect::<Vec<_>>();
        let header_pairs = native_pairs_from_owned(&headers);
        let content_type = OwnedBytes::from_vec(content_type.into_bytes());

        let native = NativeHttpResponse {
            status: response.status,
            content_type: content_type.as_native(),
            header_count: header_pairs.len() as isize,
            headers: boxed_pairs_ptr(&header_pairs),
            body: body.as_native(),
        };

        Self {
            response: native,
            content_type,
            headers,
            header_pairs,
            body,
        }
    }
}

fn response_content_type(headers: &HashMap<String, String>) -> String {
    headers
        .iter()
        .find(|(name, _)| name.eq_ignore_ascii_case("content-type"))
        .map(|(_, value)| value.clone())
        .unwrap_or_else(|| "application/json; charset=utf-8".to_string())
}

fn decode_method(method: NativeHttpMethod) -> HttpMethod {
    match method {
        NativeHttpMethod::Get => HttpMethod::Get,
        NativeHttpMethod::Post => HttpMethod::Post,
        NativeHttpMethod::Put => HttpMethod::Put,
        NativeHttpMethod::Patch => HttpMethod::Patch,
        NativeHttpMethod::Delete => HttpMethod::Delete,
        NativeHttpMethod::Head => HttpMethod::Head,
        NativeHttpMethod::Options => HttpMethod::Options,
    }
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

fn set_last_error(message: impl Into<String>) {
    let sanitized = message.into().replace('\0', " ");
    *LAST_ERROR.lock().unwrap() = CString::new(sanitized).ok();
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn maps_microsoft_graph_user_info() {
        let user = map_generic_oauth_user_info(json!({
            "id": "graph-user-id",
            "userPrincipalName": "ada@example.com",
            "displayName": "Ada Lovelace"
        }))
        .expect("Microsoft Graph user info should map");

        assert_eq!(user.id, "graph-user-id");
        assert_eq!(user.email, "ada@example.com");
        assert_eq!(user.name.as_deref(), Some("Ada Lovelace"));
    }

    #[test]
    fn maps_microsoft_oidc_user_info() {
        let user = map_generic_oauth_user_info(json!({
            "oid": "entra-object-id",
            "preferred_username": "grace@example.com",
            "name": "Grace Hopper"
        }))
        .expect("Microsoft OIDC user info should map");

        assert_eq!(user.id, "entra-object-id");
        assert_eq!(user.email, "grace@example.com");
        assert_eq!(user.name.as_deref(), Some("Grace Hopper"));
    }
}
