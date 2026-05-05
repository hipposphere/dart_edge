use std::collections::{HashMap, VecDeque};
use std::ffi::{CStr, CString, c_char};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Mutex, RwLock};
use std::thread;

use axum::Router;
use axum::body::{Body, Bytes};
use axum::extract::FromRequestParts;
use axum::extract::Request;
use axum::extract::ws::{CloseFrame, Message, WebSocket, WebSocketUpgrade, close_code};
use axum::http::{HeaderMap, HeaderName, HeaderValue, Method, Response, StatusCode, header};
use axum::response::IntoResponse;
use axum::routing::any;
use dart_edge_core::{
    NativeBytes, NativePair, OwnedBytes, OwnedPair, boxed_pairs_ptr, native_pairs_from_owned,
    owned_pairs_from_map, read_native_bytes, read_native_string, read_pairs_vec,
};
use dart_edge_http_server_core::{
    NativeHttpFreeResponse, NativeHttpHandler, NativeHttpMethod, NativeHttpRequest,
};
use futures_util::StreamExt;
use once_cell::sync::Lazy;
use serde::Deserialize;
use tokio::net::TcpListener;
use tokio::sync::{mpsc, oneshot};
use tower_http::cors::{Any, CorsLayer};

const DART_EDGE_HTTP_SERVER_RUNTIME_NATIVE_ABI_VERSION: i32 = 11;

type TransportEventCallback = extern "C" fn(i32, i64);

static NEXT_REQUEST_ID: AtomicI64 = AtomicI64::new(1);
static NEXT_WEB_SOCKET_SESSION_ID: AtomicI64 = AtomicI64::new(1);
static LAST_ERROR: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));
static TRANSPORT_EVENT_CALLBACK: Lazy<Mutex<Option<TransportEventCallback>>> =
    Lazy::new(|| Mutex::new(None));
static PENDING_REQUESTS: Lazy<Mutex<HashMap<i64, PendingRequest>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static WEB_SOCKET_SESSIONS: Lazy<Mutex<HashMap<i64, WebSocketSessionState>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static SERVER_STATE: Lazy<Mutex<Option<ServerState>>> = Lazy::new(|| Mutex::new(None));
static COMPILED_ROUTES: Lazy<RwLock<Vec<CompiledRoute>>> = Lazy::new(|| RwLock::new(Vec::new()));
static COMPILED_SCHEMAS: Lazy<RwLock<HashMap<String, jsonschema::Validator>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

struct PendingRequest {
    request: Option<TransportRequest>,
    response_tx: mpsc::UnboundedSender<PendingResponseMessage>,
}

struct ServerState {
    shutdown_tx: Option<oneshot::Sender<()>>,
    join_handle: Option<thread::JoinHandle<()>>,
}

#[repr(C)]
pub struct NativeTransportRequest {
    route_id: NativeBytes,
    path_param_count: isize,
    path_params: *const NativePair,
    query_count: isize,
    query: *const NativePair,
    header_count: isize,
    headers: *const NativePair,
    body: NativeBytes,
    request_kind: u8,
    body_kind: u8,
}

#[repr(C)]
pub struct NativeMultipartField {
    name: NativeBytes,
    value: NativeBytes,
}

#[repr(C)]
pub struct NativeMultipartFile {
    field_name: NativeBytes,
    filename: NativeBytes,
    content_type: NativeBytes,
    body: NativeBytes,
}

#[repr(C)]
pub struct NativeMultipartForm {
    field_count: isize,
    fields: *const NativeMultipartField,
    file_count: isize,
    files: *const NativeMultipartFile,
}

#[repr(C)]
pub struct NativeWebSocketConnection {
    session_id: i64,
    request_id: i64,
    route_id: NativeBytes,
    path_param_count: isize,
    path_params: *const NativePair,
    query_count: isize,
    query: *const NativePair,
    header_count: isize,
    headers: *const NativePair,
}

#[repr(C)]
pub struct NativeWebSocketMessage {
    session_id: i64,
    body: NativeBytes,
}

#[repr(C)]
struct NativeTransportRequestHandle {
    request: NativeTransportRequest,
    route_id: OwnedBytes,
    path_params: Vec<OwnedPair>,
    path_param_pairs: Box<[NativePair]>,
    query: Vec<OwnedPair>,
    query_pairs: Box<[NativePair]>,
    headers: Vec<OwnedPair>,
    header_pairs: Box<[NativePair]>,
    body: Option<OwnedBytes>,
}

#[repr(C)]
struct NativeMultipartFormHandle {
    form: NativeMultipartForm,
    fields: Vec<OwnedMultipartField>,
    field_storage: Box<[NativeMultipartField]>,
    files: Vec<OwnedMultipartFile>,
    file_storage: Box<[NativeMultipartFile]>,
}

#[repr(C)]
struct NativeWebSocketConnectionHandle {
    connection: NativeWebSocketConnection,
    route_id: OwnedBytes,
    path_params: Vec<OwnedPair>,
    path_param_pairs: Box<[NativePair]>,
    query: Vec<OwnedPair>,
    query_pairs: Box<[NativePair]>,
    headers: Vec<OwnedPair>,
    header_pairs: Box<[NativePair]>,
}

#[repr(C)]
struct NativeWebSocketMessageHandle {
    message: NativeWebSocketMessage,
    body: OwnedBytes,
}

#[repr(u8)]
#[derive(Clone, Copy)]
enum NativeBodyKind {
    None = 0,
    Text = 1,
    Json = 2,
    Multipart = 3,
}

#[repr(u8)]
#[derive(Clone, Copy)]
enum NativeRequestKind {
    Http = 0,
    WebSocket = 1,
}

struct TransportRequest {
    route_id: String,
    path_params: HashMap<String, String>,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
    body: Option<Vec<u8>>,
    request_kind: NativeRequestKind,
    body_kind: NativeBodyKind,
}

struct TransportResponse {
    status: u16,
    content_type: String,
    body: String,
    headers: Vec<(String, String)>,
}

enum PendingResponseMessage {
    Http(TransportResponse),
    SseStart {
        status: u16,
        headers: Vec<(String, String)>,
    },
    SseChunk(String),
    WebSocketAccept {
        headers: Vec<(String, String)>,
    },
    Close,
}

struct WebSocketSessionState {
    connection: Option<WebSocketConnection>,
    messages: VecDeque<WebSocketIncomingMessage>,
    command_tx: mpsc::UnboundedSender<WebSocketCommand>,
}

struct WebSocketConnection {
    session_id: i64,
    request_id: i64,
    route_id: String,
    path_params: HashMap<String, String>,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
}

struct WebSocketIncomingMessage {
    session_id: i64,
    text: String,
}

enum WebSocketCommand {
    SendText(String),
    Close {
        code: Option<u16>,
        reason: Option<String>,
    },
}

#[derive(Deserialize)]
struct RouteManifest {
    routes: Vec<RouteManifestEntry>,
    #[serde(default)]
    schemas: HashMap<String, serde_json::Value>,
}

