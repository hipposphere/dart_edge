use std::collections::HashMap;
use std::ffi::{CStr, c_char};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Mutex, RwLock};
use std::thread;

use axum::Router;
use axum::body::{Body, Bytes};
use axum::extract::Request;
use axum::http::{HeaderMap, Response, StatusCode, header};
use axum::routing::any;
use dart_edge_core::{
    NativeBytes, NativePair, OwnedBytes, OwnedPair, boxed_pairs_ptr, native_pairs_from_owned,
    owned_pairs_from_map, read_pairs_vec,
};
use once_cell::sync::Lazy;
use serde::Deserialize;
use tokio::net::TcpListener;
use tokio::sync::oneshot;

const DART_EDGE_HTTP_SERVER_RUNTIME_NATIVE_ABI_VERSION: i32 = 8;

type RequestReadyCallback = extern "C" fn(i64);

static NEXT_REQUEST_ID: AtomicI64 = AtomicI64::new(1);
static REQUEST_READY_CALLBACK: Lazy<Mutex<Option<RequestReadyCallback>>> =
    Lazy::new(|| Mutex::new(None));
static PENDING_REQUESTS: Lazy<Mutex<HashMap<i64, PendingRequest>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static SERVER_STATE: Lazy<Mutex<Option<ServerState>>> = Lazy::new(|| Mutex::new(None));
static COMPILED_ROUTES: Lazy<RwLock<Vec<CompiledRoute>>> = Lazy::new(|| RwLock::new(Vec::new()));
static COMPILED_SCHEMAS: Lazy<RwLock<HashMap<String, jsonschema::Validator>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

