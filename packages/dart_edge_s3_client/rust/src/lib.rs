use std::collections::{HashMap, HashSet};
use std::ffi::{CStr, CString, c_char, c_void};
use std::io;
use std::mem::size_of;
use std::pin::Pin;
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};
use std::task::{Context, Poll};

use aws_config::BehaviorVersion;
use aws_credential_types::Credentials;
use aws_sdk_s3::Client;
use aws_sdk_s3::config::Builder as S3ConfigBuilder;
use aws_sdk_s3::primitives::ByteStream;
use aws_types::region::Region;
use bytes::Bytes;
use dart_edge_core::{
    NATIVE_BYTE_STREAM_ABI_VERSION, NATIVE_BYTE_STREAM_READ_CANCELED,
    NATIVE_BYTE_STREAM_READ_CHUNK, NATIVE_BYTE_STREAM_READ_DONE, NATIVE_BYTE_STREAM_READ_ERROR,
    NativeByteStream, NativeByteStreamFreeRead, NativeByteStreamRead, NativeBytes,
    NativeOwnedBytes, free_owned_bytes, into_native_owned_bytes,
};
use http_body::{Body, Frame, SizeHint};
use once_cell::sync::Lazy;
use tokio::runtime::{Builder, Runtime};

const DART_EDGE_S3_CLIENT_NATIVE_ABI_VERSION: i32 = 7;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static NEXT_DOWNLOAD_HANDLE: AtomicI64 = AtomicI64::new(1);
static DOWNLOADS_STARTED: AtomicI64 = AtomicI64::new(0);
static DOWNLOADS_COMPLETED: AtomicI64 = AtomicI64::new(0);
static DOWNLOADS_CANCELED: AtomicI64 = AtomicI64::new(0);
static DOWNLOADS_FAILED: AtomicI64 = AtomicI64::new(0);
static CLIENTS: Lazy<Mutex<HashMap<i64, Client>>> = Lazy::new(|| Mutex::new(HashMap::new()));
static DOWNLOADS: Lazy<Mutex<DownloadRegistry>> =
    Lazy::new(|| Mutex::new(DownloadRegistry::default()));
static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to create dart_edge_s3_client runtime")
});

#[repr(C)]
pub struct NativeS3StringPair {
    key: *mut c_char,
    value: *mut c_char,
}

#[repr(C)]
pub struct NativeS3ClientConfig {
    region: *const c_char,
    endpoint: *const c_char,
    access_key_id: *const c_char,
    secret_access_key: *const c_char,
    session_token: *const c_char,
    force_path_style: bool,
    allow_http: bool,
}

#[repr(C)]
pub struct NativeS3ObjectRef {
    bucket: *const c_char,
    key: *const c_char,
    version_id: *const c_char,
    range: *const c_char,
}

#[repr(C)]
pub struct NativeS3PutObjectRequest {
    bucket: *const c_char,
    key: *const c_char,
    content_type: *const c_char,
    cache_control: *const c_char,
    content_disposition: *const c_char,
    content_encoding: *const c_char,
    content_language: *const c_char,
    metadata: *const NativeS3StringPair,
    metadata_len: isize,
}

