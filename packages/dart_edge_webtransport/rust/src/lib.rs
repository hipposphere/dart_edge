use once_cell::sync::Lazy;
use std::collections::{HashMap, VecDeque};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;
use tokio::sync::Notify;
use tokio::sync::mpsc;
use wtransport::endpoint::ConnectOptions;
use wtransport::{ClientConfig, Connection, Endpoint, VarInt};

type TransportEventCallback = unsafe extern "C" fn(i32, i64);

const EVENT_INCOMING_STREAM: i32 = 1;
const EVENT_STREAM_CHUNK_READY: i32 = 2;
const EVENT_STREAM_FINISHED: i32 = 3;
const EVENT_OPERATION_READY: i32 = 4;
const EVENT_DATAGRAM_READY: i32 = 5;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static NEXT_STREAM_HANDLE: AtomicI64 = AtomicI64::new(1);
static NEXT_OPERATION_ID: AtomicI64 = AtomicI64::new(1);
static SESSIONS: Lazy<Mutex<HashMap<i64, NativeWebTransportSession>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static OPENED_STREAMS: Lazy<Mutex<HashMap<i64, WebTransportStreamInfo>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static STREAMS: Lazy<Mutex<HashMap<i64, WebTransportStreamState>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static OPERATIONS: Lazy<Mutex<HashMap<i64, WebTransportOperationResult>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static DATAGRAMS: Lazy<Mutex<HashMap<i64, VecDeque<Vec<u8>>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

