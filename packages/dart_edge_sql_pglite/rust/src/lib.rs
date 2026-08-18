use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char, c_void};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use once_cell::sync::Lazy;
use pglite_oxide::{PgliteServer, PgliteServerBuilder, extensions};

const DART_EDGE_SQL_PGLITE_NATIVE_ABI_VERSION: i32 = 4;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static SERVERS: Lazy<Mutex<HashMap<i64, PgliteServerEntry>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

type ClosePoolCallback = extern "C" fn(i64);

struct PgliteServerEntry {
    server: PgliteServer,
    pool: Option<ManagedSqlPool>,
}

struct ManagedSqlPool {
    handle: i64,
    close: ClosePoolCallback,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_native_abi_version() -> i32 {
    DART_EDGE_SQL_PGLITE_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_open_temporary() -> i64 {
    open_server_with_extensions(std::ptr::null(), || PgliteServer::builder().temporary())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_open_temporary_with_extensions(
    extensions: *const c_char,
) -> i64 {
    open_server_with_extensions(extensions, || PgliteServer::builder().temporary())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_open_persistent(path: *const c_char) -> i64 {
    dart_edge_sql_pglite_open_persistent_with_extensions(path, std::ptr::null())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_open_persistent_with_extensions(
    path: *const c_char,
    extensions: *const c_char,
) -> i64 {
    let Some(path) = (unsafe { read_c_string(path) }) else {
        set_last_error("Missing PGlite storage path.");
        return 0;
    };

    open_server_with_extensions(extensions, || PgliteServer::builder().path(path))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_connection_string(handle: i64) -> *mut c_char {
    let servers = SERVERS.lock().unwrap();
    let Some(entry) = servers.get(&handle) else {
        set_last_error("Unknown PGlite database handle.");
        return std::ptr::null_mut();
    };

    match CString::new(entry.server.connection_uri()) {
        Ok(value) => {
            clear_last_error();
            value.into_raw()
        }
        Err(error) => {
            set_last_error(format!(
                "Failed to encode PGlite connection string: {error}"
            ));
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_bind_pool(
    handle: i64,
    pool_handle: i64,
    close_pool: Option<ClosePoolCallback>,
) -> bool {
    let Some(close_pool) = close_pool else {
        set_last_error("Missing native SQL pool cleanup callback.");
        return false;
    };
    let mut servers = SERVERS.lock().unwrap();
    let Some(entry) = servers.get_mut(&handle) else {
        set_last_error("Unknown PGlite database handle.");
        return false;
    };
    entry.pool = Some(ManagedSqlPool {
        handle: pool_handle,
        close: close_pool,
    });
    clear_last_error();
    true
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_close(handle: i64) -> bool {
    match close_server(handle) {
        Ok(_) => {
            clear_last_error();
            true
        }
        Err(error) => {
            set_last_error(format!("Failed to close PGlite database: {error}"));
            false
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_close_finalizer(handle: *mut c_void) {
    let _ = close_server(handle as usize as i64);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_close_all() -> bool {
    let servers = {
        let mut servers = SERVERS.lock().unwrap();
        std::mem::take(&mut *servers)
    };
    let mut errors = Vec::new();

    for (handle, entry) in servers {
        if let Err(error) = close_entry(entry) {
            errors.push(format!("handle {handle}: {error}"));
        }
    }

    if errors.is_empty() {
        clear_last_error();
        true
    } else {
        set_last_error(format!(
            "Failed to close PGlite databases: {}",
            errors.join("; ")
        ));
        false
    }
}

fn close_server(handle: i64) -> Result<(), String> {
    let entry = SERVERS.lock().unwrap().remove(&handle);
    let Some(entry) = entry else {
        return Ok(());
    };
    close_entry(entry)
}

fn close_entry(entry: PgliteServerEntry) -> Result<(), String> {
    if let Some(pool) = entry.pool {
        (pool.close)(pool.handle);
    }
    entry.server.shutdown().map_err(|error| error.to_string())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_take_last_error() -> *mut c_char {
    LAST_ERROR
        .lock()
        .unwrap()
        .take()
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_sql_pglite_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

fn open_server<E>(open: impl FnOnce() -> Result<PgliteServer, E>) -> i64
where
    E: ToString,
{
    let handle = reserve_handle();
    match open() {
        Ok(server) => {
            SERVERS
                .lock()
                .unwrap()
                .insert(handle, PgliteServerEntry { server, pool: None });
            clear_last_error();
            handle
        }
        Err(error) => {
            set_last_error(format!(
                "Failed to open PGlite database: {}",
                error.to_string()
            ));
            0
        }
    }
}

fn open_server_with_extensions(
    extensions: *const c_char,
    builder: impl FnOnce() -> PgliteServerBuilder,
) -> i64 {
    let extension_names = match read_extension_names(extensions) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(error);
            return 0;
        }
    };

    open_server(|| {
        let mut builder = builder();
        for name in extension_names {
            let Some(extension) = extensions::by_sql_name(&name) else {
                return Err(format!("Unsupported bundled PGlite extension: {name}"));
            };
            builder = builder.extension(extension);
        }
        builder.start().map_err(|error| error.to_string())
    })
}

fn read_extension_names(extensions: *const c_char) -> Result<Vec<String>, String> {
    let Some(value) = (unsafe { read_c_string(extensions) }) else {
        return Ok(Vec::new());
    };
    if value.trim().is_empty() {
        return Ok(Vec::new());
    }

    value
        .lines()
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .map(|name| {
            if name.contains('\0') {
                Err("PGlite extension names must not contain NUL bytes.".to_owned())
            } else {
                Ok(name.to_owned())
            }
        })
        .collect()
}

fn reserve_handle() -> i64 {
    NEXT_HANDLE.fetch_add(1, Ordering::Relaxed)
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
