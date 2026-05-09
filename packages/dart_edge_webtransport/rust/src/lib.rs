use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;
use wtransport::endpoint::ConnectOptions;
use wtransport::{ClientConfig, Connection, Endpoint, VarInt};

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static SESSIONS: Lazy<Mutex<HashMap<i64, NativeWebTransportSession>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

#[repr(C)]
pub struct NativeWebTransportConnectConfig {
    url: *mut c_char,
    headers_json: *mut c_char,
    allow_self_signed: bool,
}

#[repr(C)]
pub struct NativeWebTransportConnectResult {
    handle: i64,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeWebTransportBytesResult {
    bytes: *mut u8,
    length: i64,
    error: *mut c_char,
}

struct NativeWebTransportSession {
    runtime: Arc<Runtime>,
    _endpoint: Endpoint<wtransport::endpoint::endpoint_side::Client>,
    connection: Connection,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_native_abi_version() -> i64 {
    1
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_connect(
    config: *const NativeWebTransportConnectConfig,
) -> *mut NativeWebTransportConnectResult {
    let result = unsafe { connect(config) };
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_dispose(handle: i64) {
    let mut sessions = SESSIONS.lock().unwrap_or_else(|poison| poison.into_inner());
    sessions.remove(&handle);
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_send_datagram(
    handle: i64,
    bytes: *const u8,
    length: i64,
) -> *mut c_char {
    match unsafe { send_datagram(handle, bytes, length) } {
        Ok(()) => std::ptr::null_mut(),
        Err(error) => c_string_ptr(error),
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_send_stream(
    handle: i64,
    bytes: *const u8,
    length: i64,
) -> *mut c_char {
    match unsafe { send_stream(handle, bytes, length) } {
        Ok(()) => std::ptr::null_mut(),
        Err(error) => c_string_ptr(error),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_receive_datagram(
    handle: i64,
) -> *mut NativeWebTransportBytesResult {
    let result = receive_datagram(handle);
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_receive_stream(
    handle: i64,
) -> *mut NativeWebTransportBytesResult {
    let result = receive_stream(handle);
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_close(
    handle: i64,
    code: i64,
    reason: *const c_char,
) -> *mut c_char {
    match unsafe { close(handle, code, reason) } {
        Ok(()) => std::ptr::null_mut(),
        Err(error) => c_string_ptr(error),
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_free_connect_result(
    value: *mut NativeWebTransportConnectResult,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    free_c_string(value.error);
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_free_bytes_result(
    value: *mut NativeWebTransportBytesResult,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    if !value.bytes.is_null() && value.length > 0 {
        unsafe {
            let _ = Vec::from_raw_parts(value.bytes, value.length as usize, value.length as usize);
        }
    }
    free_c_string(value.error);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_free_string(value: *mut c_char) {
    free_c_string(value);
}

unsafe fn connect(
    config: *const NativeWebTransportConnectConfig,
) -> NativeWebTransportConnectResult {
    if config.is_null() {
        return connect_error("Missing WebTransport connect config.");
    }

    let config = unsafe { &*config };
    let url = match unsafe { read_required_string(config.url, "url") } {
        Ok(value) => value,
        Err(error) => return connect_error(error),
    };
    let headers_json = match unsafe { read_optional_string(config.headers_json) } {
        Ok(Some(value)) if !value.is_empty() => value,
        Ok(_) => "{}".to_string(),
        Err(error) => return connect_error(error),
    };
    let headers = match serde_json::from_str::<HashMap<String, String>>(&headers_json) {
        Ok(value) => value,
        Err(error) => return connect_error(format!("Invalid headers JSON: {error}")),
    };

    let runtime = match Runtime::new() {
        Ok(value) => Arc::new(value),
        Err(error) => return connect_error(format!("Failed to create Tokio runtime: {error}")),
    };

    let client_config = if config.allow_self_signed {
        ClientConfig::builder()
            .with_bind_default()
            .with_no_cert_validation()
            .build()
    } else {
        ClientConfig::builder()
            .with_bind_default()
            .with_native_certs()
            .build()
    };

    let endpoint = match {
        let _guard = runtime.enter();
        Endpoint::client(client_config)
    } {
        Ok(value) => value,
        Err(error) => {
            return connect_error(format!("Failed to create WebTransport endpoint: {error}"));
        }
    };

    let mut options = ConnectOptions::builder(url);
    for (name, value) in headers {
        options = options.add_header(name, value);
    }

    let connection = match runtime.block_on(endpoint.connect(options)) {
        Ok(value) => value,
        Err(error) => {
            return connect_error(format!("Failed to connect WebTransport session: {error}"));
        }
    };

    let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
    let mut sessions = SESSIONS.lock().unwrap_or_else(|poison| poison.into_inner());
    sessions.insert(
        handle,
        NativeWebTransportSession {
            runtime,
            _endpoint: endpoint,
            connection,
        },
    );

    NativeWebTransportConnectResult {
        handle,
        error: std::ptr::null_mut(),
    }
}

unsafe fn send_datagram(handle: i64, bytes: *const u8, length: i64) -> Result<(), String> {
    if length < 0 {
        return Err("Datagram length must not be negative.".to_string());
    }
    let payload = if length == 0 {
        &[]
    } else {
        if bytes.is_null() {
            return Err("Datagram bytes pointer is null.".to_string());
        }
        unsafe { std::slice::from_raw_parts(bytes, length as usize) }
    };

    with_session(handle, |session| {
        session
            .connection
            .send_datagram(payload)
            .map_err(|error| format!("Failed to send WebTransport datagram: {error}"))
    })
}

unsafe fn send_stream(handle: i64, bytes: *const u8, length: i64) -> Result<(), String> {
    let payload = unsafe { read_payload(bytes, length)? };
    with_session_connection(handle, |runtime, connection| {
        runtime.block_on(async move {
            let opening = connection
                .open_uni()
                .await
                .map_err(|error| format!("Failed to open WebTransport stream: {error}"))?;
            let mut stream = opening
                .await
                .map_err(|error| format!("Failed to establish WebTransport stream: {error}"))?;
            stream
                .write_all(&payload)
                .await
                .map_err(|error| format!("Failed to write WebTransport stream: {error}"))?;
            stream
                .finish()
                .await
                .map_err(|error| format!("Failed to finish WebTransport stream: {error}"))
        })
    })
}

fn receive_datagram(handle: i64) -> NativeWebTransportBytesResult {
    match with_session_connection(handle, |runtime, connection| {
        runtime
            .block_on(connection.receive_datagram())
            .map(|datagram| datagram.payload().to_vec())
            .map_err(|error| format!("Failed to receive WebTransport datagram: {error}"))
    }) {
        Ok(bytes) => bytes_result(bytes),
        Err(error) => bytes_result_error(error),
    }
}

fn receive_stream(handle: i64) -> NativeWebTransportBytesResult {
    match with_session_connection(handle, |runtime, connection| {
        runtime.block_on(async move {
            let stream = connection
                .accept_uni()
                .await
                .map_err(|error| format!("Failed to accept WebTransport stream: {error}"))?;
            read_stream_payload(stream)
                .await
                .map_err(|error| format!("Failed to read WebTransport stream: {error}"))
        })
    }) {
        Ok(bytes) => bytes_result(bytes),
        Err(error) => bytes_result_error(error),
    }
}

unsafe fn close(handle: i64, code: i64, reason: *const c_char) -> Result<(), String> {
    let reason = unsafe { read_optional_string(reason)? }.unwrap_or_default();
    let code = u32::try_from(code).map_err(|_| "WebTransport close code is out of range.")?;
    let code = VarInt::from_u32(code);

    with_session(handle, |session| {
        session.connection.close(code, reason.as_bytes());
        Ok(())
    })
}

fn with_session<T>(
    handle: i64,
    apply: impl FnOnce(&NativeWebTransportSession) -> Result<T, String>,
) -> Result<T, String> {
    let sessions = SESSIONS.lock().unwrap_or_else(|poison| poison.into_inner());
    let session = sessions
        .get(&handle)
        .ok_or_else(|| "Unknown WebTransport session handle.".to_string())?;
    apply(session)
}

fn with_session_connection<T>(
    handle: i64,
    apply: impl FnOnce(&Runtime, Connection) -> Result<T, String>,
) -> Result<T, String> {
    let (runtime, connection) = {
        let sessions = SESSIONS.lock().unwrap_or_else(|poison| poison.into_inner());
        let session = sessions
            .get(&handle)
            .ok_or_else(|| "Unknown WebTransport session handle.".to_string())?;
        (session.runtime.clone(), session.connection.clone())
    };

    apply(&runtime, connection)
}

unsafe fn read_payload(bytes: *const u8, length: i64) -> Result<Vec<u8>, String> {
    if length < 0 {
        return Err("Payload length must not be negative.".to_string());
    }
    if length == 0 {
        return Ok(Vec::new());
    }
    if bytes.is_null() {
        return Err("Payload bytes pointer is null.".to_string());
    }
    Ok(unsafe { std::slice::from_raw_parts(bytes, length as usize) }.to_vec())
}

async fn read_stream_payload(mut stream: wtransport::stream::RecvStream) -> Result<Vec<u8>, String> {
    let mut payload = Vec::new();
    let mut buffer = [0u8; 16 * 1024];
    loop {
        match stream.read(&mut buffer).await {
            Ok(Some(bytes_read)) => payload.extend_from_slice(&buffer[..bytes_read]),
            Ok(None) => return Ok(payload),
            Err(error) => return Err(error.to_string()),
        }
    }
}

unsafe fn read_required_string(value: *const c_char, name: &str) -> Result<String, String> {
    unsafe { read_optional_string(value) }?.ok_or_else(|| format!("Missing WebTransport {name}."))
}

unsafe fn read_optional_string(value: *const c_char) -> Result<Option<String>, String> {
    if value.is_null() {
        return Ok(None);
    }
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(|value| Some(value.to_string()))
        .map_err(|error| format!("Invalid UTF-8 in WebTransport string: {error}"))
}

fn connect_error(error: impl Into<String>) -> NativeWebTransportConnectResult {
    NativeWebTransportConnectResult {
        handle: 0,
        error: c_string_ptr(error),
    }
}

fn bytes_result(bytes: Vec<u8>) -> NativeWebTransportBytesResult {
    let mut bytes = bytes;
    let length = bytes.len() as i64;
    let ptr = if bytes.is_empty() {
        std::ptr::null_mut()
    } else {
        let ptr = bytes.as_mut_ptr();
        std::mem::forget(bytes);
        ptr
    };

    NativeWebTransportBytesResult {
        bytes: ptr,
        length,
        error: std::ptr::null_mut(),
    }
}

fn bytes_result_error(error: impl Into<String>) -> NativeWebTransportBytesResult {
    NativeWebTransportBytesResult {
        bytes: std::ptr::null_mut(),
        length: 0,
        error: c_string_ptr(error),
    }
}

fn c_string_ptr(message: impl Into<String>) -> *mut c_char {
    let message = message.into();
    CString::new(message)
        .unwrap_or_else(|_| CString::new("dart_edge_webtransport native error").unwrap())
        .into_raw()
}

fn free_c_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(value);
    }
}