#[repr(C)]
pub struct NativeWebTransportConnectConfig {
    url: *mut c_char,
    headers_json: *mut c_char,
    allow_self_signed: bool,
    callback: Option<TransportEventCallback>,
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

#[repr(C)]
pub struct NativeWebTransportStreamInfo {
    session_id: i64,
    stream_id: i64,
    protocol_id: i64,
    kind: u8,
}

#[repr(C)]
pub struct NativeWebTransportStreamChunk {
    stream_id: i64,
    bytes: *mut u8,
    length: i64,
}

#[repr(C)]
pub struct NativeWebTransportStreamTerminal {
    stream_id: i64,
    error_code: i64,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeWebTransportOperation {
    operation_id: i64,
    session_id: i64,
    stream_id: i64,
    protocol_id: i64,
    kind: u8,
    succeeded: bool,
    error: *mut c_char,
}

struct NativeWebTransportSession {
    runtime: Arc<Runtime>,
    _endpoint: Endpoint<wtransport::endpoint::endpoint_side::Client>,
    connection: Connection,
    callback: Option<TransportEventCallback>,
}

#[derive(Clone, Copy)]
struct WebTransportStreamInfo {
    session_id: i64,
    stream_id: i64,
    protocol_id: i64,
    kind: WebTransportStreamKind,
}

struct WebTransportStreamState {
    info: WebTransportStreamInfo,
    chunks: VecDeque<Vec<u8>>,
    terminal: Option<WebTransportStreamTerminal>,
    send_tx: Option<mpsc::Sender<WebTransportStreamCommand>>,
    stop_tx: Option<mpsc::UnboundedSender<u32>>,
    send_closed: bool,
    receive_closed: bool,
    receive_notify: Arc<Notify>,
}

struct WebTransportStreamTerminal {
    error_code: Option<u32>,
    error: String,
}

struct WebTransportOperationResult {
    operation_id: i64,
    session_id: i64,
    stream_id: i64,
    protocol_id: i64,
    kind: WebTransportOperationKind,
    error: Option<String>,
}

#[repr(u8)]
#[derive(Clone, Copy)]
enum WebTransportStreamKind {
    IncomingUnidirectional = 1,
    IncomingBidirectional = 2,
    OutgoingUnidirectional = 3,
    OutgoingBidirectional = 4,
}

#[repr(u8)]
#[derive(Clone, Copy)]
enum WebTransportOperationKind {
    OpenUnidirectional = 1,
    OpenBidirectional = 2,
    Write = 3,
    Finish = 4,
    Reset = 5,
    Stop = 6,
}

enum WebTransportStreamCommand {
    Write { operation_id: i64, body: Vec<u8> },
    Finish { operation_id: i64 },
    Reset { operation_id: i64, error_code: u32 },
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_native_abi_version() -> i64 {
    2
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_connect(
    config: *const NativeWebTransportConnectConfig,
) -> *mut NativeWebTransportConnectResult {
    Box::into_raw(Box::new(unsafe { connect(config) }))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_dispose(handle: i64) {
    SESSIONS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .remove(&handle);
    OPENED_STREAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .retain(|_, stream| stream.session_id != handle);
    STREAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .retain(|_, stream| stream.info.session_id != handle);
    OPERATIONS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .retain(|_, operation| operation.session_id != handle);
    DATAGRAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .remove(&handle);
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
pub extern "C" fn dart_edge_webtransport_take_datagram(
    handle: i64,
) -> *mut NativeWebTransportBytesResult {
    let bytes = DATAGRAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .get_mut(&handle)
        .and_then(VecDeque::pop_front);
    bytes
        .map(|bytes| Box::into_raw(Box::new(bytes_result(bytes))))
        .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_open_unidirectional_stream(
    session_id: i64,
    send_order: i64,
    has_send_order: bool,
) -> i64 {
    submit_open_operation(
        session_id,
        send_order,
        has_send_order,
        WebTransportOperationKind::OpenUnidirectional,
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_open_bidirectional_stream(
    session_id: i64,
    send_order: i64,
    has_send_order: bool,
) -> i64 {
    submit_open_operation(
        session_id,
        send_order,
        has_send_order,
        WebTransportOperationKind::OpenBidirectional,
    )
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_stream_write(
    stream_id: i64,
    bytes: *const u8,
    length: i64,
) -> i64 {
    let Ok(body) = (unsafe { read_payload(bytes, length) }) else {
        return 0;
    };
    submit_send_operation(stream_id, |operation_id| WebTransportStreamCommand::Write {
        operation_id,
        body,
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_stream_finish(stream_id: i64) -> i64 {
    submit_send_operation(stream_id, |operation_id| {
        WebTransportStreamCommand::Finish { operation_id }
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_stream_reset(stream_id: i64, error_code: u32) -> i64 {
    submit_send_operation(stream_id, |operation_id| WebTransportStreamCommand::Reset {
        operation_id,
        error_code,
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_stream_stop(stream_id: i64, error_code: u32) -> i64 {
    let operation_id = NEXT_OPERATION_ID.fetch_add(1, Ordering::Relaxed);
    let info = {
        let streams = STREAMS.lock().unwrap_or_else(|poison| poison.into_inner());
        let Some(stream) = streams.get(&stream_id) else {
            return 0;
        };
        let Some(stop_tx) = stream.stop_tx.as_ref() else {
            return 0;
        };
        if stop_tx.send(error_code).is_err() {
            return 0;
        }
        stream.info
    };
    push_operation(WebTransportOperationResult {
        operation_id,
        session_id: info.session_id,
        stream_id,
        protocol_id: info.protocol_id,
        kind: WebTransportOperationKind::Stop,
        error: None,
    });
    operation_id
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_take_stream_info(
    stream_id: i64,
) -> *mut NativeWebTransportStreamInfo {
    let info = OPENED_STREAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .remove(&stream_id);
    let Some(info) = info else {
        return std::ptr::null_mut();
    };
    Box::into_raw(Box::new(NativeWebTransportStreamInfo {
        session_id: info.session_id,
        stream_id: info.stream_id,
        protocol_id: info.protocol_id,
        kind: info.kind as u8,
    }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_free_stream_info(
    value: *mut NativeWebTransportStreamInfo,
) {
    if !value.is_null() {
        unsafe { drop(Box::from_raw(value)) };
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_take_stream_chunk(
    stream_id: i64,
) -> *mut NativeWebTransportStreamChunk {
    let (body, notify) = {
        let mut streams = STREAMS.lock().unwrap_or_else(|poison| poison.into_inner());
        match streams.get_mut(&stream_id) {
            Some(stream) => (
                stream.chunks.pop_front(),
                Some(stream.receive_notify.clone()),
            ),
            None => (None, None),
        }
    };
    if body.is_some() {
        if let Some(notify) = notify {
            notify.notify_one();
        }
    }
    remove_stream_if_complete(stream_id);
    let Some(body) = body else {
        return std::ptr::null_mut();
    };
    let body = body.into_boxed_slice();
    let length = body.len() as i64;
    let bytes = if body.is_empty() {
        std::ptr::null_mut()
    } else {
        Box::into_raw(body).cast::<u8>()
    };
    Box::into_raw(Box::new(NativeWebTransportStreamChunk {
        stream_id,
        bytes,
        length,
    }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_free_stream_chunk(
    value: *mut NativeWebTransportStreamChunk,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    if !value.bytes.is_null() && value.length > 0 {
        unsafe {
            drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
                value.bytes,
                value.length as usize,
            )));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_take_stream_terminal(
    stream_id: i64,
) -> *mut NativeWebTransportStreamTerminal {
    let terminal = {
        let mut streams = STREAMS.lock().unwrap_or_else(|poison| poison.into_inner());
        streams
            .get_mut(&stream_id)
            .and_then(|stream| stream.terminal.take())
    };
    remove_stream_if_complete(stream_id);
    let Some(terminal) = terminal else {
        return std::ptr::null_mut();
    };
    Box::into_raw(Box::new(NativeWebTransportStreamTerminal {
        stream_id,
        error_code: terminal.error_code.map(i64::from).unwrap_or(-1),
        error: if terminal.error.is_empty() {
            std::ptr::null_mut()
        } else {
            c_string_ptr(terminal.error)
        },
    }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_free_stream_terminal(
    value: *mut NativeWebTransportStreamTerminal,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    free_c_string(value.error);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_webtransport_take_operation(
    operation_id: i64,
) -> *mut NativeWebTransportOperation {
    let operation = OPERATIONS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .remove(&operation_id);
    let Some(operation) = operation else {
        return std::ptr::null_mut();
    };
    let succeeded = operation.error.is_none();
    Box::into_raw(Box::new(NativeWebTransportOperation {
        operation_id,
        session_id: operation.session_id,
        stream_id: operation.stream_id,
        protocol_id: operation.protocol_id,
        kind: operation.kind as u8,
        succeeded,
        error: operation
            .error
            .map(c_string_ptr)
            .unwrap_or(std::ptr::null_mut()),
    }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_webtransport_free_operation(
    value: *mut NativeWebTransportOperation,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    free_c_string(value.error);
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
            drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
                value.bytes,
                value.length as usize,
            )));
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
    SESSIONS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(
            handle,
            NativeWebTransportSession {
                runtime: runtime.clone(),
                _endpoint: endpoint,
                connection: connection.clone(),
                callback: config.callback,
            },
        );
    DATAGRAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(handle, VecDeque::new());
    spawn_incoming_stream_acceptors(handle, runtime, connection);
    NativeWebTransportConnectResult {
        handle,
        error: std::ptr::null_mut(),
    }
}

fn spawn_incoming_stream_acceptors(session_id: i64, runtime: Arc<Runtime>, connection: Connection) {
    let uni_connection = connection.clone();
    let datagram_connection = connection.clone();
    runtime.spawn(async move {
        while let Ok(datagram) = datagram_connection.receive_datagram().await {
            let payload = datagram.payload().to_vec();
            let queued = DATAGRAMS
                .lock()
                .unwrap_or_else(|poison| poison.into_inner())
                .get_mut(&session_id)
                .map(|datagrams| {
                    if datagrams.len() >= 128 {
                        datagrams.pop_front();
                    }
                    datagrams.push_back(payload);
                })
                .is_some();
            if !queued {
                return;
            }
            notify(session_id, EVENT_DATAGRAM_READY, session_id);
        }
    });
    runtime.spawn(async move {
        while let Ok(receive) = uni_connection.accept_uni().await {
            register_incoming_stream(session_id, None, receive);
        }
    });
    runtime.spawn(async move {
        while let Ok((send, receive)) = connection.accept_bi().await {
            register_incoming_stream(session_id, Some(send), receive);
        }
    });
}

fn register_incoming_stream(
    session_id: i64,
    send: Option<wtransport::stream::SendStream>,
    receive: wtransport::stream::RecvStream,
) {
    let stream_id = NEXT_STREAM_HANDLE.fetch_add(1, Ordering::Relaxed);
    let protocol_id = receive.id().into_u64() as i64;
    let kind = if send.is_some() {
        WebTransportStreamKind::IncomingBidirectional
    } else {
        WebTransportStreamKind::IncomingUnidirectional
    };
    let info = WebTransportStreamInfo {
        session_id,
        stream_id,
        protocol_id,
        kind,
    };
    let send_closed = send.is_none();
    let send_tx = send.map(|send| spawn_send_actor(info, send));
    let (stop_tx, stop_rx) = mpsc::unbounded_channel();
    let receive_notify = Arc::new(Notify::new());
    STREAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(
            stream_id,
            WebTransportStreamState {
                info,
                chunks: VecDeque::new(),
                terminal: None,
                send_tx,
                stop_tx: Some(stop_tx),
                send_closed,
                receive_closed: false,
                receive_notify,
            },
        );
    OPENED_STREAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(stream_id, info);
    notify(session_id, EVENT_INCOMING_STREAM, stream_id);
    spawn_receive_task(info, receive, stop_rx);
}

fn submit_open_operation(
    session_id: i64,
    send_order: i64,
    has_send_order: bool,
    kind: WebTransportOperationKind,
) -> i64 {
    let priority = if has_send_order {
        match i32::try_from(send_order) {
            Ok(value) => Some(value),
            Err(_) => return 0,
        }
    } else {
        None
    };
    let (runtime, connection) = match session_runtime_connection(session_id) {
        Ok(value) => value,
        Err(_) => return 0,
    };
    let operation_id = NEXT_OPERATION_ID.fetch_add(1, Ordering::Relaxed);
    runtime.spawn(async move {
        match kind {
            WebTransportOperationKind::OpenUnidirectional => {
                let result = async {
                    let opening = connection
                        .open_uni()
                        .await
                        .map_err(|error| error.to_string())?;
                    opening.await.map_err(|error| error.to_string())
                }
                .await;
                match result {
                    Ok(send) => register_outgoing_stream(
                        session_id,
                        operation_id,
                        kind,
                        WebTransportStreamKind::OutgoingUnidirectional,
                        send,
                        None,
                        priority,
                    ),
                    Err(error) => complete_open_error(session_id, operation_id, kind, error),
                }
            }
            WebTransportOperationKind::OpenBidirectional => {
                let result = async {
                    let opening = connection
                        .open_bi()
                        .await
                        .map_err(|error| error.to_string())?;
                    opening.await.map_err(|error| error.to_string())
                }
                .await;
                match result {
                    Ok((send, receive)) => register_outgoing_stream(
                        session_id,
                        operation_id,
                        kind,
                        WebTransportStreamKind::OutgoingBidirectional,
                        send,
                        Some(receive),
                        priority,
                    ),
                    Err(error) => complete_open_error(session_id, operation_id, kind, error),
                }
            }
            _ => unreachable!(),
        }
    });
    operation_id
}

fn register_outgoing_stream(
    session_id: i64,
    operation_id: i64,
    operation_kind: WebTransportOperationKind,
    stream_kind: WebTransportStreamKind,
    send: wtransport::stream::SendStream,
    receive: Option<wtransport::stream::RecvStream>,
    priority: Option<i32>,
) {
    if let Some(priority) = priority {
        send.set_priority(priority);
    }
    let stream_id = NEXT_STREAM_HANDLE.fetch_add(1, Ordering::Relaxed);
    let protocol_id = send.id().into_u64() as i64;
    let info = WebTransportStreamInfo {
        session_id,
        stream_id,
        protocol_id,
        kind: stream_kind,
    };
    let send_tx = spawn_send_actor(info, send);
    let (stop_tx, stop_rx) = if receive.is_some() {
        let (tx, rx) = mpsc::unbounded_channel();
        (Some(tx), Some(rx))
    } else {
        (None, None)
    };
    let receive_notify = Arc::new(Notify::new());
    STREAMS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(
            stream_id,
            WebTransportStreamState {
                info,
                chunks: VecDeque::new(),
                terminal: None,
                send_tx: Some(send_tx),
                stop_tx,
                send_closed: false,
                receive_closed: receive.is_none(),
                receive_notify,
            },
        );
    push_operation(WebTransportOperationResult {
        operation_id,
        session_id,
        stream_id,
        protocol_id,
        kind: operation_kind,
        error: None,
    });
    if let (Some(receive), Some(stop_rx)) = (receive, stop_rx) {
        spawn_receive_task(info, receive, stop_rx);
    }
}

fn complete_open_error(
    session_id: i64,
    operation_id: i64,
    kind: WebTransportOperationKind,
    error: String,
) {
    push_operation(WebTransportOperationResult {
        operation_id,
        session_id,
        stream_id: 0,
        protocol_id: 0,
        kind,
        error: Some(error),
    });
}

fn spawn_send_actor(
    info: WebTransportStreamInfo,
    mut send: wtransport::stream::SendStream,
) -> mpsc::Sender<WebTransportStreamCommand> {
    let (tx, mut rx) = mpsc::channel(16);
    let Ok((runtime, _)) = session_runtime_connection(info.session_id) else {
        return tx;
    };
    runtime.spawn(async move {
        while let Some(command) = rx.recv().await {
            let (operation_id, kind, result, terminal) = match command {
                WebTransportStreamCommand::Write { operation_id, body } => (
                    operation_id,
                    WebTransportOperationKind::Write,
                    send.write_all(&body)
                        .await
                        .map_err(|error| error.to_string()),
                    false,
                ),
                WebTransportStreamCommand::Finish { operation_id } => (
                    operation_id,
                    WebTransportOperationKind::Finish,
                    send.finish().await.map_err(|error| error.to_string()),
                    true,
                ),
                WebTransportStreamCommand::Reset {
                    operation_id,
                    error_code,
                } => (
                    operation_id,
                    WebTransportOperationKind::Reset,
                    send.reset(VarInt::from_u32(error_code))
                        .map_err(|error| error.to_string()),
                    true,
                ),
            };
            push_operation(WebTransportOperationResult {
                operation_id,
                session_id: info.session_id,
                stream_id: info.stream_id,
                protocol_id: info.protocol_id,
                kind,
                error: result.err(),
            });
            if terminal {
                if let Some(stream) = STREAMS
                    .lock()
                    .unwrap_or_else(|poison| poison.into_inner())
                    .get_mut(&info.stream_id)
                {
                    stream.send_closed = true;
                    stream.send_tx = None;
                }
                remove_stream_if_complete(info.stream_id);
                break;
            }
        }
    });
    tx
}

fn spawn_receive_task(
    info: WebTransportStreamInfo,
    mut receive: wtransport::stream::RecvStream,
    mut stop_rx: mpsc::UnboundedReceiver<u32>,
) {
    let Ok((runtime, _)) = session_runtime_connection(info.session_id) else {
        return;
    };
    runtime.spawn(async move {
        let mut buffer = [0u8; 16 * 1024];
        let terminal = 'read: loop {
            loop {
                let wait = {
                    let streams = STREAMS.lock().unwrap_or_else(|poison| poison.into_inner());
                    let Some(stream) = streams.get(&info.stream_id) else {
                        return;
                    };
                    (stream.chunks.len() >= 32).then(|| stream.receive_notify.clone())
                };
                match wait {
                    Some(notify) => {
                        tokio::select! {
                            _ = notify.notified() => {}
                            stop = stop_rx.recv() => {
                                let error_code = stop.unwrap_or_default();
                                receive.stop(VarInt::from_u32(error_code));
                                break 'read WebTransportStreamTerminal {
                                    error_code: Some(error_code),
                                    error: "receive stopped locally".to_string(),
                                };
                            }
                        }
                    }
                    None => break,
                }
            }
            tokio::select! {
                stop = stop_rx.recv() => {
                    let error_code = stop.unwrap_or_default();
                    receive.stop(VarInt::from_u32(error_code));
                    break WebTransportStreamTerminal {
                        error_code: Some(error_code),
                        error: "receive stopped locally".to_string(),
                    };
                }
                result = receive.read(&mut buffer) => {
                    match result {
                        Ok(Some(bytes_read)) => {
                            let body = buffer[..bytes_read].to_vec();
                            if let Some(stream) = STREAMS
                                .lock()
                                .unwrap_or_else(|poison| poison.into_inner())
                                .get_mut(&info.stream_id)
                            {
                                stream.chunks.push_back(body);
                            } else {
                                return;
                            }
                            notify(info.session_id, EVENT_STREAM_CHUNK_READY, info.stream_id);
                        }
                        Ok(None) => break WebTransportStreamTerminal {
                            error_code: None,
                            error: String::new(),
                        },
                        Err(error) => {
                            let error_code = match error {
                                wtransport::error::StreamReadError::Reset(code) => {
                                    Some(code.into_inner() as u32)
                                }
                                _ => None,
                            };
                            break WebTransportStreamTerminal {
                                error_code,
                                error: error.to_string(),
                            };
                        }
                    }
                }
            }
        };
        if let Some(stream) = STREAMS
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
            .get_mut(&info.stream_id)
        {
            stream.terminal = Some(terminal);
            stream.stop_tx = None;
            stream.receive_closed = true;
        }
        notify(info.session_id, EVENT_STREAM_FINISHED, info.stream_id);
    });
}

fn submit_send_operation(
    stream_id: i64,
    command: impl FnOnce(i64) -> WebTransportStreamCommand,
) -> i64 {
    let operation_id = NEXT_OPERATION_ID.fetch_add(1, Ordering::Relaxed);
    let streams = STREAMS.lock().unwrap_or_else(|poison| poison.into_inner());
    let Some(send_tx) = streams
        .get(&stream_id)
        .and_then(|stream| stream.send_tx.as_ref())
    else {
        return 0;
    };
    match send_tx.try_send(command(operation_id)) {
        Ok(()) => operation_id,
        Err(_) => 0,
    }
}

fn push_operation(operation: WebTransportOperationResult) {
    let operation_id = operation.operation_id;
    let session_id = operation.session_id;
    OPERATIONS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(operation_id, operation);
    notify(session_id, EVENT_OPERATION_READY, operation_id);
}

fn notify(session_id: i64, event_kind: i32, event_id: i64) {
    let callback = SESSIONS
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .get(&session_id)
        .and_then(|session| session.callback);
    if let Some(callback) = callback {
        unsafe { callback(event_kind, event_id) };
    }
}

fn remove_stream_if_complete(stream_id: i64) {
    let mut streams = STREAMS.lock().unwrap_or_else(|poison| poison.into_inner());
    let remove = streams.get(&stream_id).is_some_and(|stream| {
        stream.send_closed
            && stream.receive_closed
            && stream.terminal.is_none()
            && stream.chunks.is_empty()
    });
    if remove {
        streams.remove(&stream_id);
    }
}

unsafe fn send_datagram(handle: i64, bytes: *const u8, length: i64) -> Result<(), String> {
    let payload = unsafe { read_payload_slice(bytes, length, "Datagram")? };
    with_session(handle, |session| {
        session
            .connection
            .send_datagram(payload)
            .map_err(|error| format!("Failed to send WebTransport datagram: {error}"))
    })
}

unsafe fn close(handle: i64, code: i64, reason: *const c_char) -> Result<(), String> {
    let reason = unsafe { read_optional_string(reason)? }.unwrap_or_default();
    let code = u32::try_from(code).map_err(|_| "WebTransport close code is out of range.")?;
    with_session(handle, |session| {
        session
            .connection
            .close(VarInt::from_u32(code), reason.as_bytes());
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

fn session_runtime_connection(handle: i64) -> Result<(Arc<Runtime>, Connection), String> {
    with_session(handle, |session| {
        Ok((session.runtime.clone(), session.connection.clone()))
    })
}

unsafe fn read_payload(bytes: *const u8, length: i64) -> Result<Vec<u8>, String> {
    Ok(unsafe { read_payload_slice(bytes, length, "Payload")? }.to_vec())
}

unsafe fn read_payload_slice<'a>(
    bytes: *const u8,
    length: i64,
    name: &str,
) -> Result<&'a [u8], String> {
    if length < 0 {
        return Err(format!("{name} length must not be negative."));
    }
    if length == 0 {
        return Ok(&[]);
    }
    if bytes.is_null() {
        return Err(format!("{name} bytes pointer is null."));
    }
    Ok(unsafe { std::slice::from_raw_parts(bytes, length as usize) })
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
    let bytes = bytes.into_boxed_slice();
    let length = bytes.len() as i64;
    let ptr = if bytes.is_empty() {
        std::ptr::null_mut()
    } else {
        Box::into_raw(bytes).cast::<u8>()
    };
    NativeWebTransportBytesResult {
        bytes: ptr,
        length,
        error: std::ptr::null_mut(),
    }
}

fn c_string_ptr(message: impl Into<String>) -> *mut c_char {
    CString::new(message.into())
        .unwrap_or_else(|_| CString::new("dart_edge_webtransport native error").unwrap())
        .into_raw()
}

fn free_c_string(value: *mut c_char) {
    if !value.is_null() {
        unsafe { drop(CString::from_raw(value)) };
    }
}