#[derive(Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
enum RouteTransportKind {
    #[default]
    Http,
    NativeHttp,
    WebSocket,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RouteManifestEntry {
    #[serde(default)]
    kind: RouteTransportKind,
    route_id: String,
    method: NativeHttpMethod,
    path_segments: Vec<RouteSegmentManifest>,
    handler_path_segments: Option<Vec<RouteSegmentManifest>>,
    params_schema_id: Option<String>,
    query_schema_id: Option<String>,
    headers_schema_id: Option<String>,
    request_body: Option<RequestBodyManifest>,
    native_handle: Option<i64>,
    native_handler_address: Option<usize>,
    native_free_response_address: Option<usize>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RouteSegmentManifest {
    value: String,
    is_parameter: bool,
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RequestBodyManifest {
    content_type: String,
    schema_id: Option<String>,
}

#[derive(Clone)]
struct CompiledRoute {
    kind: RouteTransportKind,
    route_id: String,
    method: NativeHttpMethod,
    path_segments: Vec<CompiledRouteSegment>,
    params_schema_id: Option<String>,
    query_schema_id: Option<String>,
    headers_schema_id: Option<String>,
    request_body: Option<RequestBodyValidation>,
    native_handler: Option<CompiledNativeHttpHandler>,
}

#[derive(Clone)]
struct CompiledNativeHttpHandler {
    handle: i64,
    handler: NativeHttpHandler,
    free_response: NativeHttpFreeResponse,
    handler_path_segments: Option<Vec<CompiledRouteSegment>>,
}

#[derive(Clone)]
enum CompiledRouteSegment {
    Literal(String),
    Parameter(String),
}

#[derive(Clone)]
struct RequestBodyValidation {
    content_type: String,
    kind: RequestBodyKind,
    schema_id: Option<String>,
}

#[derive(Clone, Copy)]
enum RequestBodyKind {
    Json,
    Text,
    Multipart,
    Other,
}

struct NativeRouteMatch {
    kind: RouteTransportKind,
    route_id: String,
    path_params: HashMap<String, String>,
    params_schema_id: Option<String>,
    query_schema_id: Option<String>,
    headers_schema_id: Option<String>,
    request_body: Option<RequestBodyValidation>,
    native_handler: Option<CompiledNativeHttpHandler>,
}

struct ValidatedBody {
    bytes: Option<Vec<u8>>,
    kind: NativeBodyKind,
    json: Option<serde_json::Value>,
}

struct ParsedMultipartForm {
    fields: Vec<ParsedMultipartField>,
    files: Vec<ParsedMultipartFile>,
}

struct ParsedMultipartField {
    name: String,
    value: String,
}

struct ParsedMultipartFile {
    field_name: String,
    filename: Option<String>,
    content_type: Option<String>,
    body_start: usize,
    body_len: usize,
}

struct ParsedContentDisposition {
    name: String,
    filename: Option<String>,
}

struct OwnedMultipartField {
    name: OwnedBytes,
    value: OwnedBytes,
}

struct OwnedMultipartFile {
    field_name: OwnedBytes,
    filename: Option<OwnedBytes>,
    content_type: Option<OwnedBytes>,
    body: NativeBytes,
}

struct CompiledManifest {
    routes: Vec<CompiledRoute>,
    schemas: HashMap<String, jsonschema::Validator>,
}

#[derive(Deserialize)]
struct MiddlewareManifest {
    #[serde(default)]
    middlewares: Vec<MiddlewareManifestEntry>,
}

#[derive(Deserialize)]
struct MiddlewareManifestEntry {
    name: String,
    #[serde(default)]
    configuration: serde_json::Value,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct CorsMiddlewareConfiguration {
    #[serde(default)]
    allow_origins: Vec<String>,
    #[serde(default)]
    allow_headers: Vec<String>,
}

#[repr(i32)]
#[derive(Clone, Copy)]
enum TransportEventKind {
    RequestReady = 1,
    WebSocketOpened = 2,
    WebSocketMessageReady = 3,
    WebSocketClosed = 4,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_native_abi_version() -> i32 {
    DART_EDGE_HTTP_SERVER_RUNTIME_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_start_server(
    host: *const c_char,
    port: i64,
    worker_count: i64,
    routes_json: *const c_char,
    middlewares_json: *const c_char,
    callback: TransportEventCallback,
) -> i64 {
    let Some(host) = (unsafe { read_c_string(host) }) else {
        return -1;
    };
    let Some(routes_json) = (unsafe { read_c_string(routes_json) }) else {
        return -1;
    };
    let Some(middlewares_json) = (unsafe { read_c_string(middlewares_json) }) else {
        return -1;
    };

    let compiled_manifest = match compile_manifest(&routes_json) {
        Ok(manifest) => manifest,
        Err(error) => {
            eprintln!("dart_edge_http_server_runtime route manifest parse failed: {error}");
            return -1;
        }
    };
    let cors_layer = match compile_cors_layer(&middlewares_json) {
        Ok(layer) => layer,
        Err(error) => {
            eprintln!("dart_edge_http_server_runtime middleware manifest parse failed: {error}");
            return -1;
        }
    };

    let mut server_state = SERVER_STATE.lock().unwrap();
    if server_state.is_some() {
        return -1;
    }

    *COMPILED_ROUTES.write().unwrap() = compiled_manifest.routes;
    *COMPILED_SCHEMAS.write().unwrap() = compiled_manifest.schemas;
    *TRANSPORT_EVENT_CALLBACK.lock().unwrap() = Some(callback);

    let (ready_tx, ready_rx) = std::sync::mpsc::channel();
    let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();
    let bind_host = host;
    let requested_port = port as u16;
    let worker_count = worker_count.max(1) as usize;

    let join_handle = thread::spawn(move || {
        let runtime = match build_runtime(worker_count) {
            Ok(runtime) => runtime,
            Err(error) => {
                let _ = ready_tx.send(Err(error.to_string()));
                return;
            }
        };

        runtime.block_on(async move {
            let listener = match TcpListener::bind((bind_host.as_str(), requested_port)).await {
                Ok(listener) => listener,
                Err(error) => {
                    let _ = ready_tx.send(Err(error.to_string()));
                    return;
                }
            };

            let local_port = match listener.local_addr() {
                Ok(address) => address.port(),
                Err(error) => {
                    let _ = ready_tx.send(Err(error.to_string()));
                    return;
                }
            };
            let _ = ready_tx.send(Ok(local_port));

            let mut app = Router::new().fallback(any(handle_request));
            if let Some(cors_layer) = cors_layer {
                app = app.layer(cors_layer);
            }
            let server = axum::serve(listener, app).with_graceful_shutdown(async move {
                let _ = shutdown_rx.await;
            });

            if let Err(error) = server.await {
                eprintln!("dart_edge_http_server_runtime transport server failed: {error}");
            }
        });
    });

    match ready_rx.recv() {
        Ok(Ok(bound_port)) => {
            *server_state = Some(ServerState {
                shutdown_tx: Some(shutdown_tx),
                join_handle: Some(join_handle),
            });
            bound_port as i64
        }
        Ok(Err(error)) => {
            eprintln!("dart_edge_http_server_runtime transport startup failed: {error}");
            *TRANSPORT_EVENT_CALLBACK.lock().unwrap() = None;
            *COMPILED_ROUTES.write().unwrap() = Vec::new();
            *COMPILED_SCHEMAS.write().unwrap() = HashMap::new();
            let _ = join_handle.join();
            -1
        }
        Err(error) => {
            eprintln!("dart_edge_http_server_runtime transport startup failed: {error}");
            *TRANSPORT_EVENT_CALLBACK.lock().unwrap() = None;
            *COMPILED_ROUTES.write().unwrap() = Vec::new();
            *COMPILED_SCHEMAS.write().unwrap() = HashMap::new();
            let _ = join_handle.join();
            -1
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_stop_server() {
    *TRANSPORT_EVENT_CALLBACK.lock().unwrap() = None;
    *COMPILED_ROUTES.write().unwrap() = Vec::new();
    *COMPILED_SCHEMAS.write().unwrap() = HashMap::new();

    {
        let mut pending = PENDING_REQUESTS.lock().unwrap();
        for (_, request) in pending.drain() {
            let _ = request
                .response_tx
                .send(PendingResponseMessage::Http(TransportResponse {
                    status: 503,
                    content_type: "text/plain; charset=utf-8".to_string(),
                    body: "Server stopped".to_string(),
                    headers: Vec::new(),
                }));
            let _ = request.response_tx.send(PendingResponseMessage::Close);
        }
    }

    {
        let mut sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
        for (_, session) in sessions.drain() {
            let _ = session.command_tx.send(WebSocketCommand::Close {
                code: Some(1012),
                reason: Some("Server stopped".to_string()),
            });
        }
    }

    let server_state = SERVER_STATE.lock().unwrap().take();
    if let Some(mut state) = server_state {
        if let Some(shutdown_tx) = state.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }
        if let Some(join_handle) = state.join_handle.take() {
            let _ = join_handle.join();
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_take_request(
    request_id: i64,
) -> *mut NativeTransportRequest {
    let mut pending = PENDING_REQUESTS.lock().unwrap();
    let Some(request) = pending.get_mut(&request_id) else {
        return std::ptr::null_mut();
    };
    let Some(request) = request.request.take() else {
        return std::ptr::null_mut();
    };

    let handle = Box::new(NativeTransportRequestHandle::from_transport_request(
        request,
    ));
    Box::into_raw(handle).cast::<NativeTransportRequest>()
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_free_request(value: *mut NativeTransportRequest) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = Box::from_raw(value.cast::<NativeTransportRequestHandle>());
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_accept_web_socket(
    request_id: i64,
    header_count: isize,
    headers: *const NativePair,
) -> bool {
    let headers = unsafe { read_pairs_vec(headers, header_count) };
    send_pending_response_message(
        request_id,
        PendingResponseMessage::WebSocketAccept { headers },
        true,
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_start_sse_response(
    request_id: i64,
    status: i32,
    header_count: isize,
    headers: *const NativePair,
) -> bool {
    let headers = unsafe { read_pairs_vec(headers, header_count) };
    send_pending_response_message(
        request_id,
        PendingResponseMessage::SseStart {
            status: status as u16,
            headers,
        },
        false,
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_send_sse_chunk(
    request_id: i64,
    chunk: *const c_char,
) -> bool {
    let Some(chunk) = (unsafe { read_c_string(chunk) }) else {
        return false;
    };

    send_pending_response_message(request_id, PendingResponseMessage::SseChunk(chunk), false)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_finish_sse_response(request_id: i64) -> bool {
    send_pending_response_message(request_id, PendingResponseMessage::Close, true)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_parse_multipart(
    request: *mut NativeTransportRequest,
    content_type: *const c_char,
) -> *mut NativeMultipartForm {
    clear_last_error();

    if request.is_null() {
        set_last_error("Missing native request.");
        return std::ptr::null_mut();
    }

    let Some(content_type) = (unsafe { read_c_string(content_type) }) else {
        set_last_error("Missing request content type.");
        return std::ptr::null_mut();
    };

    let boundary = match parse_multipart_boundary(&content_type) {
        Ok(boundary) => boundary,
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    let request_handle = unsafe { &mut *request.cast::<NativeTransportRequestHandle>() };
    let body = request_handle.request.body;
    if body.ptr.is_null() || body.len <= 0 {
        set_last_error("Request body is empty.");
        return std::ptr::null_mut();
    }

    let body_bytes = unsafe { std::slice::from_raw_parts(body.ptr, body.len as usize) };
    let parsed_form = match parse_multipart_form(body_bytes, &boundary) {
        Ok(form) => form,
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    let handle = Box::new(NativeMultipartFormHandle::from_parsed_form(
        parsed_form,
        body.ptr,
    ));
    Box::into_raw(handle).cast::<NativeMultipartForm>()
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_free_multipart_form(
    value: *mut NativeMultipartForm,
) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = Box::from_raw(value.cast::<NativeMultipartFormHandle>());
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_take_web_socket_connection(
    session_id: i64,
) -> *mut NativeWebSocketConnection {
    let mut sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
    let Some(session) = sessions.get_mut(&session_id) else {
        return std::ptr::null_mut();
    };
    let Some(connection) = session.connection.take() else {
        return std::ptr::null_mut();
    };

    let handle = Box::new(NativeWebSocketConnectionHandle::from_connection(connection));
    Box::into_raw(handle).cast::<NativeWebSocketConnection>()
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_free_web_socket_connection(
    value: *mut NativeWebSocketConnection,
) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = Box::from_raw(value.cast::<NativeWebSocketConnectionHandle>());
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_take_web_socket_message(
    session_id: i64,
) -> *mut NativeWebSocketMessage {
    let mut sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
    let Some(session) = sessions.get_mut(&session_id) else {
        return std::ptr::null_mut();
    };
    let Some(message) = session.messages.pop_front() else {
        return std::ptr::null_mut();
    };

    let handle = Box::new(NativeWebSocketMessageHandle::from_message(message));
    Box::into_raw(handle).cast::<NativeWebSocketMessage>()
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_free_web_socket_message(
    value: *mut NativeWebSocketMessage,
) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = Box::from_raw(value.cast::<NativeWebSocketMessageHandle>());
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_web_socket_send_text(
    session_id: i64,
    text: *const c_char,
) -> bool {
    let Some(text) = (unsafe { read_c_string(text) }) else {
        return false;
    };
    let command_tx = {
        let sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
        let Some(session) = sessions.get(&session_id) else {
            return false;
        };
        session.command_tx.clone()
    };

    command_tx.send(WebSocketCommand::SendText(text)).is_ok()
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_web_socket_close(
    session_id: i64,
    code: i32,
    reason: *const c_char,
) -> bool {
    let reason = unsafe { read_optional_c_string(reason) };
    let command_tx = {
        let sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
        let Some(session) = sessions.get(&session_id) else {
            return false;
        };
        session.command_tx.clone()
    };

    command_tx
        .send(WebSocketCommand::Close {
            code: if code <= 0 { None } else { Some(code as u16) },
            reason,
        })
        .is_ok()
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_take_last_error() -> *mut c_char {
    let Some(message) = LAST_ERROR.lock().unwrap().take() else {
        return std::ptr::null_mut();
    };

    match CString::new(message) {
        Ok(message) => message.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_send_response(
    request_id: i64,
    status: i32,
    content_type: *const c_char,
    body: *const c_char,
    header_count: isize,
    headers: *const NativePair,
) -> bool {
    let content_type = unsafe { read_c_string(content_type) };
    let body = unsafe { read_c_string(body) };
    let Some(content_type) = content_type else {
        return false;
    };
    let Some(body) = body else {
        return false;
    };
    let headers = unsafe { read_pairs_vec(headers, header_count) };

    send_pending_response_message(
        request_id,
        PendingResponseMessage::Http(TransportResponse {
            status: status as u16,
            content_type,
            body,
            headers,
        }),
        true,
    )
}

async fn handle_request(request: Request<Body>) -> Response<Body> {
    let (parts, body) = request.into_parts();
    let requested_kind = if wants_web_socket_upgrade(&parts.headers) {
        RouteTransportKind::WebSocket
    } else {
        RouteTransportKind::Http
    };

    let route_match = match match_route(parts.method.as_str(), parts.uri.path(), requested_kind) {
        Some(route_match) => route_match,
        None => {
            return response(
                StatusCode::NOT_FOUND,
                "text/plain; charset=utf-8",
                "Not found".to_string(),
            );
        }
    };
    let query = parse_query(parts.uri.query());
    let headers = collect_headers(&parts.headers);

    if let Err(error_response) = validate_string_map(
        &route_match.path_params,
        route_match.params_schema_id.as_deref(),
        "Path parameters",
    ) {
        return error_response;
    }
    if let Err(error_response) = validate_string_map(
        &query,
        route_match.query_schema_id.as_deref(),
        "Query parameters",
    ) {
        return error_response;
    }
    if let Err(error_response) = validate_string_map(
        &headers,
        route_match.headers_schema_id.as_deref(),
        "Headers",
    ) {
        return error_response;
    }

    match route_match.kind {
        RouteTransportKind::Http | RouteTransportKind::NativeHttp => {
            let body_bytes = match axum::body::to_bytes(body, usize::MAX).await {
                Ok(bytes) => bytes,
                Err(_) => {
                    return response(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "text/plain; charset=utf-8",
                        "Failed to read request body".to_string(),
                    );
                }
            };
            let body = match validate_and_read_body(
                &parts.headers,
                body_bytes,
                route_match.request_body.as_ref(),
            ) {
                Ok(body) => body,
                Err(error_response) => return error_response,
            };
            if let Some(request_body) = route_match.request_body.as_ref() {
                if let Err(error_response) = validate_request_body(&body, request_body) {
                    return error_response;
                }
            }

            match route_match.kind {
                RouteTransportKind::NativeHttp => {
                    handle_native_http_request(
                        route_match,
                        parts.method.as_str(),
                        parts.uri.path(),
                        query,
                        headers,
                        body,
                    )
                    .await
                }
                _ => handle_http_request(route_match, query, headers, body).await,
            }
        }
        RouteTransportKind::WebSocket => {
            handle_web_socket_request(parts, route_match, query, headers).await
        }
    }
}

async fn handle_http_request(
    route_match: NativeRouteMatch,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
    body: ValidatedBody,
) -> Response<Body> {
    let transport_request = TransportRequest {
        route_id: route_match.route_id,
        path_params: route_match.path_params,
        query,
        headers,
        body: body.bytes,
        request_kind: NativeRequestKind::Http,
        body_kind: body.kind,
    };

    let (_request_id, mut response_rx) = match dispatch_request_to_dart(transport_request) {
        Ok(value) => value,
        Err(error_response) => return error_response,
    };

    match response_rx.recv().await {
        Some(PendingResponseMessage::Http(transport_response)) => response_with_headers(
            StatusCode::from_u16(transport_response.status)
                .unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            &transport_response.content_type,
            &transport_response.headers,
            transport_response.body,
        ),
        Some(PendingResponseMessage::SseStart { status, headers }) => {
            let stream = async_stream::stream! {
                while let Some(message) = response_rx.recv().await {
                    match message {
                        PendingResponseMessage::SseChunk(chunk) => {
                            yield Ok::<Bytes, std::convert::Infallible>(Bytes::from(chunk));
                        }
                        PendingResponseMessage::Close => break,
                        PendingResponseMessage::Http(_)
                        | PendingResponseMessage::SseStart { .. }
                        | PendingResponseMessage::WebSocketAccept { .. } => break,
                    }
                }
            };

            response_body_with_headers(
                StatusCode::from_u16(status).unwrap_or(StatusCode::OK),
                "text/event-stream; charset=utf-8",
                &headers,
                Body::from_stream(stream),
            )
        }
        Some(PendingResponseMessage::Close) | None => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "Request handling failed".to_string(),
        ),
        Some(PendingResponseMessage::SseChunk(_)) => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "Unexpected SSE chunk before SSE start".to_string(),
        ),
        Some(PendingResponseMessage::WebSocketAccept { .. }) => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "Unexpected WebSocket response for HTTP request".to_string(),
        ),
    }
}

async fn handle_native_http_request(
    route_match: NativeRouteMatch,
    method: &str,
    path: &str,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
    body: ValidatedBody,
) -> Response<Body> {
    let NativeRouteMatch {
        native_handler,
        path_params,
        ..
    } = route_match;
    let Some(native_handler) = native_handler else {
        return response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "Native route is missing handler metadata".to_string(),
        );
    };

    let handler_path = match native_handler_path(
        path,
        native_handler.handler_path_segments.as_deref(),
        &path_params,
    ) {
        Ok(path) => path,
        Err(message) => {
            return response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "text/plain; charset=utf-8",
                message,
            );
        }
    };
    let path = CString::new(handler_path).unwrap_or_default();
    let query_pairs = owned_pairs_from_map(query);
    let query_storage = native_pairs_from_owned(&query_pairs);
    let header_pairs = owned_pairs_from_map(headers);
    let header_storage = native_pairs_from_owned(&header_pairs);
    let body_bytes = body.bytes.unwrap_or_default();
    let body_ptr = if body_bytes.is_empty() {
        std::ptr::null()
    } else {
        body_bytes.as_ptr()
    };

    let Some(method) = NativeHttpMethod::from_name(method) else {
        return response(
            StatusCode::METHOD_NOT_ALLOWED,
            "text/plain; charset=utf-8",
            "Unsupported HTTP method".to_string(),
        );
    };
    let request_body = NativeBytes {
        ptr: body_ptr,
        len: body_bytes.len() as isize,
    };
    let native_request = NativeHttpRequest {
        method: method.code(),
        path: path.as_ptr(),
        query_count: query_storage.len() as isize,
        query: boxed_pairs_ptr(&query_storage),
        header_count: header_storage.len() as isize,
        headers: boxed_pairs_ptr(&header_storage),
        body: request_body,
    };
    let response_ptr = unsafe { (native_handler.handler)(native_handler.handle, &native_request) };
    if response_ptr.is_null() {
        return response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "Native route handler failed".to_string(),
        );
    }

    let native_response = unsafe { &*response_ptr };
    let status =
        StatusCode::from_u16(native_response.status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
    let content_type = unsafe { read_native_string(native_response.content_type) }
        .unwrap_or_else(|| "application/octet-stream".to_string());
    let response_body = unsafe { read_native_bytes(native_response.body) }
        .map(|bytes| bytes.to_vec())
        .unwrap_or_default();
    let response_headers =
        unsafe { read_pairs_vec(native_response.headers, native_response.header_count) };
    unsafe {
        (native_handler.free_response)(response_ptr);
    }

    response_body_with_headers(
        status,
        &content_type,
        &response_headers,
        Body::from(response_body),
    )
}

fn native_handler_path(
    public_path: &str,
    handler_path_segments: Option<&[CompiledRouteSegment]>,
    path_params: &HashMap<String, String>,
) -> Result<String, String> {
    let Some(handler_path_segments) = handler_path_segments else {
        return Ok(public_path.to_string());
    };

    if handler_path_segments.is_empty() {
        return Ok("/".to_string());
    }

    let mut path = String::new();
    for segment in handler_path_segments {
        path.push('/');
        match segment {
            CompiledRouteSegment::Literal(value) => path.push_str(value),
            CompiledRouteSegment::Parameter(name) => {
                let Some(value) = path_params.get(name) else {
                    return Err(format!(
                        "Native route handler path references missing parameter '{name}'."
                    ));
                };
                path.push_str(value);
            }
        }
    }

    Ok(path)
}

async fn handle_web_socket_request(
    mut parts: http::request::Parts,
    route_match: NativeRouteMatch,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
) -> Response<Body> {
    let route_id = route_match.route_id;
    let path_params = route_match.path_params;
    let transport_request = TransportRequest {
        route_id: route_id.clone(),
        path_params: path_params.clone(),
        query: query.clone(),
        headers: headers.clone(),
        body: None,
        request_kind: NativeRequestKind::WebSocket,
        body_kind: NativeBodyKind::None,
    };

    let (request_id, mut response_rx) = match dispatch_request_to_dart(transport_request) {
        Ok(value) => value,
        Err(error_response) => return error_response,
    };

    match response_rx.recv().await {
        Some(PendingResponseMessage::Http(transport_response)) => response_with_headers(
            StatusCode::from_u16(transport_response.status)
                .unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            &transport_response.content_type,
            &transport_response.headers,
            transport_response.body,
        ),
        Some(PendingResponseMessage::WebSocketAccept {
            headers: response_headers,
        }) => {
            let websocket = match WebSocketUpgrade::from_request_parts(&mut parts, &()).await {
                Ok(websocket) => websocket,
                Err(rejection) => return rejection.into_response(),
            };

            let mut response = websocket
                .on_upgrade(move |socket| {
                    handle_web_socket_session(
                        socket,
                        request_id,
                        route_id,
                        path_params,
                        query,
                        headers,
                    )
                })
                .into_response();
            append_headers(response.headers_mut(), &response_headers);
            response
        }
        _ => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "WebSocket handshake failed".to_string(),
        ),
    }
}

async fn handle_web_socket_session(
    mut socket: WebSocket,
    request_id: i64,
    route_id: String,
    path_params: HashMap<String, String>,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
) {
    let session_id = NEXT_WEB_SOCKET_SESSION_ID.fetch_add(1, Ordering::Relaxed);
    let (command_tx, mut command_rx) = mpsc::unbounded_channel::<WebSocketCommand>();
    {
        let mut sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
        sessions.insert(
            session_id,
            WebSocketSessionState {
                connection: Some(WebSocketConnection {
                    session_id,
                    request_id,
                    route_id,
                    path_params,
                    query,
                    headers,
                }),
                messages: VecDeque::new(),
                command_tx,
            },
        );
    }
    notify_transport_event(TransportEventKind::WebSocketOpened, session_id);

    loop {
        tokio::select! {
            incoming = socket.next() => {
                match incoming {
                    Some(Ok(Message::Text(text))) => {
                        push_web_socket_message(
                            session_id,
                            WebSocketIncomingMessage {
                                session_id,
                                text: text.to_string(),
                            },
                        );
                        notify_transport_event(TransportEventKind::WebSocketMessageReady, session_id);
                    }
                    Some(Ok(Message::Binary(bytes))) => {
                        match String::from_utf8(bytes.to_vec()) {
                            Ok(text) => {
                                push_web_socket_message(
                                    session_id,
                                    WebSocketIncomingMessage { session_id, text },
                                );
                                notify_transport_event(TransportEventKind::WebSocketMessageReady, session_id);
                            }
                            Err(_) => {
                                let _ = try_send_web_socket_close(
                                    &mut socket,
                                    Some(close_code::UNSUPPORTED),
                                    Some("Binary WebSocket frames must be UTF-8 JSON.".to_string()),
                                )
                                .await;
                                break;
                            }
                        }
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Ok(Message::Ping(_))) | Some(Ok(Message::Pong(_))) => {}
                    Some(Err(_)) => break,
                }
            }
            command = command_rx.recv() => {
                match command {
                    Some(WebSocketCommand::SendText(text)) => {
                        if socket.send(Message::Text(text.into())).await.is_err() {
                            break;
                        }
                    }
                    Some(WebSocketCommand::Close { code, reason }) => {
                        let _ = try_send_web_socket_close(&mut socket, code, reason).await;
                        break;
                    }
                    None => break,
                }
            }
        }
    }

    let _ = WEB_SOCKET_SESSIONS.lock().unwrap().remove(&session_id);
    notify_transport_event(TransportEventKind::WebSocketClosed, session_id);
}

fn dispatch_request_to_dart(
    transport_request: TransportRequest,
) -> Result<(i64, mpsc::UnboundedReceiver<PendingResponseMessage>), Response<Body>> {
    let request_id = NEXT_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
    let (response_tx, response_rx) = mpsc::unbounded_channel::<PendingResponseMessage>();
    {
        let mut pending = PENDING_REQUESTS.lock().unwrap();
        pending.insert(
            request_id,
            PendingRequest {
                request: Some(transport_request),
                response_tx,
            },
        );
    }

    if !notify_transport_event(TransportEventKind::RequestReady, request_id) {
        let _ = PENDING_REQUESTS.lock().unwrap().remove(&request_id);
        return Err(response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "No Dart callback registered".to_string(),
        ));
    }

    Ok((request_id, response_rx))
}

fn send_pending_response_message(
    request_id: i64,
    message: PendingResponseMessage,
    remove: bool,
) -> bool {
    let response_tx = {
        let mut pending = PENDING_REQUESTS.lock().unwrap();
        if remove {
            let Some(request) = pending.remove(&request_id) else {
                return false;
            };
            request.response_tx
        } else {
            let Some(request) = pending.get(&request_id) else {
                return false;
            };
            request.response_tx.clone()
        }
    };

    if response_tx.send(message).is_ok() {
        return true;
    }

    if !remove {
        let _ = PENDING_REQUESTS.lock().unwrap().remove(&request_id);
    }
    false
}

fn notify_transport_event(event_kind: TransportEventKind, event_id: i64) -> bool {
    let callback = *TRANSPORT_EVENT_CALLBACK.lock().unwrap();
    let Some(callback) = callback else {
        return false;
    };

    callback(event_kind as i32, event_id);
    true
}

fn wants_web_socket_upgrade(headers: &HeaderMap) -> bool {
    headers
        .get(header::UPGRADE)
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value.eq_ignore_ascii_case("websocket"))
}

fn append_headers(target: &mut HeaderMap, headers: &[(String, String)]) {
    for (name, value) in headers {
        let Ok(header_name) = HeaderName::try_from(name.as_str()) else {
            continue;
        };
        let Ok(header_value) = HeaderValue::from_str(value) else {
            continue;
        };
        target.append(header_name, header_value);
    }
}

fn response_body_with_headers(
    status: StatusCode,
    content_type: &str,
    headers: &[(String, String)],
    body: Body,
) -> Response<Body> {
    let mut builder = Response::builder().status(status);
    builder = builder.header(header::CONTENT_TYPE, content_type);
    for (name, value) in headers {
        builder = builder.header(name, value);
    }
    builder
        .body(body)
        .unwrap_or_else(|_| Response::new(Body::from("Internal Server Error")))
}

fn push_web_socket_message(session_id: i64, message: WebSocketIncomingMessage) {
    let mut sessions = WEB_SOCKET_SESSIONS.lock().unwrap();
    if let Some(session) = sessions.get_mut(&session_id) {
        session.messages.push_back(message);
    }
}

async fn try_send_web_socket_close(
    socket: &mut WebSocket,
    code: Option<u16>,
    reason: Option<String>,
) -> Result<(), axum::Error> {
    let frame = match (code, reason) {
        (None, None) => None,
        (code, reason) => Some(CloseFrame {
            code: code.unwrap_or(close_code::NORMAL),
            reason: reason.unwrap_or_default().into(),
        }),
    };

    socket.send(Message::Close(frame)).await
}

fn compile_manifest(routes_json: &str) -> Result<CompiledManifest, String> {
    let manifest: RouteManifest =
        serde_json::from_str(routes_json).map_err(|error| error.to_string())?;
    let schemas = compile_schemas(manifest.schemas)?;
    let routes = manifest
        .routes
        .into_iter()
        .map(|route| compile_route(route, &schemas))
        .collect::<Result<Vec<_>, _>>()?;

    Ok(CompiledManifest { routes, schemas })
}

fn compile_cors_layer(middlewares_json: &str) -> Result<Option<CorsLayer>, String> {
    let manifest: MiddlewareManifest =
        serde_json::from_str(middlewares_json).map_err(|error| error.to_string())?;

    for middleware in manifest.middlewares {
        if middleware.name != "cors" {
            continue;
        }

        let configuration: CorsMiddlewareConfiguration =
            serde_json::from_value(middleware.configuration).map_err(|error| error.to_string())?;
        return Ok(Some(cors_layer(configuration)?));
    }

    Ok(None)
}

fn cors_layer(configuration: CorsMiddlewareConfiguration) -> Result<CorsLayer, String> {
    let mut layer = CorsLayer::new().allow_methods([
        Method::GET,
        Method::POST,
        Method::PUT,
        Method::PATCH,
        Method::DELETE,
        Method::HEAD,
        Method::OPTIONS,
    ]);

    layer = if configuration.allow_origins.is_empty()
        || configuration
            .allow_origins
            .iter()
            .any(|origin| origin == "*")
    {
        layer.allow_origin(Any)
    } else {
        let origins = configuration
            .allow_origins
            .iter()
            .map(|origin| {
                HeaderValue::from_str(origin)
                    .map_err(|error| format!("Invalid CORS origin '{origin}': {error}"))
            })
            .collect::<Result<Vec<_>, _>>()?;
        layer.allow_origin(origins)
    };

    layer = if configuration.allow_headers.is_empty()
        || configuration
            .allow_headers
            .iter()
            .any(|header| header == "*")
    {
        layer.allow_headers(Any)
    } else {
        let headers = configuration
            .allow_headers
            .iter()
            .map(|header| {
                HeaderName::try_from(header.as_str())
                    .map_err(|error| format!("Invalid CORS header '{header}': {error}"))
            })
            .collect::<Result<Vec<_>, _>>()?;
        layer.allow_headers(headers)
    };

    Ok(layer)
}

fn compile_schemas(
    manifest_schemas: HashMap<String, serde_json::Value>,
) -> Result<HashMap<String, jsonschema::Validator>, String> {
    let mut schemas = HashMap::with_capacity(manifest_schemas.len());

    for (id, schema) in manifest_schemas {
        let validator = jsonschema::validator_for(&schema)
            .map_err(|error| format!("Invalid schema '{id}': {error}"))?;
        schemas.insert(id, validator);
    }

    Ok(schemas)
}

fn compile_route(
    route: RouteManifestEntry,
    schemas: &HashMap<String, jsonschema::Validator>,
) -> Result<CompiledRoute, String> {
    ensure_schema_exists(schemas, route.params_schema_id.as_deref())?;
    ensure_schema_exists(schemas, route.query_schema_id.as_deref())?;
    ensure_schema_exists(schemas, route.headers_schema_id.as_deref())?;
    ensure_schema_exists(
        schemas,
        route
            .request_body
            .as_ref()
            .and_then(|request_body| request_body.schema_id.as_deref()),
    )?;

    let request_body = match route.kind {
        RouteTransportKind::Http | RouteTransportKind::NativeHttp => {
            route
                .request_body
                .map(|request_body| RequestBodyValidation {
                    kind: body_kind(&request_body.content_type),
                    content_type: request_body.content_type,
                    schema_id: request_body.schema_id,
                })
        }
        RouteTransportKind::WebSocket => None,
    };
    let handler_path_segments = route.handler_path_segments.map(compile_route_segments);
    let native_handler = match route.kind {
        RouteTransportKind::NativeHttp => {
            let handle = route.native_handle.ok_or_else(|| {
                format!("Native route '{}' is missing nativeHandle", route.route_id)
            })?;
            let handler_address = route.native_handler_address.ok_or_else(|| {
                format!(
                    "Native route '{}' is missing nativeHandlerAddress",
                    route.route_id
                )
            })?;
            let free_response_address = route.native_free_response_address.ok_or_else(|| {
                format!(
                    "Native route '{}' is missing nativeFreeResponseAddress",
                    route.route_id
                )
            })?;
            Some(CompiledNativeHttpHandler {
                handle,
                handler: unsafe {
                    std::mem::transmute::<usize, NativeHttpHandler>(handler_address)
                },
                free_response: unsafe {
                    std::mem::transmute::<usize, NativeHttpFreeResponse>(free_response_address)
                },
                handler_path_segments,
            })
        }
        _ => None,
    };

    Ok(CompiledRoute {
        kind: route.kind,
        route_id: route.route_id,
        method: route.method,
        path_segments: compile_route_segments(route.path_segments),
        params_schema_id: route.params_schema_id,
        query_schema_id: route.query_schema_id,
        headers_schema_id: route.headers_schema_id,
        request_body,
        native_handler,
    })
}

fn compile_route_segments(segments: Vec<RouteSegmentManifest>) -> Vec<CompiledRouteSegment> {
    segments
        .into_iter()
        .map(|segment| {
            if segment.is_parameter {
                CompiledRouteSegment::Parameter(segment.value)
            } else {
                CompiledRouteSegment::Literal(segment.value)
            }
        })
        .collect()
}

fn ensure_schema_exists(
    schemas: &HashMap<String, jsonschema::Validator>,
    schema_id: Option<&str>,
) -> Result<(), String> {
    let Some(schema_id) = schema_id else {
        return Ok(());
    };

    if schemas.contains_key(schema_id) {
        Ok(())
    } else {
        Err(format!("Route references missing schema '{schema_id}'"))
    }
}

fn build_runtime(worker_count: usize) -> Result<tokio::runtime::Runtime, std::io::Error> {
    if worker_count == 1 {
        return tokio::runtime::Builder::new_current_thread()
            .enable_io()
            .build();
    }

    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(worker_count)
        .max_blocking_threads(worker_count)
        .thread_stack_size(1024 * 1024)
        .enable_io()
        .build()
}

impl NativeTransportRequestHandle {
    fn from_transport_request(request: TransportRequest) -> Self {
        let route_id = OwnedBytes::from_vec(request.route_id.into_bytes());
        let path_params = owned_pairs_from_map(request.path_params);
        let path_param_pairs = native_pairs_from_owned(&path_params);
        let query = owned_pairs_from_map(request.query);
        let query_pairs = native_pairs_from_owned(&query);
        let headers = owned_pairs_from_map(request.headers);
        let header_pairs = native_pairs_from_owned(&headers);
        let body = request.body.map(OwnedBytes::from_vec);

        let native_request = NativeTransportRequest {
            route_id: route_id.as_native(),
            path_param_count: path_param_pairs.len() as isize,
            path_params: boxed_pairs_ptr(&path_param_pairs),
            query_count: query_pairs.len() as isize,
            query: boxed_pairs_ptr(&query_pairs),
            header_count: header_pairs.len() as isize,
            headers: boxed_pairs_ptr(&header_pairs),
            body: body
                .as_ref()
                .map(OwnedBytes::as_native)
                .unwrap_or_else(NativeBytes::empty),
            request_kind: request.request_kind as u8,
            body_kind: request.body_kind as u8,
        };

        Self {
            request: native_request,
            route_id,
            path_params,
            path_param_pairs,
            query,
            query_pairs,
            headers,
            header_pairs,
            body,
        }
    }
}

impl NativeWebSocketConnectionHandle {
    fn from_connection(connection: WebSocketConnection) -> Self {
        let route_id = OwnedBytes::from_string(connection.route_id);
        let path_params = owned_pairs_from_map(connection.path_params);
        let path_param_pairs = native_pairs_from_owned(&path_params);
        let query = owned_pairs_from_map(connection.query);
        let query_pairs = native_pairs_from_owned(&query);
        let headers = owned_pairs_from_map(connection.headers);
        let header_pairs = native_pairs_from_owned(&headers);

        let native_connection = NativeWebSocketConnection {
            session_id: connection.session_id,
            request_id: connection.request_id,
            route_id: route_id.as_native(),
            path_param_count: path_param_pairs.len() as isize,
            path_params: boxed_pairs_ptr(&path_param_pairs),
            query_count: query_pairs.len() as isize,
            query: boxed_pairs_ptr(&query_pairs),
            header_count: header_pairs.len() as isize,
            headers: boxed_pairs_ptr(&header_pairs),
        };

        Self {
            connection: native_connection,
            route_id,
            path_params,
            path_param_pairs,
            query,
            query_pairs,
            headers,
            header_pairs,
        }
    }
}

impl NativeWebSocketMessageHandle {
    fn from_message(message: WebSocketIncomingMessage) -> Self {
        let body = OwnedBytes::from_string(message.text);
        let native_message = NativeWebSocketMessage {
            session_id: message.session_id,
            body: body.as_native(),
        };

        Self {
            message: native_message,
            body,
        }
    }
}

impl OwnedMultipartField {
    fn new(name: String, value: String) -> Self {
        Self {
            name: OwnedBytes::from_string(name),
            value: OwnedBytes::from_string(value),
        }
    }

    fn as_native(&self) -> NativeMultipartField {
        NativeMultipartField {
            name: self.name.as_native(),
            value: self.value.as_native(),
        }
    }
}

impl OwnedMultipartFile {
    fn new(
        field_name: String,
        filename: Option<String>,
        content_type: Option<String>,
        body_ptr: *const u8,
        body_start: usize,
        body_len: usize,
    ) -> Self {
        let body = if body_len == 0 {
            NativeBytes::empty()
        } else {
            NativeBytes {
                ptr: unsafe { body_ptr.add(body_start) },
                len: body_len as isize,
            }
        };

        Self {
            field_name: OwnedBytes::from_string(field_name),
            filename: filename.map(OwnedBytes::from_string),
            content_type: content_type.map(OwnedBytes::from_string),
            body,
        }
    }

    fn as_native(&self) -> NativeMultipartFile {
        NativeMultipartFile {
            field_name: self.field_name.as_native(),
            filename: self
                .filename
                .as_ref()
                .map(OwnedBytes::as_native)
                .unwrap_or_else(NativeBytes::empty),
            content_type: self
                .content_type
                .as_ref()
                .map(OwnedBytes::as_native)
                .unwrap_or_else(NativeBytes::empty),
            body: self.body,
        }
    }
}

impl NativeMultipartFormHandle {
    fn from_parsed_form(form: ParsedMultipartForm, body_ptr: *const u8) -> Self {
        let fields = form
            .fields
            .into_iter()
            .map(|field| OwnedMultipartField::new(field.name, field.value))
            .collect::<Vec<_>>();
        let field_storage = fields
            .iter()
            .map(OwnedMultipartField::as_native)
            .collect::<Vec<_>>()
            .into_boxed_slice();
        let files = form
            .files
            .into_iter()
            .map(|file| {
                OwnedMultipartFile::new(
                    file.field_name,
                    file.filename,
                    file.content_type,
                    body_ptr,
                    file.body_start,
                    file.body_len,
                )
            })
            .collect::<Vec<_>>();
        let file_storage = files
            .iter()
            .map(OwnedMultipartFile::as_native)
            .collect::<Vec<_>>()
            .into_boxed_slice();

        let native_form = NativeMultipartForm {
            field_count: field_storage.len() as isize,
            fields: boxed_ptr(&field_storage),
            file_count: file_storage.len() as isize,
            files: boxed_ptr(&file_storage),
        };

        Self {
            form: native_form,
            fields,
            field_storage,
            files,
            file_storage,
        }
    }
}

fn match_route(
    method: &str,
    path: &str,
    requested_kind: RouteTransportKind,
) -> Option<NativeRouteMatch> {
    let request_segments = path_segments(path);
    let routes = COMPILED_ROUTES.read().unwrap();

    for route in routes.iter() {
        if !route_kind_matches(route.kind, requested_kind) {
            continue;
        }
        if route.method.as_str() != method {
            continue;
        }
        if route.path_segments.len() != request_segments.len() {
            continue;
        }

        let mut path_params = HashMap::new();
        let mut matched = true;

        for (route_segment, request_segment) in
            route.path_segments.iter().zip(request_segments.iter())
        {
            match route_segment {
                CompiledRouteSegment::Literal(literal) if literal == request_segment => {}
                CompiledRouteSegment::Literal(_) => {
                    matched = false;
                    break;
                }
                CompiledRouteSegment::Parameter(name) => {
                    path_params.insert(name.clone(), (*request_segment).to_string());
                }
            }
        }

        if matched {
            return Some(NativeRouteMatch {
                kind: route.kind,
                route_id: route.route_id.clone(),
                path_params,
                params_schema_id: route.params_schema_id.clone(),
                query_schema_id: route.query_schema_id.clone(),
                headers_schema_id: route.headers_schema_id.clone(),
                request_body: route.request_body.clone(),
                native_handler: route.native_handler.clone(),
            });
        }
    }

    None
}

fn route_kind_matches(route_kind: RouteTransportKind, requested_kind: RouteTransportKind) -> bool {
    match requested_kind {
        RouteTransportKind::Http => {
            matches!(
                route_kind,
                RouteTransportKind::Http | RouteTransportKind::NativeHttp
            )
        }
        RouteTransportKind::NativeHttp => false,
        RouteTransportKind::WebSocket => route_kind == RouteTransportKind::WebSocket,
    }
}

fn validate_and_read_body(
    headers: &HeaderMap,
    body: Bytes,
    request_body: Option<&RequestBodyValidation>,
) -> Result<ValidatedBody, Response<Body>> {
    if body.is_empty() {
        return Ok(ValidatedBody::none());
    }

    if let Some(request_body) = request_body {
        let actual_content_type = headers
            .get(header::CONTENT_TYPE)
            .and_then(|value| value.to_str().ok());

        if !content_type_matches(actual_content_type, &request_body.content_type) {
            return Err(response(
                StatusCode::UNSUPPORTED_MEDIA_TYPE,
                "text/plain; charset=utf-8",
                format!("Expected {}", request_body.content_type),
            ));
        }

        return match request_body.kind {
            RequestBodyKind::Json => parse_json_body(body),
            RequestBodyKind::Multipart => Ok(ValidatedBody {
                bytes: Some(body.to_vec()),
                kind: NativeBodyKind::Multipart,
                json: None,
            }),
            RequestBodyKind::Text | RequestBodyKind::Other => {
                parse_utf8_body(body, NativeBodyKind::Text)
            }
        };
    }

    parse_utf8_body(body, NativeBodyKind::Text)
}

fn parse_json_body(body: Bytes) -> Result<ValidatedBody, Response<Body>> {
    match serde_json::from_slice::<serde_json::Value>(body.as_ref()) {
        Ok(json) => Ok(ValidatedBody {
            bytes: Some(body.to_vec()),
            kind: NativeBodyKind::Json,
            json: Some(json),
        }),
        Err(_) => Err(response(
            StatusCode::BAD_REQUEST,
            "text/plain; charset=utf-8",
            "Invalid JSON body".to_string(),
        )),
    }
}

fn parse_utf8_body(body: Bytes, kind: NativeBodyKind) -> Result<ValidatedBody, Response<Body>> {
    match std::str::from_utf8(body.as_ref()) {
        Ok(_) => Ok(ValidatedBody {
            bytes: Some(body.to_vec()),
            kind,
            json: None,
        }),
        Err(_) => Err(response(
            StatusCode::BAD_REQUEST,
            "text/plain; charset=utf-8",
            "Request body must be valid UTF-8".to_string(),
        )),
    }
}

impl ValidatedBody {
    fn none() -> Self {
        Self {
            bytes: None,
            kind: NativeBodyKind::None,
            json: None,
        }
    }
}

fn validate_string_map(
    values: &HashMap<String, String>,
    schema_id: Option<&str>,
    label: &str,
) -> Result<(), Response<Body>> {
    let Some(schema_id) = schema_id else {
        return Ok(());
    };

    let instance = serde_json::Value::Object(
        values
            .iter()
            .map(|(key, value)| (key.clone(), serde_json::Value::String(value.clone())))
            .collect(),
    );
    validate_schema_value(schema_id, &instance, label)
}

fn validate_request_body(
    body: &ValidatedBody,
    request_body: &RequestBodyValidation,
) -> Result<(), Response<Body>> {
    let Some(schema_id) = request_body.schema_id.as_deref() else {
        return Ok(());
    };
    let instance = match body.kind {
        NativeBodyKind::Json => body
            .json
            .as_ref()
            .cloned()
            .unwrap_or(serde_json::Value::Null),
        NativeBodyKind::Text => match body.bytes.as_ref() {
            Some(bytes) => {
                serde_json::Value::String(String::from_utf8_lossy(bytes.as_slice()).into_owned())
            }
            None => serde_json::Value::Null,
        },
        NativeBodyKind::Multipart | NativeBodyKind::None => serde_json::Value::Null,
    };

    validate_schema_value(schema_id, &instance, "Request body")
}

fn validate_schema_value(
    schema_id: &str,
    instance: &serde_json::Value,
    label: &str,
) -> Result<(), Response<Body>> {
    let schemas = COMPILED_SCHEMAS.read().unwrap();
    let Some(validator) = schemas.get(schema_id) else {
        return Err(response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            format!("Missing compiled schema '{schema_id}'"),
        ));
    };

    if validator.is_valid(instance) {
        return Ok(());
    }

    let detail = validator
        .iter_errors(instance)
        .next()
        .map(|error| error.to_string())
        .unwrap_or_else(|| "Unknown schema validation error".to_string());
    Err(response(
        StatusCode::UNPROCESSABLE_ENTITY,
        "text/plain; charset=utf-8",
        format!("{label} validation failed: {detail}"),
    ))
}

fn response(status: StatusCode, content_type: &str, body: String) -> Response<Body> {
    response_with_headers(status, content_type, &[], body)
}

fn response_with_headers(
    status: StatusCode,
    content_type: &str,
    headers: &[(String, String)],
    body: String,
) -> Response<Body> {
    response_body_with_headers(status, content_type, headers, Body::from(body))
}

fn path_segments(path: &str) -> Vec<&str> {
    if path == "/" {
        return Vec::new();
    }

    path.split('/')
        .filter(|segment| !segment.is_empty())
        .collect()
}

fn body_kind(content_type: &str) -> RequestBodyKind {
    match content_type_essence(content_type) {
        "application/json" => RequestBodyKind::Json,
        "multipart/form-data" => RequestBodyKind::Multipart,
        "text/plain" => RequestBodyKind::Text,
        _ => RequestBodyKind::Other,
    }
}

fn content_type_matches(actual: Option<&str>, expected: &str) -> bool {
    let Some(actual) = actual else {
        return false;
    };

    content_type_essence(actual).eq_ignore_ascii_case(content_type_essence(expected))
}

fn content_type_essence(value: &str) -> &str {
    value.split(';').next().unwrap_or_default().trim()
}

fn parse_query(query: Option<&str>) -> HashMap<String, String> {
    let mut result = HashMap::new();
    if let Some(query) = query {
        for pair in query.split('&') {
            if pair.is_empty() {
                continue;
            }
            let (key, value) = pair.split_once('=').unwrap_or((pair, ""));
            result.insert(key.to_string(), value.to_string());
        }
    }
    result
}

fn collect_headers(headers: &HeaderMap) -> HashMap<String, String> {
    headers
        .iter()
        .map(|(name, value)| {
            let value = value.to_str().unwrap_or_default().to_string();
            (name.as_str().to_string(), value)
        })
        .collect()
}

fn boxed_ptr<T>(values: &[T]) -> *const T {
    if values.is_empty() {
        std::ptr::null()
    } else {
        values.as_ptr()
    }
}

fn set_last_error(message: impl Into<String>) {
    *LAST_ERROR.lock().unwrap() = Some(message.into());
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

fn parse_multipart_boundary(content_type: &str) -> Result<String, String> {
    if !content_type_essence(content_type).eq_ignore_ascii_case("multipart/form-data") {
        return Err("Expected multipart/form-data request.".to_string());
    }

    for parameter in content_type.split(';').skip(1) {
        let Some((name, value)) = parameter.trim().split_once('=') else {
            continue;
        };
        if !name.trim().eq_ignore_ascii_case("boundary") {
            continue;
        }

        let boundary = trim_header_parameter(value.trim());
        if boundary.is_empty() {
            return Err("Multipart boundary must not be empty.".to_string());
        }
        return Ok(boundary.to_string());
    }

    Err("Missing multipart boundary.".to_string())
}

fn parse_multipart_form(body: &[u8], boundary: &str) -> Result<ParsedMultipartForm, String> {
    let boundary_marker = format!("--{boundary}").into_bytes();
    let part_delimiter = format!("\r\n--{boundary}").into_bytes();
    let mut cursor = 0;
    let mut fields = Vec::new();
    let mut files = Vec::new();

    if !body.starts_with(&boundary_marker) {
        return Err("Multipart body does not start with the declared boundary.".to_string());
    }

    loop {
        cursor += boundary_marker.len();

        if body.get(cursor..cursor + 2) == Some(b"--") {
            cursor += 2;
            if body.get(cursor..cursor + 2) == Some(b"\r\n") {
                cursor += 2;
            }
            if cursor != body.len() {
                return Err("Unexpected bytes after the closing multipart boundary.".to_string());
            }
            return Ok(ParsedMultipartForm { fields, files });
        }

        if body.get(cursor..cursor + 2) != Some(b"\r\n") {
            return Err("Invalid multipart boundary separator.".to_string());
        }
        cursor += 2;

        let Some(headers_end) = find_bytes(body, cursor, b"\r\n\r\n") else {
            return Err("Multipart part is missing a header terminator.".to_string());
        };
        let part_headers = parse_part_headers(&body[cursor..headers_end])?;
        cursor = headers_end + 4;

        let Some(content_disposition) = part_headers.get("content-disposition") else {
            return Err("Multipart part is missing Content-Disposition.".to_string());
        };
        let disposition = parse_content_disposition(content_disposition)?;

        let Some(part_end) = find_bytes(body, cursor, &part_delimiter) else {
            return Err("Multipart part is missing a closing boundary.".to_string());
        };
        let part_body = &body[cursor..part_end];

        if disposition.filename.is_some() {
            files.push(ParsedMultipartFile {
                field_name: disposition.name,
                filename: disposition.filename,
                content_type: part_headers.get("content-type").cloned(),
                body_start: cursor,
                body_len: part_body.len(),
            });
        } else {
            let value = std::str::from_utf8(part_body)
                .map_err(|_| {
                    format!(
                        "Multipart field '{}' must be valid UTF-8.",
                        disposition.name
                    )
                })?
                .to_string();
            fields.push(ParsedMultipartField {
                name: disposition.name,
                value,
            });
        }

        cursor = part_end + 2;
        if !body[cursor..].starts_with(&boundary_marker) {
            return Err("Multipart parser lost boundary alignment.".to_string());
        }
    }
}

fn parse_part_headers(header_block: &[u8]) -> Result<HashMap<String, String>, String> {
    let header_text = std::str::from_utf8(header_block)
        .map_err(|_| "Multipart part headers must be valid UTF-8.".to_string())?;
    let mut headers = HashMap::new();

    for line in header_text.split("\r\n") {
        if line.is_empty() {
            continue;
        }

        let Some((name, value)) = line.split_once(':') else {
            return Err(format!("Invalid multipart header line '{line}'."));
        };
        headers.insert(name.trim().to_ascii_lowercase(), value.trim().to_string());
    }

    Ok(headers)
}

fn parse_content_disposition(value: &str) -> Result<ParsedContentDisposition, String> {
    let mut parts = value.split(';');
    let Some(kind) = parts.next() else {
        return Err("Empty Content-Disposition header.".to_string());
    };
    if !kind.trim().eq_ignore_ascii_case("form-data") {
        return Err("Multipart Content-Disposition must be form-data.".to_string());
    }

    let mut name = None;
    let mut filename = None;

    for part in parts {
        let Some((parameter_name, parameter_value)) = part.trim().split_once('=') else {
            continue;
        };
        let decoded_value = trim_header_parameter(parameter_value.trim()).to_string();
        if parameter_name.trim().eq_ignore_ascii_case("name") {
            name = Some(decoded_value);
            continue;
        }
        if parameter_name.trim().eq_ignore_ascii_case("filename")
            || parameter_name.trim().eq_ignore_ascii_case("filename*")
        {
            filename = Some(decoded_value);
        }
    }

    let Some(name) = name else {
        return Err("Multipart part is missing a field name.".to_string());
    };

    Ok(ParsedContentDisposition { name, filename })
}

fn trim_header_parameter(value: &str) -> &str {
    if value.len() >= 2 && value.starts_with('"') && value.ends_with('"') {
        &value[1..value.len() - 1]
    } else {
        value
    }
}

fn find_bytes(haystack: &[u8], start: usize, needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || start > haystack.len() || haystack.len() - start < needle.len() {
        return None;
    }

    haystack[start..]
        .windows(needle.len())
        .position(|window| window == needle)
        .map(|offset| start + offset)
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

unsafe fn read_optional_c_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }

    unsafe { read_c_string(value) }
}
