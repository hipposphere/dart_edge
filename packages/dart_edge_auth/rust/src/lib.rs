use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use better_auth::adapters::{DatabaseAdapter, MemoryDatabaseAdapter, SqlxAdapter};
use better_auth::plugins::{
    AccountManagementPlugin, AdminPlugin, EmailPasswordPlugin, EmailVerificationPlugin,
    PasswordManagementPlugin, SessionManagementPlugin,
};
use better_auth::{
    AuthBuilder, AuthConfig, AuthRequest, BetterAuth, HttpMethod, RateLimitConfig, TypedAuthBuilder,
};
use better_auth_diesel_sqlite::DieselSqliteAdapter;
use dart_edge_core::{
    NativePair, OwnedBytes, OwnedPair, boxed_pairs_ptr, native_pairs_from_owned, read_native_bytes,
    read_pairs_map,
};
use dart_edge_http_server_core::{
    NativeHttpMethod, NativeHttpRequest, NativeHttpResponse, native_http_routes_to_json,
};
use once_cell::sync::Lazy;
use serde::Deserialize;
use serde_json::json;
use shared_sql_adapter::{SharedSqlCallbacks, SharedSqlDatabaseAdapter, SharedSqlDialect};
use tokio::runtime::Runtime;

mod routes;
mod shared_sql_adapter;

use routes::{join_path, normalize_base_path};

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
    Postgres {
        connection_string: String,
    },
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
    let headers = unsafe { read_pairs_map(request.headers, request.header_count) };
    let body = unsafe { read_native_bytes(request.body) }.map(|body| body.to_vec());

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
                return Err(
                    "Shared database dialect did not match the requested callbacks.".to_string(),
                );
            }

            let adapter = SharedSqlDatabaseAdapter::new(shared_dialect, callbacks);
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

    fn openapi_spec(&self) -> better_auth::OpenApiSpec {
        match self {
            NativeAuthBackend::Memory(auth) => auth.openapi_spec(),
            NativeAuthBackend::Postgres(auth) => auth.openapi_spec(),
            NativeAuthBackend::Sqlite(auth) => auth.openapi_spec(),
            NativeAuthBackend::Shared(auth) => auth.openapi_spec(),
        }
    }
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
