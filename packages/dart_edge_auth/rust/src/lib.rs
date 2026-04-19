use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use better_auth::adapters::{DatabaseAdapter, MemoryDatabaseAdapter, SqlxAdapter};
use better_auth::core_paths;
use better_auth::plugins::{
    AccountManagementPlugin, AdminPlugin, EmailPasswordPlugin, EmailVerificationPlugin,
    PasswordManagementPlugin, SessionManagementPlugin,
};
use better_auth::{
    AuthBuilder, AuthConfig, AuthRequest, BetterAuth, HttpMethod, RateLimitConfig,
    TypedAuthBuilder,
};
use better_auth_diesel_sqlite::DieselSqliteAdapter;
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use serde_json::json;
use shared_sql_adapter::{SharedSqlCallbacks, SharedSqlDatabaseAdapter, SharedSqlDialect};
use tokio::runtime::Runtime;

mod shared_sql_adapter;

const DART_EDGE_AUTH_NATIVE_ABI_VERSION: i32 = 1;

static NEXT_INSTANCE_ID: AtomicI64 = AtomicI64::new(1);
static INSTANCES: Lazy<Mutex<HashMap<i64, AuthInstance>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

struct AuthInstance {
    base_path: String,
    runtime: Runtime,
    auth: NativeAuthBackend,
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
pub struct NativeBytes {
    ptr: *const u8,
    len: isize,
}

#[repr(C)]
pub struct NativePair {
    key: NativeBytes,
    value: NativeBytes,
}

#[repr(C)]
pub struct NativeAuthResponse {
    status: u16,
    content_type: NativeBytes,
    header_count: isize,
    headers: *const NativePair,
    body: NativeBytes,
}

struct OwnedBytes {
    bytes: Box<[u8]>,
}

struct OwnedPair {
    key: OwnedBytes,
    value: OwnedBytes,
}

#[repr(C)]
struct NativeAuthResponseHandle {
    response: NativeAuthResponse,
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
    admin: Option<NativeAdminConfig>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeAdminConfig {
    admin_role: String,
    default_user_role: String,
    allow_ban_admin: bool,
    default_page_limit: usize,
    max_page_limit: usize,
}

#[derive(Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
enum NativeDatabaseConfig {
    Memory,
    Postgres { connection_string: String },
    Sqlite {
        path: String,
        #[serde(rename = "inMemory")]
        in_memory: bool,
        #[serde(default = "default_manage_migrations")]
        manage_migrations: bool,
    },
    Shared {
        dialect: NativeSharedSqlDialect,
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

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ListedRoute {
    method: String,
    path: String,
    operation_id: String,
    accepts_json_body: bool,
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
            set_last_error(format!("Unsupported shared database dialect code: {dialect}"));
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

    let routes = list_routes(instance);
    let json = match serde_json::to_string(&routes) {
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
    method: i32,
    path: *const c_char,
    query_count: isize,
    query: *const NativePair,
    header_count: isize,
    headers: *const NativePair,
    body_ptr: *const u8,
    body_len: isize,
) -> *mut NativeAuthResponse {
    let Some(path) = (unsafe { read_c_string(path) }) else {
        set_last_error("Missing auth request path.");
        return std::ptr::null_mut();
    };

    let method = match decode_method(method) {
        Some(method) => method,
        None => {
            set_last_error(format!("Unsupported auth method code: {method}"));
            return std::ptr::null_mut();
        }
    };

    let query = unsafe { read_pairs(query, query_count) };
    let headers = unsafe { read_pairs(headers, header_count) };
    let body = unsafe { read_bytes(body_ptr, body_len) };

    let mut instances = INSTANCES.lock().unwrap();
    let Some(instance) = instances.get_mut(&handle) else {
        set_last_error("Unknown dart_edge_auth handle.");
        return std::ptr::null_mut();
    };

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
        instance
            .runtime
            .block_on(instance.auth.handle_request(request))
    };

    match response {
        Ok(response) => {
            clear_last_error();
            Box::into_raw(Box::new(NativeAuthResponseHandle::from_response(response)))
                .cast::<NativeAuthResponse>()
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_auth_free_response(value: *mut NativeAuthResponse) {
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
            manage_migrations,
        } => {
            let Some((shared_dialect, callbacks)) = shared_database else {
                return Err("Missing shared dart_edge_sql callbacks.".to_string());
            };
            if *dialect != native_shared_dialect(shared_dialect) {
                return Err("Shared database dialect did not match the requested callbacks."
                    .to_string());
            }

            let adapter = SharedSqlDatabaseAdapter::new(shared_dialect, callbacks);
            if *manage_migrations {
                adapter.run_migrations().map_err(|error| error.to_string())?;
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

fn list_routes(instance: &AuthInstance) -> Vec<ListedRoute> {
    let mut routes = vec![
        ListedRoute::new(
            "GET",
            join_path(&instance.base_path, core_paths::OK),
            "ok",
            false,
        ),
        ListedRoute::new(
            "GET",
            join_path(&instance.base_path, core_paths::ERROR),
            "error",
            false,
        ),
        ListedRoute::new(
            "GET",
            join_path(&instance.base_path, "/health"),
            "health",
            false,
        ),
        ListedRoute::new(
            "GET",
            join_path(&instance.base_path, core_paths::OPENAPI_SPEC),
            "openapi_spec",
            false,
        ),
        ListedRoute::new(
            "POST",
            join_path(&instance.base_path, core_paths::UPDATE_USER),
            "update_user",
            true,
        ),
        ListedRoute::new(
            "POST",
            join_path(&instance.base_path, core_paths::DELETE_USER),
            "delete_user_post",
            true,
        ),
        ListedRoute::new(
            "DELETE",
            join_path(&instance.base_path, core_paths::DELETE_USER),
            "delete_user_delete",
            true,
        ),
        ListedRoute::new(
            "POST",
            join_path(&instance.base_path, core_paths::CHANGE_EMAIL),
            "change_email",
            true,
        ),
        ListedRoute::new(
            "GET",
            join_path(&instance.base_path, core_paths::DELETE_USER_CALLBACK),
            "delete_user_callback",
            false,
        ),
    ];

    instance
        .auth
        .append_plugin_routes(&mut routes, &instance.base_path);

    routes
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

    fn append_plugin_routes(&self, routes: &mut Vec<ListedRoute>, base_path: &str) {
        match self {
            NativeAuthBackend::Memory(auth) => append_plugin_routes(auth, routes, base_path),
            NativeAuthBackend::Postgres(auth) => append_plugin_routes(auth, routes, base_path),
            NativeAuthBackend::Sqlite(auth) => append_plugin_routes(auth, routes, base_path),
            NativeAuthBackend::Shared(auth) => append_plugin_routes(auth, routes, base_path),
        }
    }
}

fn decode_shared_dialect(value: i32) -> Option<SharedSqlDialect> {
    match value {
        0 => Some(SharedSqlDialect::Postgres),
        1 => Some(SharedSqlDialect::Sqlite),
        _ => None,
    }
}

fn native_shared_dialect(value: SharedSqlDialect) -> NativeSharedSqlDialect {
    match value {
        SharedSqlDialect::Postgres => NativeSharedSqlDialect::Postgres,
        SharedSqlDialect::Sqlite => NativeSharedSqlDialect::Sqlite,
    }
}

fn append_plugin_routes<DB: DatabaseAdapter>(
    auth: &BetterAuth<DB>,
    routes: &mut Vec<ListedRoute>,
    base_path: &str,
) {
    for plugin in auth.plugins() {
        for route in plugin.routes() {
            routes.push(ListedRoute {
                method: http_method_name(&route.method).to_string(),
                path: join_path(base_path, &route.path),
                operation_id: route.operation_id,
                accepts_json_body: accepts_json_body(&route.method),
            });
        }
    }
}

fn configure_builder<DB: DatabaseAdapter>(
    mut builder: TypedAuthBuilder<DB>,
    config: &NativeAuthConfig,
) -> TypedAuthBuilder<DB> {
    if config.enable_email_password {
        builder = builder.plugin(EmailPasswordPlugin::new().enable_signup(config.enable_signup));
    }
    if config.enable_session_management {
        builder = builder.plugin(SessionManagementPlugin::new());
    }
    if config.enable_password_management {
        builder = builder.plugin(PasswordManagementPlugin::new());
    }
    if config.enable_account_management {
        builder = builder.plugin(AccountManagementPlugin::new());
    }
    if config.enable_email_verification {
        builder = builder.plugin(EmailVerificationPlugin::new());
    }
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

fn default_database() -> NativeDatabaseConfig {
    NativeDatabaseConfig::Memory
}

fn default_manage_migrations() -> bool {
    true
}

impl ListedRoute {
    fn new(method: &str, path: String, operation_id: &str, accepts_json_body: bool) -> Self {
        Self {
            method: method.to_string(),
            path,
            operation_id: operation_id.to_string(),
            accepts_json_body,
        }
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

        let native = NativeAuthResponse {
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

impl OwnedBytes {
    fn from_vec(bytes: Vec<u8>) -> Self {
        Self {
            bytes: bytes.into_boxed_slice(),
        }
    }

    fn as_native(&self) -> NativeBytes {
        NativeBytes {
            ptr: self.bytes.as_ptr(),
            len: self.bytes.len() as isize,
        }
    }
}

impl OwnedPair {
    fn new(key: String, value: String) -> Self {
        Self {
            key: OwnedBytes::from_vec(key.into_bytes()),
            value: OwnedBytes::from_vec(value.into_bytes()),
        }
    }

    fn as_native(&self) -> NativePair {
        NativePair {
            key: self.key.as_native(),
            value: self.value.as_native(),
        }
    }
}

fn native_pairs_from_owned(values: &[OwnedPair]) -> Box<[NativePair]> {
    values
        .iter()
        .map(OwnedPair::as_native)
        .collect::<Vec<_>>()
        .into_boxed_slice()
}

fn boxed_pairs_ptr(values: &[NativePair]) -> *const NativePair {
    if values.is_empty() {
        std::ptr::null()
    } else {
        values.as_ptr()
    }
}

fn response_content_type(headers: &HashMap<String, String>) -> String {
    headers
        .iter()
        .find(|(name, _)| name.eq_ignore_ascii_case("content-type"))
        .map(|(_, value)| value.clone())
        .unwrap_or_else(|| "application/json; charset=utf-8".to_string())
}

fn accepts_json_body(method: &HttpMethod) -> bool {
    matches!(
        method,
        HttpMethod::Post | HttpMethod::Put | HttpMethod::Patch | HttpMethod::Delete
    )
}

fn http_method_name(method: &HttpMethod) -> &'static str {
    match method {
        HttpMethod::Get => "GET",
        HttpMethod::Post => "POST",
        HttpMethod::Put => "PUT",
        HttpMethod::Patch => "PATCH",
        HttpMethod::Delete => "DELETE",
        HttpMethod::Head => "HEAD",
        HttpMethod::Options => "OPTIONS",
    }
}

fn decode_method(value: i32) -> Option<HttpMethod> {
    match value {
        0 => Some(HttpMethod::Get),
        1 => Some(HttpMethod::Post),
        2 => Some(HttpMethod::Put),
        3 => Some(HttpMethod::Patch),
        4 => Some(HttpMethod::Delete),
        5 => Some(HttpMethod::Head),
        6 => Some(HttpMethod::Options),
        _ => None,
    }
}

fn join_path(prefix: &str, path: &str) -> String {
    let prefix = normalize_base_path(prefix);
    let path = normalize_relative_path(path);

    if prefix == "/" {
        return path;
    }
    if path == "/" {
        return prefix;
    }

    format!("{prefix}{path}")
}

fn normalize_base_path(value: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() || trimmed == "/" {
        return "/".to_string();
    }

    let without_trailing = trimmed.trim_end_matches('/');
    if without_trailing.starts_with('/') {
        without_trailing.to_string()
    } else {
        format!("/{without_trailing}")
    }
}

fn normalize_relative_path(value: &str) -> String {
    if value.is_empty() || value == "/" {
        return "/".to_string();
    }

    if value.starts_with('/') {
        value.to_string()
    } else {
        format!("/{value}")
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

unsafe fn read_pairs(values: *const NativePair, count: isize) -> HashMap<String, String> {
    if count <= 0 || values.is_null() {
        return HashMap::new();
    }

    let mut result = HashMap::with_capacity(count as usize);
    for index in 0..count {
        let pair = unsafe { values.offset(index).read() };
        let Some(key) = (unsafe { read_native_string(pair.key) }) else {
            continue;
        };
        let Some(value) = (unsafe { read_native_string(pair.value) }) else {
            continue;
        };
        result.insert(key, value);
    }
    result
}

unsafe fn read_bytes(ptr: *const u8, len: isize) -> Option<Vec<u8>> {
    if ptr.is_null() || len <= 0 {
        return None;
    }

    Some(unsafe { std::slice::from_raw_parts(ptr, len as usize) }.to_vec())
}

unsafe fn read_native_string(value: NativeBytes) -> Option<String> {
    if value.ptr.is_null() || value.len <= 0 {
        return Some(String::new());
    }

    let slice = unsafe { std::slice::from_raw_parts(value.ptr, value.len as usize) };
    std::str::from_utf8(slice).ok().map(ToOwned::to_owned)
}