#[repr(C)]
pub struct NativeS3CreateResult {
    handle: i64,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3PutObjectResult {
    bucket: *mut c_char,
    key: *mut c_char,
    e_tag: *mut c_char,
    version_id: *mut c_char,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3DeleteObjectResult {
    bucket: *mut c_char,
    key: *mut c_char,
    has_delete_marker: bool,
    delete_marker: bool,
    version_id: *mut c_char,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3ObjectMetadata {
    bucket: *mut c_char,
    key: *mut c_char,
    version_id: *mut c_char,
    e_tag: *mut c_char,
    content_type: *mut c_char,
    content_length: i64,
    object_length: i64,
    content_range: *mut c_char,
    cache_control: *mut c_char,
    content_disposition: *mut c_char,
    content_encoding: *mut c_char,
    content_language: *mut c_char,
    metadata: *mut NativeS3StringPair,
    metadata_len: isize,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3BytesResult {
    bytes: NativeOwnedBytes,
    metadata: NativeS3ObjectMetadata,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3StreamStartResult {
    download_handle: i64,
    metadata: NativeS3ObjectMetadata,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3NativeStreamStartResult {
    stream: NativeByteStream,
    metadata: NativeS3ObjectMetadata,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeS3StreamChunkResult {
    bytes: NativeOwnedBytes,
    done: bool,
    error: *mut c_char,
}

struct S3ClientConfig {
    region: Option<String>,
    endpoint: Option<String>,
    access_key_id: Option<String>,
    secret_access_key: Option<String>,
    session_token: Option<String>,
    force_path_style: bool,
    allow_http: bool,
}

struct ActiveDownload {
    client_handle: i64,
    body: ByteStream,
}

enum DownloadRead {
    Chunk(Bytes),
    Done,
}

/// Producer-owned stream read whose C-compatible prefix is shared with the
/// HTTP runtime. `_chunk` keeps the original AWS allocation alive until the
/// consumer invokes `free_read`; only its pointer and length cross the ABI.
#[repr(C)]
struct S3NativeByteStreamRead {
    read: NativeByteStreamRead,
    _chunk: Option<Bytes>,
    _error: Option<CString>,
}

impl S3NativeByteStreamRead {
    fn chunk(chunk: Bytes) -> Self {
        let bytes = NativeOwnedBytes {
            ptr: chunk.as_ptr().cast_mut(),
            len: chunk.len() as isize,
        };
        Self {
            read: NativeByteStreamRead {
                status: NATIVE_BYTE_STREAM_READ_CHUNK,
                bytes,
                error: NativeBytes::empty(),
            },
            _chunk: Some(chunk),
            _error: None,
        }
    }

    fn done() -> Self {
        Self {
            read: NativeByteStreamRead {
                status: NATIVE_BYTE_STREAM_READ_DONE,
                bytes: NativeOwnedBytes::empty(),
                error: NativeBytes::empty(),
            },
            _chunk: None,
            _error: None,
        }
    }

    fn error(error: impl Into<String>) -> Self {
        let error = CString::new(error.into().replace('\0', "\\0"))
            .expect("sanitized S3 stream error should not contain NUL");
        let error_bytes = NativeBytes {
            ptr: error.as_ptr().cast::<u8>(),
            len: error.as_bytes().len() as isize,
        };
        Self {
            read: NativeByteStreamRead {
                status: NATIVE_BYTE_STREAM_READ_ERROR,
                bytes: NativeOwnedBytes::empty(),
                error: error_bytes,
            },
            _chunk: None,
            _error: Some(error),
        }
    }

    fn into_raw(self) -> *mut NativeByteStreamRead {
        Box::into_raw(Box::new(self)).cast::<NativeByteStreamRead>()
    }
}

#[derive(Default)]
struct DownloadRegistry {
    available: HashMap<i64, ActiveDownload>,
    in_flight: HashMap<i64, i64>,
    canceled_in_flight: HashSet<i64>,
}

struct ObjectRef {
    bucket: String,
    key: String,
    version_id: Option<String>,
    range: Option<String>,
}

struct PutObjectBytesRequest {
    bucket: String,
    key: String,
    content_type: Option<String>,
    cache_control: Option<String>,
    content_disposition: Option<String>,
    content_encoding: Option<String>,
    content_language: Option<String>,
    metadata: HashMap<String, String>,
}

/// Single-owner native producer body adopted by one S3 PUT request.
///
/// Each producer chunk is wrapped by [`Bytes::from_owner`], so the AWS HTTP
/// stack reads the producer allocation directly and invokes `free_read` only
/// after it has finished with that chunk.
struct NativeUploadBody {
    stream: NativeByteStream,
    remaining: u64,
    completed: bool,
}

impl NativeUploadBody {
    fn new(stream: NativeByteStream, content_length: i64) -> Result<Self, String> {
        let mut owned = Self {
            stream,
            remaining: 0,
            completed: false,
        };
        if !owned.stream.is_valid() {
            return Err("Native S3 upload stream descriptor is invalid.".to_string());
        }
        owned.remaining = u64::try_from(content_length)
            .map_err(|_| "Native S3 upload content length must not be negative.".to_string())?;
        Ok(owned)
    }

    fn next_frame(&mut self) -> Result<Option<Frame<Bytes>>, io::Error> {
        if self.completed {
            return Ok(None);
        }
        let next = self
            .stream
            .next
            .ok_or_else(|| io::Error::other("Native S3 upload stream has no next callback."))?;
        let free_read = self.stream.free_read.ok_or_else(|| {
            io::Error::other("Native S3 upload stream has no result release callback.")
        })?;
        let read = unsafe { next(self.stream.context) };
        if read.is_null() {
            return Err(io::Error::other(
                "Native S3 upload stream returned a null read result.",
            ));
        }
        let status = unsafe { (*read).status };
        match status {
            NATIVE_BYTE_STREAM_READ_CHUNK => {
                let owner = NativeUploadRead::new(read, free_read)?;
                let chunk_length = owner.len() as u64;
                if chunk_length > self.remaining {
                    return Err(io::Error::other(format!(
                        "Native S3 upload stream exceeded its declared content length by {} bytes.",
                        chunk_length - self.remaining
                    )));
                }
                self.remaining -= chunk_length;
                Ok(Some(Frame::data(Bytes::from_owner(owner))))
            }
            NATIVE_BYTE_STREAM_READ_DONE => {
                unsafe { free_read(read) };
                if self.remaining != 0 {
                    return Err(io::Error::other(format!(
                        "Native S3 upload stream ended with {} declared bytes remaining.",
                        self.remaining
                    )));
                }
                self.completed = true;
                Ok(None)
            }
            NATIVE_BYTE_STREAM_READ_CANCELED => {
                unsafe { free_read(read) };
                Err(io::Error::other("Native S3 upload stream was canceled."))
            }
            NATIVE_BYTE_STREAM_READ_ERROR => {
                let error = unsafe { read_native_stream_error(read) };
                unsafe { free_read(read) };
                Err(io::Error::other(error))
            }
            other => {
                unsafe { free_read(read) };
                Err(io::Error::other(format!(
                    "Native S3 upload stream returned unknown status {other}."
                )))
            }
        }
    }
}

impl Body for NativeUploadBody {
    type Data = Bytes;
    type Error = io::Error;

    fn poll_frame(
        mut self: Pin<&mut Self>,
        _cx: &mut Context<'_>,
    ) -> Poll<Option<Result<Frame<Self::Data>, Self::Error>>> {
        Poll::Ready(self.next_frame().transpose())
    }

    fn is_end_stream(&self) -> bool {
        self.completed
    }

    fn size_hint(&self) -> SizeHint {
        SizeHint::with_exact(self.remaining)
    }
}

impl Drop for NativeUploadBody {
    fn drop(&mut self) {
        unsafe {
            if !self.completed
                && let Some(cancel) = self.stream.cancel
            {
                cancel(self.stream.context);
            }
            if let Some(release) = self.stream.release {
                release(self.stream.context);
            }
        }
    }
}

struct NativeUploadRead {
    read: *mut NativeByteStreamRead,
    free_read: NativeByteStreamFreeRead,
}

impl NativeUploadRead {
    fn new(
        read: *mut NativeByteStreamRead,
        free_read: NativeByteStreamFreeRead,
    ) -> Result<Self, io::Error> {
        let bytes = unsafe { (*read).bytes };
        if bytes.len < 0 || (bytes.len > 0 && bytes.ptr.is_null()) {
            unsafe { free_read(read) };
            return Err(io::Error::other(
                "Native S3 upload stream returned invalid chunk bytes.",
            ));
        }
        Ok(Self { read, free_read })
    }

    fn len(&self) -> usize {
        usize::try_from(unsafe { (*self.read).bytes.len }).unwrap_or(0)
    }
}

impl AsRef<[u8]> for NativeUploadRead {
    fn as_ref(&self) -> &[u8] {
        let bytes = unsafe { (*self.read).bytes };
        if bytes.len == 0 {
            return &[];
        }
        unsafe { std::slice::from_raw_parts(bytes.ptr, bytes.len as usize) }
    }
}

impl Drop for NativeUploadRead {
    fn drop(&mut self) {
        unsafe { (self.free_read)(self.read) };
    }
}

unsafe impl Send for NativeUploadRead {}

struct PutObjectResult {
    bucket: String,
    key: String,
    e_tag: Option<String>,
    version_id: Option<String>,
}

struct DeleteObjectResult {
    bucket: String,
    key: String,
    delete_marker: Option<bool>,
    version_id: Option<String>,
}

struct ObjectMetadata {
    bucket: String,
    key: String,
    version_id: Option<String>,
    e_tag: Option<String>,
    content_type: Option<String>,
    content_length: i64,
    object_length: i64,
    content_range: Option<String>,
    cache_control: Option<String>,
    content_disposition: Option<String>,
    content_encoding: Option<String>,
    content_language: Option<String>,
    metadata: HashMap<String, String>,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_native_abi_version() -> i32 {
    DART_EDGE_S3_CLIENT_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_create(
    config: *const NativeS3ClientConfig,
) -> *mut NativeS3CreateResult {
    let result = match unsafe { read_client_config(config) } {
        Ok(config) => match RUNTIME.block_on(build_client(config)) {
            Ok(client) => {
                let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
                CLIENTS.lock().unwrap().insert(handle, client);
                NativeS3CreateResult {
                    handle,
                    error: std::ptr::null_mut(),
                }
            }
            Err(error) => create_result_error(error),
        },
        Err(error) => create_result_error(error),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_dispose(handle: i64) {
    CLIENTS.lock().unwrap().remove(&handle);
    let canceled = {
        let mut downloads = DOWNLOADS.lock().unwrap();
        let handles = downloads
            .available
            .iter()
            .filter_map(|(download_handle, download)| {
                (download.client_handle == handle).then_some(*download_handle)
            })
            .collect::<Vec<_>>();
        let canceled = handles.len() as i64;
        for download_handle in handles {
            downloads.available.remove(&download_handle);
        }
        let in_flight = downloads
            .in_flight
            .iter()
            .filter_map(|(download_handle, client_handle)| {
                (*client_handle == handle).then_some(*download_handle)
            })
            .collect::<Vec<_>>();
        let mut newly_canceled_in_flight = 0;
        for download_handle in in_flight {
            if downloads.canceled_in_flight.insert(download_handle) {
                newly_canceled_in_flight += 1;
            }
        }
        canceled + newly_canceled_in_flight
    };
    DOWNLOADS_CANCELED.fetch_add(canceled, Ordering::Relaxed);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_active_download_count() -> i64 {
    let downloads = DOWNLOADS.lock().unwrap();
    (downloads.available.len() + downloads.in_flight.len()) as i64
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_downloads_started_count() -> i64 {
    DOWNLOADS_STARTED.load(Ordering::Relaxed)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_downloads_completed_count() -> i64 {
    DOWNLOADS_COMPLETED.load(Ordering::Relaxed)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_downloads_canceled_count() -> i64 {
    DOWNLOADS_CANCELED.load(Ordering::Relaxed)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_downloads_failed_count() -> i64 {
    DOWNLOADS_FAILED.load(Ordering::Relaxed)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_put_object_bytes(
    handle: i64,
    request: *const NativeS3PutObjectRequest,
    bytes_ptr: *const u8,
    bytes_len: isize,
) -> *mut NativeS3PutObjectResult {
    let result = match client_for_handle(handle) {
        Some(client) => match unsafe { read_put_object_request(request) } {
            Ok(request) => match unsafe { read_input_bytes(bytes_ptr, bytes_len) } {
                Some(bytes) => match RUNTIME.block_on(put_object_bytes(client, request, bytes)) {
                    Ok(result) => native_put_object_result(result),
                    Err(error) => put_object_result_error(error),
                },
                None => put_object_result_error("Invalid putObject byte input."),
            },
            Err(error) => put_object_result_error(error),
        },
        None => put_object_result_error("Unknown dart_edge_s3_client handle."),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_s3_client_put_object_native_stream(
    handle: i64,
    request: *const NativeS3PutObjectRequest,
    stream: *const NativeByteStream,
    content_length: i64,
) -> *mut NativeS3PutObjectResult {
    // Adoption happens before client/request validation. Once a descriptor is
    // provided, this function releases its producer context on every outcome.
    let result = if stream.is_null() {
        Err("Missing native S3 upload stream descriptor.".to_string())
    } else {
        let descriptor = unsafe { *stream };
        put_object_native_stream_inner(handle, request, descriptor, content_length)
    }
    .unwrap_or_else(put_object_result_error);
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_get_object_bytes(
    handle: i64,
    request: *const NativeS3ObjectRef,
) -> *mut NativeS3BytesResult {
    let result = match client_for_handle(handle) {
        Some(client) => match unsafe { read_object_ref(request) } {
            Ok(request) => match RUNTIME.block_on(get_object_bytes(client, request)) {
                Ok((bytes, metadata)) => NativeS3BytesResult {
                    bytes: into_native_owned_bytes(bytes),
                    metadata: native_object_metadata(metadata),
                    error: std::ptr::null_mut(),
                },
                Err(error) => bytes_result_error(error),
            },
            Err(error) => bytes_result_error(error),
        },
        None => bytes_result_error("Unknown dart_edge_s3_client handle."),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_start_get_object_stream(
    handle: i64,
    request: *const NativeS3ObjectRef,
) -> *mut NativeS3StreamStartResult {
    let result = match client_for_handle(handle) {
        Some(client) => match unsafe { read_object_ref(request) } {
            Ok(request) => match RUNTIME.block_on(start_get_object_stream(client, request)) {
                Ok((body, metadata)) => {
                    let download_handle = NEXT_DOWNLOAD_HANDLE.fetch_add(1, Ordering::Relaxed);
                    DOWNLOADS.lock().unwrap().available.insert(
                        download_handle,
                        ActiveDownload {
                            client_handle: handle,
                            body,
                        },
                    );
                    DOWNLOADS_STARTED.fetch_add(1, Ordering::Relaxed);
                    NativeS3StreamStartResult {
                        download_handle,
                        metadata: native_object_metadata(metadata),
                        error: std::ptr::null_mut(),
                    }
                }
                Err(error) => stream_start_result_error(error),
            },
            Err(error) => stream_start_result_error(error),
        },
        None => stream_start_result_error("Unknown dart_edge_s3_client handle."),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_start_get_object_native_stream(
    handle: i64,
    request: *const NativeS3ObjectRef,
) -> *mut NativeS3NativeStreamStartResult {
    let start_ptr = dart_edge_s3_client_start_get_object_stream(handle, request);
    if start_ptr.is_null() {
        return Box::into_raw(Box::new(native_stream_start_result_error(
            "Failed to start S3 native stream.",
        )));
    }
    let start = unsafe { Box::from_raw(start_ptr) };
    if !start.error.is_null() {
        return Box::into_raw(Box::new(NativeS3NativeStreamStartResult {
            stream: empty_native_byte_stream(),
            metadata: start.metadata,
            error: start.error,
        }));
    }

    let context = start.download_handle as isize as *mut c_void;
    Box::into_raw(Box::new(NativeS3NativeStreamStartResult {
        stream: NativeByteStream {
            abi_version: NATIVE_BYTE_STREAM_ABI_VERSION,
            struct_size: size_of::<NativeByteStream>(),
            context,
            next: Some(s3_native_stream_next),
            cancel: Some(s3_native_stream_cancel),
            free_read: Some(s3_native_stream_free_read),
            release: Some(s3_native_stream_release),
        },
        metadata: start.metadata,
        error: std::ptr::null_mut(),
    }))
}

unsafe extern "C" fn s3_native_stream_next(context: *mut c_void) -> *mut NativeByteStreamRead {
    let handle = context as isize as i64;
    match next_get_object_stream_chunk(handle) {
        Ok(DownloadRead::Chunk(chunk)) => S3NativeByteStreamRead::chunk(chunk).into_raw(),
        Ok(DownloadRead::Done) => S3NativeByteStreamRead::done().into_raw(),
        Err(error) => S3NativeByteStreamRead::error(error).into_raw(),
    }
}

unsafe extern "C" fn s3_native_stream_cancel(context: *mut c_void) {
    dart_edge_s3_client_cancel_get_object_stream(context as isize as i64);
}

unsafe extern "C" fn s3_native_stream_free_read(value: *mut NativeByteStreamRead) {
    if value.is_null() {
        return;
    }
    unsafe { drop(Box::from_raw(value.cast::<S3NativeByteStreamRead>())) };
}

unsafe extern "C" fn s3_native_stream_release(context: *mut c_void) {
    let download_handle = context as isize as i64;
    let completed = DOWNLOADS
        .lock()
        .unwrap()
        .available
        .remove(&download_handle)
        .is_some();
    if completed {
        DOWNLOADS_COMPLETED.fetch_add(1, Ordering::Relaxed);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_next_get_object_stream_chunk(
    download_handle: i64,
) -> *mut NativeS3StreamChunkResult {
    let result = match next_get_object_stream_chunk(download_handle) {
        // The Dart-facing stream materializes this allocation into a
        // TransferableTypedData. Native HTTP delivery bypasses this branch.
        Ok(DownloadRead::Chunk(bytes)) => NativeS3StreamChunkResult {
            bytes: into_native_owned_bytes(bytes.to_vec()),
            done: false,
            error: std::ptr::null_mut(),
        },
        Ok(DownloadRead::Done) => NativeS3StreamChunkResult {
            bytes: NativeOwnedBytes::empty(),
            done: true,
            error: std::ptr::null_mut(),
        },
        Err(error) => stream_chunk_result_error(error),
    };
    Box::into_raw(Box::new(result))
}

fn next_get_object_stream_chunk(download_handle: i64) -> Result<DownloadRead, String> {
    let mut download = {
        let mut downloads = DOWNLOADS.lock().unwrap();
        let Some(download) = downloads.available.remove(&download_handle) else {
            return Err("Unknown S3 download stream handle.".to_string());
        };
        downloads
            .in_flight
            .insert(download_handle, download.client_handle);
        download
    };

    // Native consumers may invoke this producer callback from one of their
    // Tokio workers. Enter a supported blocking section before driving the S3
    // body on our runtime instead of recursively calling `Runtime::block_on`.
    let next = if tokio::runtime::Handle::try_current().is_ok() {
        tokio::task::block_in_place(|| RUNTIME.handle().block_on(download.body.next()))
    } else {
        RUNTIME.block_on(download.body.next())
    };
    let canceled = {
        let mut downloads = DOWNLOADS.lock().unwrap();
        downloads.in_flight.remove(&download_handle);
        downloads.canceled_in_flight.remove(&download_handle)
    };
    if canceled {
        Ok(DownloadRead::Done)
    } else {
        match next {
            Some(Ok(bytes)) => {
                DOWNLOADS
                    .lock()
                    .unwrap()
                    .available
                    .insert(download_handle, download);
                Ok(DownloadRead::Chunk(bytes))
            }
            Some(Err(error)) => {
                DOWNLOADS_FAILED.fetch_add(1, Ordering::Relaxed);
                Err(format!("Failed to read S3 object stream: {error}"))
            }
            None => {
                DOWNLOADS_COMPLETED.fetch_add(1, Ordering::Relaxed);
                Ok(DownloadRead::Done)
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_cancel_get_object_stream(download_handle: i64) {
    let canceled = {
        let mut downloads = DOWNLOADS.lock().unwrap();
        if downloads.available.remove(&download_handle).is_some() {
            true
        } else if downloads.in_flight.contains_key(&download_handle) {
            downloads.canceled_in_flight.insert(download_handle)
        } else {
            false
        }
    };
    if canceled {
        DOWNLOADS_CANCELED.fetch_add(1, Ordering::Relaxed);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_head_object(
    handle: i64,
    request: *const NativeS3ObjectRef,
) -> *mut NativeS3ObjectMetadata {
    let result = match client_for_handle(handle) {
        Some(client) => match unsafe { read_object_ref(request) } {
            Ok(request) => match RUNTIME.block_on(head_object(client, request)) {
                Ok(metadata) => native_object_metadata(metadata),
                Err(error) => object_metadata_error(error),
            },
            Err(error) => object_metadata_error(error),
        },
        None => object_metadata_error("Unknown dart_edge_s3_client handle."),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_delete_object(
    handle: i64,
    request: *const NativeS3ObjectRef,
) -> *mut NativeS3DeleteObjectResult {
    let result = match client_for_handle(handle) {
        Some(client) => match unsafe { read_object_ref(request) } {
            Ok(request) => match RUNTIME.block_on(delete_object(client, request)) {
                Ok(result) => native_delete_object_result(result),
                Err(error) => delete_object_result_error(error),
            },
            Err(error) => delete_object_result_error(error),
        },
        None => delete_object_result_error("Unknown dart_edge_s3_client handle."),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_create_result(value: *mut NativeS3CreateResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let value = Box::from_raw(value);
        free_c_string(value.error);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_put_object_result(value: *mut NativeS3PutObjectResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let value = Box::from_raw(value);
        free_c_string(value.bucket);
        free_c_string(value.key);
        free_c_string(value.e_tag);
        free_c_string(value.version_id);
        free_c_string(value.error);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_delete_object_result(
    value: *mut NativeS3DeleteObjectResult,
) {
    if value.is_null() {
        return;
    }

    unsafe {
        let value = Box::from_raw(value);
        free_c_string(value.bucket);
        free_c_string(value.key);
        free_c_string(value.version_id);
        free_c_string(value.error);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_object_metadata(value: *mut NativeS3ObjectMetadata) {
    if value.is_null() {
        return;
    }

    unsafe {
        let mut value = Box::from_raw(value);
        free_object_metadata_fields(&mut value);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_bytes_result(value: *mut NativeS3BytesResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let mut value = Box::from_raw(value);
        free_owned_bytes(value.bytes);
        free_object_metadata_fields(&mut value.metadata);
        free_c_string(value.error);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_stream_start_result(
    value: *mut NativeS3StreamStartResult,
) {
    if value.is_null() {
        return;
    }
    unsafe {
        let mut value = Box::from_raw(value);
        free_object_metadata_fields(&mut value.metadata);
        free_c_string(value.error);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_native_stream_start_result(
    value: *mut NativeS3NativeStreamStartResult,
) {
    if value.is_null() {
        return;
    }
    unsafe {
        let mut value = Box::from_raw(value);
        free_object_metadata_fields(&mut value.metadata);
        free_c_string(value.error);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_stream_chunk_result(
    value: *mut NativeS3StreamChunkResult,
) {
    if value.is_null() {
        return;
    }
    unsafe {
        let value = Box::from_raw(value);
        free_owned_bytes(value.bytes);
        free_c_string(value.error);
    }
}

async fn build_client(config: S3ClientConfig) -> Result<Client, String> {
    validate_client_config(&config)?;

    let mut loader = aws_config::defaults(BehaviorVersion::latest());
    if let Some(region) = config.region.as_ref() {
        loader = loader.region(Region::new(region.clone()));
    }

    if let (Some(access_key_id), Some(secret_access_key)) = (
        config.access_key_id.clone(),
        config.secret_access_key.clone(),
    ) {
        loader = loader.credentials_provider(Credentials::new(
            access_key_id,
            secret_access_key,
            config.session_token.clone(),
            None,
            "dart_edge_s3_client",
        ));
    }

    let shared_config = loader.load().await;
    let mut builder = S3ConfigBuilder::from(&shared_config);
    if let Some(endpoint) = config.endpoint {
        builder = builder.endpoint_url(endpoint);
    }
    builder = builder.force_path_style(config.force_path_style);

    Ok(Client::from_conf(builder.build()))
}

async fn put_object_bytes(
    client: Client,
    request: PutObjectBytesRequest,
    bytes: Vec<u8>,
) -> Result<PutObjectResult, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client
        .put_object()
        .bucket(&request.bucket)
        .key(&request.key)
        .body(ByteStream::from(bytes));

    if let Some(content_type) = request.content_type {
        operation = operation.content_type(content_type);
    }
    if let Some(cache_control) = request.cache_control {
        operation = operation.cache_control(cache_control);
    }
    if let Some(content_disposition) = request.content_disposition {
        operation = operation.content_disposition(content_disposition);
    }
    if let Some(content_encoding) = request.content_encoding {
        operation = operation.content_encoding(content_encoding);
    }
    if let Some(content_language) = request.content_language {
        operation = operation.content_language(content_language);
    }
    if !request.metadata.is_empty() {
        operation = operation.set_metadata(Some(request.metadata));
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to put S3 object '{bucket}/{key}': {error}"))?;

    Ok(PutObjectResult {
        bucket,
        key,
        e_tag: response.e_tag().map(ToOwned::to_owned),
        version_id: response.version_id().map(ToOwned::to_owned),
    })
}

fn put_object_native_stream_inner(
    handle: i64,
    request: *const NativeS3PutObjectRequest,
    stream: NativeByteStream,
    content_length: i64,
) -> Result<NativeS3PutObjectResult, String> {
    let body = NativeUploadBody::new(stream, content_length)?;
    let client = client_for_handle(handle)
        .ok_or_else(|| "Unknown dart_edge_s3_client handle.".to_string())?;
    let request = unsafe { read_put_object_request(request)? };
    RUNTIME
        .block_on(put_object_stream(client, request, body, content_length))
        .map(native_put_object_result)
}

async fn put_object_stream(
    client: Client,
    request: PutObjectBytesRequest,
    body: NativeUploadBody,
    content_length: i64,
) -> Result<PutObjectResult, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();
    let mut operation = client
        .put_object()
        .bucket(&request.bucket)
        .key(&request.key)
        .content_length(content_length)
        .body(ByteStream::from_body_1_x(body));

    if let Some(content_type) = request.content_type {
        operation = operation.content_type(content_type);
    }
    if let Some(cache_control) = request.cache_control {
        operation = operation.cache_control(cache_control);
    }
    if let Some(content_disposition) = request.content_disposition {
        operation = operation.content_disposition(content_disposition);
    }
    if let Some(content_encoding) = request.content_encoding {
        operation = operation.content_encoding(content_encoding);
    }
    if let Some(content_language) = request.content_language {
        operation = operation.content_language(content_language);
    }
    if !request.metadata.is_empty() {
        operation = operation.set_metadata(Some(request.metadata));
    }

    let response = operation
        .send()
        .await
        .map_err(|error| {
            format!("Failed to stream S3 object '{bucket}/{key}': {error:?}")
        })?;

    Ok(PutObjectResult {
        bucket,
        key,
        e_tag: response.e_tag().map(ToOwned::to_owned),
        version_id: response.version_id().map(ToOwned::to_owned),
    })
}

async fn get_object_bytes(
    client: Client,
    request: ObjectRef,
) -> Result<(Vec<u8>, ObjectMetadata), String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client
        .get_object()
        .bucket(&request.bucket)
        .key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }
    if let Some(range) = request.range.as_ref() {
        operation = operation.range(range);
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to get S3 object '{bucket}/{key}': {error}"))?;

    let content_length = response.content_length().unwrap_or(0);
    let content_range = response.content_range().map(ToOwned::to_owned);
    let metadata = ObjectMetadata {
        bucket,
        key,
        version_id: response.version_id().map(ToOwned::to_owned),
        e_tag: response.e_tag().map(ToOwned::to_owned),
        content_type: response.content_type().map(ToOwned::to_owned),
        content_length,
        object_length: object_length(content_range.as_deref(), content_length),
        content_range,
        cache_control: response.cache_control().map(ToOwned::to_owned),
        content_disposition: response.content_disposition().map(ToOwned::to_owned),
        content_encoding: response.content_encoding().map(ToOwned::to_owned),
        content_language: response.content_language().map(ToOwned::to_owned),
        metadata: response.metadata().cloned().unwrap_or_default(),
    };

    let collected = response.body.collect().await.map_err(|error| {
        format!(
            "Failed to read S3 object body '{}/{}': {error}",
            metadata.bucket, metadata.key
        )
    })?;
    let bytes = collected.into_bytes().to_vec();

    Ok((bytes, metadata))
}

async fn start_get_object_stream(
    client: Client,
    request: ObjectRef,
) -> Result<(ByteStream, ObjectMetadata), String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();
    let mut operation = client
        .get_object()
        .bucket(&request.bucket)
        .key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }
    if let Some(range) = request.range.as_ref() {
        operation = operation.range(range);
    }
    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to get S3 object '{bucket}/{key}': {error}"))?;
    let content_length = response.content_length().unwrap_or(0);
    let content_range = response.content_range().map(ToOwned::to_owned);
    let metadata = ObjectMetadata {
        bucket,
        key,
        version_id: response.version_id().map(ToOwned::to_owned),
        e_tag: response.e_tag().map(ToOwned::to_owned),
        content_type: response.content_type().map(ToOwned::to_owned),
        content_length,
        object_length: object_length(content_range.as_deref(), content_length),
        content_range,
        cache_control: response.cache_control().map(ToOwned::to_owned),
        content_disposition: response.content_disposition().map(ToOwned::to_owned),
        content_encoding: response.content_encoding().map(ToOwned::to_owned),
        content_language: response.content_language().map(ToOwned::to_owned),
        metadata: response.metadata().cloned().unwrap_or_default(),
    };
    Ok((response.body, metadata))
}

async fn head_object(client: Client, request: ObjectRef) -> Result<ObjectMetadata, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client
        .head_object()
        .bucket(&request.bucket)
        .key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to head S3 object '{bucket}/{key}': {error}"))?;

    Ok(ObjectMetadata {
        bucket,
        key,
        version_id: response.version_id().map(ToOwned::to_owned),
        e_tag: response.e_tag().map(ToOwned::to_owned),
        content_type: response.content_type().map(ToOwned::to_owned),
        content_length: response.content_length().unwrap_or(0),
        object_length: response.content_length().unwrap_or(0),
        content_range: None,
        cache_control: response.cache_control().map(ToOwned::to_owned),
        content_disposition: response.content_disposition().map(ToOwned::to_owned),
        content_encoding: response.content_encoding().map(ToOwned::to_owned),
        content_language: response.content_language().map(ToOwned::to_owned),
        metadata: response.metadata().cloned().unwrap_or_default(),
    })
}

async fn delete_object(client: Client, request: ObjectRef) -> Result<DeleteObjectResult, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client
        .delete_object()
        .bucket(&request.bucket)
        .key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to delete S3 object '{bucket}/{key}': {error}"))?;

    Ok(DeleteObjectResult {
        bucket,
        key,
        delete_marker: response.delete_marker(),
        version_id: response.version_id().map(ToOwned::to_owned),
    })
}

fn client_for_handle(handle: i64) -> Option<Client> {
    CLIENTS.lock().unwrap().get(&handle).cloned()
}

fn validate_client_config(config: &S3ClientConfig) -> Result<(), String> {
    if config
        .region
        .as_ref()
        .is_some_and(|region| region.trim().is_empty())
    {
        return Err("S3 client region must not be empty.".to_string());
    }

    match (&config.access_key_id, &config.secret_access_key) {
        (Some(_), Some(_)) | (None, None) => {}
        _ => {
            return Err(
                "S3 client accessKeyId and secretAccessKey must be provided together.".to_string(),
            );
        }
    }

    if config.session_token.is_some() && config.access_key_id.is_none() {
        return Err("S3 client sessionToken requires accessKeyId and secretAccessKey.".to_string());
    }

    if let Some(endpoint) = config.endpoint.as_ref() {
        if endpoint.trim().is_empty() {
            return Err("S3 client endpoint must not be empty when provided.".to_string());
        }
        if endpoint.starts_with("http://") && !config.allow_http {
            return Err("HTTP S3 endpoints require allowHttp: true in S3ClientConfig.".to_string());
        }
    }

    Ok(())
}

fn validate_object_ref(request: &ObjectRef) -> Result<(), String> {
    if request.bucket.trim().is_empty() {
        return Err("S3 object bucket must not be empty.".to_string());
    }
    if request.key.trim().is_empty() {
        return Err("S3 object key must not be empty.".to_string());
    }
    Ok(())
}

fn object_length(content_range: Option<&str>, content_length: i64) -> i64 {
    content_range
        .and_then(|value| value.rsplit_once('/').map(|(_, total)| total))
        .and_then(|total| total.parse::<i64>().ok())
        .unwrap_or(content_length)
}

fn validate_put_request(request: &PutObjectBytesRequest) -> Result<(), String> {
    if request.bucket.trim().is_empty() {
        return Err("putObject bucket must not be empty.".to_string());
    }
    if request.key.trim().is_empty() {
        return Err("putObject key must not be empty.".to_string());
    }
    Ok(())
}

unsafe fn read_client_config(
    config: *const NativeS3ClientConfig,
) -> Result<S3ClientConfig, String> {
    if config.is_null() {
        return Err("Missing S3 client config.".to_string());
    }

    let config = unsafe { &*config };
    Ok(S3ClientConfig {
        region: unsafe { read_optional_c_string(config.region)? },
        endpoint: unsafe { read_optional_c_string(config.endpoint)? },
        access_key_id: unsafe { read_optional_c_string(config.access_key_id)? },
        secret_access_key: unsafe { read_optional_c_string(config.secret_access_key)? },
        session_token: unsafe { read_optional_c_string(config.session_token)? },
        force_path_style: config.force_path_style,
        allow_http: config.allow_http,
    })
}

unsafe fn read_object_ref(request: *const NativeS3ObjectRef) -> Result<ObjectRef, String> {
    if request.is_null() {
        return Err("Missing S3 object request.".to_string());
    }

    let request = unsafe { &*request };
    let object = ObjectRef {
        bucket: unsafe { read_required_c_string(request.bucket, "bucket")? },
        key: unsafe { read_required_c_string(request.key, "key")? },
        version_id: unsafe { read_optional_c_string(request.version_id)? },
        range: unsafe { read_optional_c_string(request.range)? },
    };
    validate_object_ref(&object)?;
    Ok(object)
}

unsafe fn read_put_object_request(
    request: *const NativeS3PutObjectRequest,
) -> Result<PutObjectBytesRequest, String> {
    if request.is_null() {
        return Err("Missing putObject request.".to_string());
    }

    let request = unsafe { &*request };
    let request = PutObjectBytesRequest {
        bucket: unsafe { read_required_c_string(request.bucket, "bucket")? },
        key: unsafe { read_required_c_string(request.key, "key")? },
        content_type: unsafe { read_optional_c_string(request.content_type)? },
        cache_control: unsafe { read_optional_c_string(request.cache_control)? },
        content_disposition: unsafe { read_optional_c_string(request.content_disposition)? },
        content_encoding: unsafe { read_optional_c_string(request.content_encoding)? },
        content_language: unsafe { read_optional_c_string(request.content_language)? },
        metadata: unsafe { read_metadata(request.metadata, request.metadata_len)? },
    };
    validate_put_request(&request)?;
    Ok(request)
}

unsafe fn read_metadata(
    entries: *const NativeS3StringPair,
    len: isize,
) -> Result<HashMap<String, String>, String> {
    if len < 0 {
        return Err("S3 metadata length must not be negative.".to_string());
    }
    if len == 0 {
        return Ok(HashMap::new());
    }
    if entries.is_null() {
        return Err("S3 metadata entries must not be null when length is positive.".to_string());
    }

    let entries = unsafe { std::slice::from_raw_parts(entries, len as usize) };
    let mut metadata = HashMap::with_capacity(entries.len());
    for entry in entries {
        let key = unsafe { read_required_c_string(entry.key, "metadata key")? };
        let value = unsafe { read_required_c_string(entry.value, "metadata value")? };
        metadata.insert(key, value);
    }
    Ok(metadata)
}

unsafe fn read_optional_c_string(value: *const c_char) -> Result<Option<String>, String> {
    if value.is_null() {
        return Ok(None);
    }

    unsafe { read_c_string(value) }.map(Some)
}

unsafe fn read_required_c_string(value: *const c_char, name: &str) -> Result<String, String> {
    if value.is_null() {
        return Err(format!("Missing S3 {name}."));
    }

    unsafe { read_c_string(value) }
}

unsafe fn read_c_string(value: *const c_char) -> Result<String, String> {
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(ToOwned::to_owned)
        .map_err(|error| format!("Invalid UTF-8 in S3 string: {error}"))
}

unsafe fn read_input_bytes(ptr: *const u8, len: isize) -> Option<Vec<u8>> {
    if len < 0 {
        return None;
    }
    if len == 0 {
        return Some(Vec::new());
    }
    if ptr.is_null() {
        return None;
    }

    Some(unsafe { std::slice::from_raw_parts(ptr, len as usize) }.to_vec())
}

unsafe fn read_native_stream_error(read: *mut NativeByteStreamRead) -> String {
    let error = unsafe { (*read).error };
    if error.len <= 0 || error.ptr.is_null() {
        return "Native S3 upload stream read failed.".to_string();
    }
    let bytes = unsafe { std::slice::from_raw_parts(error.ptr, error.len as usize) };
    String::from_utf8_lossy(bytes).into_owned()
}

fn create_result_error(error: impl Into<String>) -> NativeS3CreateResult {
    NativeS3CreateResult {
        handle: 0,
        error: c_string_ptr(error),
    }
}

fn put_object_result_error(error: impl Into<String>) -> NativeS3PutObjectResult {
    NativeS3PutObjectResult {
        bucket: std::ptr::null_mut(),
        key: std::ptr::null_mut(),
        e_tag: std::ptr::null_mut(),
        version_id: std::ptr::null_mut(),
        error: c_string_ptr(error),
    }
}

fn delete_object_result_error(error: impl Into<String>) -> NativeS3DeleteObjectResult {
    NativeS3DeleteObjectResult {
        bucket: std::ptr::null_mut(),
        key: std::ptr::null_mut(),
        has_delete_marker: false,
        delete_marker: false,
        version_id: std::ptr::null_mut(),
        error: c_string_ptr(error),
    }
}

fn object_metadata_error(error: impl Into<String>) -> NativeS3ObjectMetadata {
    NativeS3ObjectMetadata {
        error: c_string_ptr(error),
        ..empty_object_metadata()
    }
}

fn bytes_result_error(error: impl Into<String>) -> NativeS3BytesResult {
    NativeS3BytesResult {
        bytes: NativeOwnedBytes {
            ptr: std::ptr::null_mut(),
            len: 0,
        },
        metadata: empty_object_metadata(),
        error: c_string_ptr(error),
    }
}

fn stream_start_result_error(error: impl Into<String>) -> NativeS3StreamStartResult {
    NativeS3StreamStartResult {
        download_handle: 0,
        metadata: empty_object_metadata(),
        error: c_string_ptr(error),
    }
}

fn native_stream_start_result_error(error: impl Into<String>) -> NativeS3NativeStreamStartResult {
    NativeS3NativeStreamStartResult {
        stream: empty_native_byte_stream(),
        metadata: empty_object_metadata(),
        error: c_string_ptr(error),
    }
}

fn empty_native_byte_stream() -> NativeByteStream {
    NativeByteStream {
        abi_version: NATIVE_BYTE_STREAM_ABI_VERSION,
        struct_size: size_of::<NativeByteStream>(),
        context: std::ptr::null_mut(),
        next: None,
        cancel: None,
        free_read: None,
        release: None,
    }
}

fn stream_chunk_result_error(error: impl Into<String>) -> NativeS3StreamChunkResult {
    NativeS3StreamChunkResult {
        bytes: NativeOwnedBytes {
            ptr: std::ptr::null_mut(),
            len: 0,
        },
        done: true,
        error: c_string_ptr(error),
    }
}

fn native_put_object_result(result: PutObjectResult) -> NativeS3PutObjectResult {
    NativeS3PutObjectResult {
        bucket: c_string_ptr(result.bucket),
        key: c_string_ptr(result.key),
        e_tag: optional_c_string_ptr(result.e_tag),
        version_id: optional_c_string_ptr(result.version_id),
        error: std::ptr::null_mut(),
    }
}

fn native_delete_object_result(result: DeleteObjectResult) -> NativeS3DeleteObjectResult {
    let (has_delete_marker, delete_marker) = result
        .delete_marker
        .map(|value| (true, value))
        .unwrap_or((false, false));

    NativeS3DeleteObjectResult {
        bucket: c_string_ptr(result.bucket),
        key: c_string_ptr(result.key),
        has_delete_marker,
        delete_marker,
        version_id: optional_c_string_ptr(result.version_id),
        error: std::ptr::null_mut(),
    }
}

fn native_object_metadata(metadata: ObjectMetadata) -> NativeS3ObjectMetadata {
    let (metadata_ptr, metadata_len) = native_string_pairs(metadata.metadata);
    NativeS3ObjectMetadata {
        bucket: c_string_ptr(metadata.bucket),
        key: c_string_ptr(metadata.key),
        version_id: optional_c_string_ptr(metadata.version_id),
        e_tag: optional_c_string_ptr(metadata.e_tag),
        content_type: optional_c_string_ptr(metadata.content_type),
        content_length: metadata.content_length,
        object_length: metadata.object_length,
        content_range: optional_c_string_ptr(metadata.content_range),
        cache_control: optional_c_string_ptr(metadata.cache_control),
        content_disposition: optional_c_string_ptr(metadata.content_disposition),
        content_encoding: optional_c_string_ptr(metadata.content_encoding),
        content_language: optional_c_string_ptr(metadata.content_language),
        metadata: metadata_ptr,
        metadata_len,
        error: std::ptr::null_mut(),
    }
}

fn empty_object_metadata() -> NativeS3ObjectMetadata {
    NativeS3ObjectMetadata {
        bucket: std::ptr::null_mut(),
        key: std::ptr::null_mut(),
        version_id: std::ptr::null_mut(),
        e_tag: std::ptr::null_mut(),
        content_type: std::ptr::null_mut(),
        content_length: 0,
        object_length: 0,
        content_range: std::ptr::null_mut(),
        cache_control: std::ptr::null_mut(),
        content_disposition: std::ptr::null_mut(),
        content_encoding: std::ptr::null_mut(),
        content_language: std::ptr::null_mut(),
        metadata: std::ptr::null_mut(),
        metadata_len: 0,
        error: std::ptr::null_mut(),
    }
}

fn native_string_pairs(metadata: HashMap<String, String>) -> (*mut NativeS3StringPair, isize) {
    if metadata.is_empty() {
        return (std::ptr::null_mut(), 0);
    }

    let mut entries = metadata
        .into_iter()
        .map(|(key, value)| NativeS3StringPair {
            key: c_string_ptr(key),
            value: c_string_ptr(value),
        })
        .collect::<Vec<_>>();
    let ptr = entries.as_mut_ptr();
    let len = entries.len() as isize;
    std::mem::forget(entries);
    (ptr, len)
}

fn c_string_ptr(value: impl Into<String>) -> *mut c_char {
    let value = value.into().replace('\0', "\\0");
    CString::new(value)
        .expect("sanitized S3 string should not contain NUL")
        .into_raw()
}

fn optional_c_string_ptr(value: Option<String>) -> *mut c_char {
    value.map(c_string_ptr).unwrap_or(std::ptr::null_mut())
}

unsafe fn free_object_metadata_fields(value: &mut NativeS3ObjectMetadata) {
    unsafe {
        free_c_string(value.bucket);
        free_c_string(value.key);
        free_c_string(value.version_id);
        free_c_string(value.e_tag);
        free_c_string(value.content_type);
        free_c_string(value.content_range);
        free_c_string(value.cache_control);
        free_c_string(value.content_disposition);
        free_c_string(value.content_encoding);
        free_c_string(value.content_language);
        free_string_pairs(value.metadata, value.metadata_len);
        free_c_string(value.error);
    }
}

unsafe fn free_string_pairs(entries: *mut NativeS3StringPair, len: isize) {
    if entries.is_null() || len <= 0 {
        return;
    }

    let entries = unsafe { Vec::from_raw_parts(entries, len as usize, len as usize) };
    for entry in entries {
        unsafe {
            free_c_string(entry.key);
            free_c_string(entry.value);
        }
    }
}

unsafe fn free_c_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

#[cfg(test)]
mod tests {
    use std::collections::VecDeque;
    use std::ffi::c_void;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicBool, Ordering};

    use super::*;

    struct TrackingBytes {
        bytes: Vec<u8>,
        dropped: Arc<AtomicBool>,
    }

    impl AsRef<[u8]> for TrackingBytes {
        fn as_ref(&self) -> &[u8] {
            &self.bytes
        }
    }

    impl Drop for TrackingBytes {
        fn drop(&mut self) {
            self.dropped.store(true, Ordering::SeqCst);
        }
    }

    struct FakeUploadContext {
        chunks: VecDeque<Vec<u8>>,
        canceled: Arc<AtomicBool>,
        released: Arc<AtomicBool>,
    }

    #[repr(C)]
    struct FakeUploadRead {
        read: NativeByteStreamRead,
        _bytes: Vec<u8>,
    }

    unsafe extern "C" fn fake_upload_next(context: *mut c_void) -> *mut NativeByteStreamRead {
        let context = unsafe { &mut *context.cast::<FakeUploadContext>() };
        let Some(mut bytes) = context.chunks.pop_front() else {
            return Box::into_raw(Box::new(FakeUploadRead {
                read: NativeByteStreamRead {
                    status: NATIVE_BYTE_STREAM_READ_DONE,
                    bytes: NativeOwnedBytes::empty(),
                    error: NativeBytes::empty(),
                },
                _bytes: Vec::new(),
            }))
            .cast();
        };
        let native_bytes = NativeOwnedBytes {
            ptr: bytes.as_mut_ptr(),
            len: bytes.len() as isize,
        };
        Box::into_raw(Box::new(FakeUploadRead {
            read: NativeByteStreamRead {
                status: NATIVE_BYTE_STREAM_READ_CHUNK,
                bytes: native_bytes,
                error: NativeBytes::empty(),
            },
            _bytes: bytes,
        }))
        .cast()
    }

    unsafe extern "C" fn fake_upload_cancel(context: *mut c_void) {
        unsafe { &*context.cast::<FakeUploadContext>() }
            .canceled
            .store(true, Ordering::SeqCst);
    }

    unsafe extern "C" fn fake_upload_free_read(read: *mut NativeByteStreamRead) {
        unsafe { drop(Box::from_raw(read.cast::<FakeUploadRead>())) };
    }

    unsafe extern "C" fn fake_upload_release(context: *mut c_void) {
        let context = unsafe { Box::from_raw(context.cast::<FakeUploadContext>()) };
        context.released.store(true, Ordering::SeqCst);
    }

    fn fake_upload_stream(
        chunks: impl IntoIterator<Item = Vec<u8>>,
    ) -> (NativeByteStream, Arc<AtomicBool>, Arc<AtomicBool>) {
        let canceled = Arc::new(AtomicBool::new(false));
        let released = Arc::new(AtomicBool::new(false));
        let context = Box::new(FakeUploadContext {
            chunks: chunks.into_iter().collect(),
            canceled: Arc::clone(&canceled),
            released: Arc::clone(&released),
        });
        (
            NativeByteStream {
                abi_version: NATIVE_BYTE_STREAM_ABI_VERSION,
                struct_size: size_of::<NativeByteStream>(),
                context: Box::into_raw(context).cast(),
                next: Some(fake_upload_next),
                cancel: Some(fake_upload_cancel),
                free_read: Some(fake_upload_free_read),
                release: Some(fake_upload_release),
            },
            canceled,
            released,
        )
    }

    #[test]
    fn native_stream_read_borrows_and_releases_the_original_bytes() {
        let dropped = Arc::new(AtomicBool::new(false));
        let chunk = Bytes::from_owner(TrackingBytes {
            bytes: b"native zero copy".to_vec(),
            dropped: Arc::clone(&dropped),
        });
        let original_ptr = chunk.as_ptr();
        let read = S3NativeByteStreamRead::chunk(chunk).into_raw();

        unsafe {
            assert_eq!((*read).status, NATIVE_BYTE_STREAM_READ_CHUNK);
            assert_eq!((*read).bytes.ptr.cast_const(), original_ptr);
            assert_eq!((*read).bytes.len, 16);
            assert_eq!(
                std::slice::from_raw_parts((*read).bytes.ptr, (*read).bytes.len as usize),
                b"native zero copy"
            );
            assert!(!dropped.load(Ordering::SeqCst));
            s3_native_stream_free_read(read);
        }

        assert!(dropped.load(Ordering::SeqCst));
    }

    #[test]
    fn native_stream_error_stays_valid_until_free_read() {
        let read = S3NativeByteStreamRead::error("stream failed").into_raw();

        unsafe {
            assert_eq!((*read).status, NATIVE_BYTE_STREAM_READ_ERROR);
            assert_eq!(
                std::slice::from_raw_parts((*read).error.ptr, (*read).error.len as usize),
                b"stream failed"
            );
            s3_native_stream_free_read(read);
        }
    }

    #[test]
    fn native_upload_body_adopts_chunks_and_releases_the_producer() {
        let (stream, canceled, released) =
            fake_upload_stream([b"native ".to_vec(), b"upload".to_vec()]);
        let body = NativeUploadBody::new(stream, 13).expect("valid native upload body");
        let bytes = RUNTIME
            .block_on(ByteStream::from_body_1_x(body).collect())
            .expect("native body should collect")
            .into_bytes();

        assert_eq!(bytes.as_ref(), b"native upload");
        assert!(!canceled.load(Ordering::SeqCst));
        assert!(released.load(Ordering::SeqCst));
    }

    #[test]
    fn native_upload_body_rejects_declared_length_mismatches() {
        let (stream, canceled, released) = fake_upload_stream([b"too long".to_vec()]);
        let body = NativeUploadBody::new(stream, 3).expect("valid native upload body");
        let error = RUNTIME
            .block_on(ByteStream::from_body_1_x(body).collect())
            .expect_err("oversized body must fail");

        assert!(error.to_string().contains("declared content length"));
        assert!(canceled.load(Ordering::SeqCst));
        assert!(released.load(Ordering::SeqCst));
    }

    #[test]
    fn native_upload_body_keeps_end_of_stream_idempotent() {
        let (stream, canceled, released) = fake_upload_stream([b"done".to_vec()]);
        let mut body = NativeUploadBody::new(stream, 4).expect("valid native upload body");

        assert!(body.next_frame().expect("data frame").is_some());
        assert!(body.next_frame().expect("first end-of-stream").is_none());
        assert!(body.next_frame().expect("repeated end-of-stream").is_none());
        drop(body);

        assert!(!canceled.load(Ordering::SeqCst));
        assert!(released.load(Ordering::SeqCst));
    }
}