struct PendingRequest {
    request: Option<TransportRequest>,
    response_tx: Option<oneshot::Sender<TransportResponse>>,
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
    body_kind: u8,
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

#[repr(u8)]
#[derive(Clone, Copy)]
enum NativeBodyKind {
    None = 0,
    Text = 1,
    Json = 2,
}

struct TransportRequest {
    route_id: String,
    path_params: HashMap<String, String>,
    query: HashMap<String, String>,
    headers: HashMap<String, String>,
    body: Option<Vec<u8>>,
    body_kind: NativeBodyKind,
}

struct TransportResponse {
    status: u16,
    content_type: String,
    body: String,
    headers: Vec<(String, String)>,
}

#[derive(Deserialize)]
struct RouteManifest {
    routes: Vec<RouteManifestEntry>,
    #[serde(default)]
    schemas: HashMap<String, serde_json::Value>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RouteManifestEntry {
    route_id: String,
    method: String,
    path_segments: Vec<RouteSegmentManifest>,
    params_schema_id: Option<String>,
    query_schema_id: Option<String>,
    headers_schema_id: Option<String>,
    request_body: Option<RequestBodyManifest>,
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
    route_id: String,
    method: String,
    path_segments: Vec<CompiledRouteSegment>,
    params_schema_id: Option<String>,
    query_schema_id: Option<String>,
    headers_schema_id: Option<String>,
    request_body: Option<RequestBodyValidation>,
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
    Other,
}

struct NativeRouteMatch {
    route_id: String,
    path_params: HashMap<String, String>,
    params_schema_id: Option<String>,
    query_schema_id: Option<String>,
    headers_schema_id: Option<String>,
    request_body: Option<RequestBodyValidation>,
}

struct ValidatedBody {
    bytes: Option<Vec<u8>>,
    kind: NativeBodyKind,
    json: Option<serde_json::Value>,
}

struct CompiledManifest {
    routes: Vec<CompiledRoute>,
    schemas: HashMap<String, jsonschema::Validator>,
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
    callback: RequestReadyCallback,
) -> i64 {
    let Some(host) = (unsafe { read_c_string(host) }) else {
        return -1;
    };
    let Some(routes_json) = (unsafe { read_c_string(routes_json) }) else {
        return -1;
    };

    let compiled_manifest = match compile_manifest(&routes_json) {
        Ok(manifest) => manifest,
        Err(error) => {
            eprintln!("dart_edge_http_server_runtime route manifest parse failed: {error}");
            return -1;
        }
    };

    let mut server_state = SERVER_STATE.lock().unwrap();
    if server_state.is_some() {
        return -1;
    }

    *COMPILED_ROUTES.write().unwrap() = compiled_manifest.routes;
    *COMPILED_SCHEMAS.write().unwrap() = compiled_manifest.schemas;
    *REQUEST_READY_CALLBACK.lock().unwrap() = Some(callback);

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

            let app = Router::new().fallback(any(handle_request));
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
            *REQUEST_READY_CALLBACK.lock().unwrap() = None;
            *COMPILED_ROUTES.write().unwrap() = Vec::new();
            *COMPILED_SCHEMAS.write().unwrap() = HashMap::new();
            let _ = join_handle.join();
            -1
        }
        Err(error) => {
            eprintln!("dart_edge_http_server_runtime transport startup failed: {error}");
            *REQUEST_READY_CALLBACK.lock().unwrap() = None;
            *COMPILED_ROUTES.write().unwrap() = Vec::new();
            *COMPILED_SCHEMAS.write().unwrap() = HashMap::new();
            let _ = join_handle.join();
            -1
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_http_server_runtime_stop_server() {
    *REQUEST_READY_CALLBACK.lock().unwrap() = None;
    *COMPILED_ROUTES.write().unwrap() = Vec::new();
    *COMPILED_SCHEMAS.write().unwrap() = HashMap::new();

    let mut pending = PENDING_REQUESTS.lock().unwrap();
    for (_, mut request) in pending.drain() {
        if let Some(response_tx) = request.response_tx.take() {
            let _ = response_tx.send(TransportResponse {
                status: 503,
                content_type: "text/plain; charset=utf-8".to_string(),
                body: "Server stopped".to_string(),
                headers: Vec::new(),
            });
        }
    }
    drop(pending);

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

    let mut pending = PENDING_REQUESTS.lock().unwrap();
    let Some(mut request) = pending.remove(&request_id) else {
        return false;
    };

    if let Some(response_tx) = request.response_tx.take() {
        response_tx
            .send(TransportResponse {
                status: status as u16,
                content_type,
                body,
                headers,
            })
            .is_ok()
    } else {
        false
    }
}

async fn handle_request(request: Request<Body>) -> Response<Body> {
    let (parts, body) = request.into_parts();
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

    let route_match = match match_route(parts.method.as_str(), parts.uri.path()) {
        Some(route_match) => route_match,
        None => {
            return response(
                StatusCode::NOT_FOUND,
                "text/plain; charset=utf-8",
                "Not found".to_string(),
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
    if let Some(request_body) = route_match.request_body.as_ref() {
        if let Err(error_response) = validate_request_body(&body, request_body) {
            return error_response;
        }
    }

    let request_id = NEXT_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
    let (response_tx, response_rx) = oneshot::channel::<TransportResponse>();
    let transport_request = TransportRequest {
        route_id: route_match.route_id,
        path_params: route_match.path_params,
        query,
        headers,
        body: body.bytes,
        body_kind: body.kind,
    };

    {
        let mut pending = PENDING_REQUESTS.lock().unwrap();
        pending.insert(
            request_id,
            PendingRequest {
                request: Some(transport_request),
                response_tx: Some(response_tx),
            },
        );
    }

    let callback = *REQUEST_READY_CALLBACK.lock().unwrap();
    let Some(callback) = callback else {
        let mut pending = PENDING_REQUESTS.lock().unwrap();
        pending.remove(&request_id);
        return response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "No Dart callback registered".to_string(),
        );
    };

    callback(request_id);

    match response_rx.await {
        Ok(transport_response) => response_with_headers(
            StatusCode::from_u16(transport_response.status)
                .unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            &transport_response.content_type,
            &transport_response.headers,
            transport_response.body,
        ),
        Err(_) => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "text/plain; charset=utf-8",
            "Request handling failed".to_string(),
        ),
    }
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

    Ok(CompiledRoute {
        route_id: route.route_id,
        method: route.method,
        path_segments: route
            .path_segments
            .into_iter()
            .map(|segment| {
                if segment.is_parameter {
                    CompiledRouteSegment::Parameter(segment.value)
                } else {
                    CompiledRouteSegment::Literal(segment.value)
                }
            })
            .collect(),
        params_schema_id: route.params_schema_id,
        query_schema_id: route.query_schema_id,
        headers_schema_id: route.headers_schema_id,
        request_body: route
            .request_body
            .map(|request_body| RequestBodyValidation {
                kind: body_kind(&request_body.content_type),
                content_type: request_body.content_type,
                schema_id: request_body.schema_id,
            }),
    })
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

fn match_route(method: &str, path: &str) -> Option<NativeRouteMatch> {
    let request_segments = path_segments(path);
    let routes = COMPILED_ROUTES.read().unwrap();

    for route in routes.iter() {
        if route.method != method {
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
                route_id: route.route_id.clone(),
                path_params,
                params_schema_id: route.params_schema_id.clone(),
                query_schema_id: route.query_schema_id.clone(),
                headers_schema_id: route.headers_schema_id.clone(),
                request_body: route.request_body.clone(),
            });
        }
    }

    None
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
        NativeBodyKind::None => serde_json::Value::Null,
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
    let mut builder = Response::builder().status(status);
    builder = builder.header(header::CONTENT_TYPE, content_type);
    for (name, value) in headers {
        builder = builder.header(name, value);
    }
    builder
        .body(Body::from(body))
        .unwrap_or_else(|_| Response::new(Body::from("Internal Server Error")))
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

unsafe fn read_c_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }

    unsafe { CStr::from_ptr(value) }
        .to_str()
        .ok()
        .map(ToOwned::to_owned)
}
