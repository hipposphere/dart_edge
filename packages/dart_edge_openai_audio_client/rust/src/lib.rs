use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::io::{self, Read};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};
use std::time::Duration;

use dart_edge_core::{
    NATIVE_BYTE_STREAM_READ_CANCELED, NATIVE_BYTE_STREAM_READ_CHUNK, NATIVE_BYTE_STREAM_READ_DONE,
    NATIVE_BYTE_STREAM_READ_ERROR, NativeByteStream, NativeByteStreamFreeRead,
    NativeByteStreamRead,
};
use once_cell::sync::Lazy;
use reqwest::Url;
use reqwest::blocking::Client;
use reqwest::blocking::multipart::{Form, Part};
use reqwest::header::{AUTHORIZATION, HeaderMap, HeaderName, HeaderValue, USER_AGENT};

const NATIVE_ABI_VERSION: i32 = 1;
const DEFAULT_USER_AGENT: &str = "dart_edge_openai_audio_client/0.1.0";

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static CLIENTS: Lazy<Mutex<HashMap<i64, ClientState>>> = Lazy::new(|| Mutex::new(HashMap::new()));

#[repr(C)]
pub struct NativeOpenAiAudioStringPair {
    key: *const c_char,
    value: *const c_char,
}

#[repr(C)]
pub struct NativeOpenAiAudioClientConfig {
    base_url: *const c_char,
    api_key: *const c_char,
    headers: *const NativeOpenAiAudioStringPair,
    headers_len: isize,
    connect_timeout_ms: i64,
    request_timeout_ms: i64,
    max_response_bytes: i64,
    allow_http: bool,
}

#[repr(C)]
pub struct NativeOpenAiAudioTranscriptionRequest {
    filename: *const c_char,
    content_type: *const c_char,
    fields: *const NativeOpenAiAudioStringPair,
    fields_len: isize,
}

#[repr(C)]
pub struct NativeOpenAiAudioCreateResult {
    handle: i64,
    error: *mut c_char,
}

#[repr(C)]
pub struct NativeOpenAiAudioTranscriptionResult {
    status_code: i32,
    body: *mut c_char,
    content_type: *mut c_char,
    request_id: *mut c_char,
    error: *mut c_char,
}

#[derive(Clone)]
struct ClientState {
    client: Client,
    endpoint: Url,
    max_response_bytes: usize,
}

struct TranscriptionRequest {
    filename: String,
    content_type: String,
    fields: Vec<(String, String)>,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_openai_audio_client_native_abi_version() -> i32 {
    NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_openai_audio_client_create(
    config: *const NativeOpenAiAudioClientConfig,
) -> *mut NativeOpenAiAudioCreateResult {
    let result = create_client(config).unwrap_or_else(create_result_error);
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_openai_audio_client_dispose(handle: i64) {
    if let Ok(mut clients) = CLIENTS.lock() {
        clients.remove(&handle);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_openai_audio_client_transcribe_bytes(
    handle: i64,
    request: *const NativeOpenAiAudioTranscriptionRequest,
    bytes_ptr: *const u8,
    bytes_len: isize,
) -> *mut NativeOpenAiAudioTranscriptionResult {
    let result = transcribe_bytes(handle, request, bytes_ptr, bytes_len)
        .unwrap_or_else(transcription_result_error);
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_openai_audio_client_transcribe_native_stream(
    handle: i64,
    request: *const NativeOpenAiAudioTranscriptionRequest,
    stream: *const NativeByteStream,
    content_length: i64,
) -> *mut NativeOpenAiAudioTranscriptionResult {
    // Adoption happens before request validation. The native side therefore
    // releases the producer context for every result once a descriptor exists.
    let result = if stream.is_null() {
        Err("Missing native audio stream descriptor.".to_string())
    } else {
        let descriptor = unsafe { *stream };
        let reader = NativeStreamReader::new(descriptor);
        transcribe_stream(handle, request, reader, content_length)
    }
    .unwrap_or_else(transcription_result_error);
    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_openai_audio_client_free_create_result(
    value: *mut NativeOpenAiAudioCreateResult,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    unsafe { free_c_string(value.error) };
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn dart_edge_openai_audio_client_free_transcription_result(
    value: *mut NativeOpenAiAudioTranscriptionResult,
) {
    if value.is_null() {
        return;
    }
    let value = unsafe { Box::from_raw(value) };
    unsafe {
        free_c_string(value.body);
        free_c_string(value.content_type);
        free_c_string(value.request_id);
        free_c_string(value.error);
    }
}

fn create_client(
    config: *const NativeOpenAiAudioClientConfig,
) -> Result<NativeOpenAiAudioCreateResult, String> {
    if config.is_null() {
        return Err("Missing OpenAI audio client config.".to_string());
    }
    let config = unsafe { &*config };
    let base_url = unsafe { read_required_string(config.base_url, "base URL")? };
    let endpoint = transcription_endpoint(&base_url, config.allow_http)?;
    let connect_timeout = positive_duration(config.connect_timeout_ms, "connect timeout")?;
    let request_timeout = positive_duration(config.request_timeout_ms, "request timeout")?;
    let max_response_bytes = usize::try_from(config.max_response_bytes)
        .ok()
        .filter(|value| *value > 0)
        .ok_or_else(|| "Maximum response bytes must be positive.".to_string())?;

    let mut headers = HeaderMap::new();
    for (name, value) in unsafe { read_pairs(config.headers, config.headers_len, "header")? } {
        let name = HeaderName::from_bytes(name.as_bytes())
            .map_err(|error| format!("Invalid HTTP header name: {error}"))?;
        let value = HeaderValue::from_str(&value)
            .map_err(|error| format!("Invalid HTTP header value: {error}"))?;
        headers.append(name, value);
    }
    if let Some(api_key) = unsafe { read_optional_string(config.api_key)? } {
        if api_key.trim().is_empty() {
            return Err("API key must not be empty when provided.".to_string());
        }
        let value = HeaderValue::from_str(&format!("Bearer {api_key}"))
            .map_err(|error| format!("Invalid API key header: {error}"))?;
        headers.insert(AUTHORIZATION, value);
    }
    headers
        .entry(USER_AGENT)
        .or_insert(HeaderValue::from_static(DEFAULT_USER_AGENT));

    let client = Client::builder()
        .connect_timeout(connect_timeout)
        .timeout(request_timeout)
        .default_headers(headers)
        .build()
        .map_err(|error| format!("Failed to create native HTTP client: {error}"))?;

    let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
    CLIENTS
        .lock()
        .map_err(|_| "OpenAI audio client registry is unavailable.".to_string())?
        .insert(
            handle,
            ClientState {
                client,
                endpoint,
                max_response_bytes,
            },
        );
    Ok(NativeOpenAiAudioCreateResult {
        handle,
        error: std::ptr::null_mut(),
    })
}

fn transcribe_bytes(
    handle: i64,
    request: *const NativeOpenAiAudioTranscriptionRequest,
    bytes_ptr: *const u8,
    bytes_len: isize,
) -> Result<NativeOpenAiAudioTranscriptionResult, String> {
    let client = client_state(handle)?;
    let request = unsafe { read_request(request)? };
    let bytes = unsafe { read_input_bytes(bytes_ptr, bytes_len)? };
    if bytes.is_empty() {
        return Err("Audio bytes must not be empty.".to_string());
    }
    let part = Part::bytes(bytes)
        .file_name(request.filename.clone())
        .mime_str(&request.content_type)
        .map_err(|error| format!("Invalid audio content type: {error}"))?;
    send_transcription(&client, request, part)
}

fn transcribe_stream(
    handle: i64,
    request: *const NativeOpenAiAudioTranscriptionRequest,
    reader: Result<NativeStreamReader, String>,
    content_length: i64,
) -> Result<NativeOpenAiAudioTranscriptionResult, String> {
    // Resolve the reader first so its descriptor is owned even if the client
    // handle or request is invalid.
    let reader = reader?;
    let content_length = u64::try_from(content_length)
        .ok()
        .filter(|value| *value > 0)
        .ok_or_else(|| "Native audio content length must be positive.".to_string())?;
    let client = client_state(handle)?;
    let request = unsafe { read_request(request)? };
    let part = Part::reader_with_length(reader, content_length)
        .file_name(request.filename.clone())
        .mime_str(&request.content_type)
        .map_err(|error| format!("Invalid audio content type: {error}"))?;
    send_transcription(&client, request, part)
}

fn send_transcription(
    state: &ClientState,
    request: TranscriptionRequest,
    file: Part,
) -> Result<NativeOpenAiAudioTranscriptionResult, String> {
    let mut form = Form::new().part("file", file);
    for (name, value) in request.fields {
        form = form.text(name, value);
    }
    let response = state
        .client
        .post(state.endpoint.clone())
        .multipart(form)
        .send()
        .map_err(|error| format!("OpenAI-compatible transcription request failed: {error}"))?;
    let status_code = i32::from(response.status().as_u16());
    let content_type = response
        .headers()
        .get(reqwest::header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .map(ToOwned::to_owned);
    let request_id = response
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map(ToOwned::to_owned);
    let body = read_limited_response(response, state.max_response_bytes)?;
    let body = String::from_utf8(body)
        .map_err(|error| format!("Provider response was not UTF-8: {error}"))?;

    Ok(NativeOpenAiAudioTranscriptionResult {
        status_code,
        body: c_string_ptr(body),
        content_type: optional_c_string_ptr(content_type),
        request_id: optional_c_string_ptr(request_id),
        error: std::ptr::null_mut(),
    })
}

fn read_limited_response(
    response: reqwest::blocking::Response,
    max_bytes: usize,
) -> Result<Vec<u8>, String> {
    let limit = u64::try_from(max_bytes)
        .map_err(|_| "Maximum response size is unsupported on this platform.".to_string())?;
    let mut body = Vec::with_capacity(max_bytes.min(64 * 1024));
    response
        .take(limit.saturating_add(1))
        .read_to_end(&mut body)
        .map_err(|error| format!("Failed to read provider response: {error}"))?;
    if body.len() > max_bytes {
        return Err(format!(
            "Provider response exceeded the configured {max_bytes}-byte limit."
        ));
    }
    Ok(body)
}

fn client_state(handle: i64) -> Result<ClientState, String> {
    CLIENTS
        .lock()
        .map_err(|_| "OpenAI audio client registry is unavailable.".to_string())?
        .get(&handle)
        .cloned()
        .ok_or_else(|| "OpenAI audio client handle is invalid or disposed.".to_string())
}

fn transcription_endpoint(base_url: &str, allow_http: bool) -> Result<Url, String> {
    let normalized = base_url.trim().trim_end_matches('/');
    let path = if normalized.ends_with("/v1") {
        format!("{normalized}/audio/transcriptions")
    } else {
        format!("{normalized}/v1/audio/transcriptions")
    };
    let url = Url::parse(&path).map_err(|error| format!("Invalid provider base URL: {error}"))?;
    match url.scheme() {
        "https" => {}
        "http" if allow_http => {}
        "http" => return Err("HTTP provider URLs require allowHttp.".to_string()),
        scheme => return Err(format!("Unsupported provider URL scheme: {scheme}")),
    }
    if !url.username().is_empty() || url.password().is_some() {
        return Err("Provider URLs must not contain credentials.".to_string());
    }
    if url.query().is_some() || url.fragment().is_some() {
        return Err("Provider URLs must not contain a query or fragment.".to_string());
    }
    Ok(url)
}

fn positive_duration(value_ms: i64, name: &str) -> Result<Duration, String> {
    u64::try_from(value_ms)
        .ok()
        .filter(|value| *value > 0)
        .map(Duration::from_millis)
        .ok_or_else(|| format!("OpenAI audio client {name} must be positive."))
}

unsafe fn read_request(
    request: *const NativeOpenAiAudioTranscriptionRequest,
) -> Result<TranscriptionRequest, String> {
    if request.is_null() {
        return Err("Missing transcription request.".to_string());
    }
    let request = unsafe { &*request };
    let filename = unsafe { read_required_string(request.filename, "filename")? };
    let content_type = unsafe { read_required_string(request.content_type, "content type")? };
    let fields = unsafe { read_pairs(request.fields, request.fields_len, "multipart field")? };
    if filename.trim().is_empty() || content_type.trim().is_empty() {
        return Err("Filename and content type must not be empty.".to_string());
    }
    if !fields
        .iter()
        .any(|(name, value)| name == "model" && !value.trim().is_empty())
    {
        return Err("Transcription request requires a model field.".to_string());
    }
    Ok(TranscriptionRequest {
        filename,
        content_type,
        fields,
    })
}

unsafe fn read_pairs(
    pairs: *const NativeOpenAiAudioStringPair,
    len: isize,
    description: &str,
) -> Result<Vec<(String, String)>, String> {
    if len < 0 {
        return Err(format!("Invalid {description} count."));
    }
    if len == 0 {
        return Ok(Vec::new());
    }
    if pairs.is_null() {
        return Err(format!("Missing {description} entries."));
    }
    let pairs = unsafe { std::slice::from_raw_parts(pairs, len as usize) };
    pairs
        .iter()
        .map(|pair| {
            let key = unsafe { read_required_string(pair.key, description)? };
            let value = unsafe { read_required_string(pair.value, description)? };
            if key.trim().is_empty() {
                return Err(format!("{description} name must not be empty."));
            }
            Ok((key, value))
        })
        .collect()
}

unsafe fn read_input_bytes(ptr: *const u8, len: isize) -> Result<Vec<u8>, String> {
    if len <= 0 || ptr.is_null() {
        return Err("Audio bytes must not be empty.".to_string());
    }
    Ok(unsafe { std::slice::from_raw_parts(ptr, len as usize) }.to_vec())
}

unsafe fn read_required_string(value: *const c_char, name: &str) -> Result<String, String> {
    unsafe { read_optional_string(value)? }.ok_or_else(|| format!("Missing {name}."))
}

unsafe fn read_optional_string(value: *const c_char) -> Result<Option<String>, String> {
    if value.is_null() {
        return Ok(None);
    }
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(|value| Some(value.to_owned()))
        .map_err(|error| format!("Invalid UTF-8 across native boundary: {error}"))
}

struct NativeStreamReader {
    stream: NativeByteStream,
    current: Option<NativeReadChunk>,
    completed: bool,
}

impl NativeStreamReader {
    fn new(stream: NativeByteStream) -> Result<Self, String> {
        if !stream.is_valid() {
            let owned = Self {
                stream,
                current: None,
                completed: false,
            };
            drop(owned);
            return Err("Native audio stream descriptor is invalid.".to_string());
        }
        Ok(Self {
            stream,
            current: None,
            completed: false,
        })
    }

    fn next_read(&mut self) -> io::Result<Option<NativeReadChunk>> {
        let next = self
            .stream
            .next
            .ok_or_else(|| io::Error::other("Native audio stream has no next callback."))?;
        let free_read = self.stream.free_read.ok_or_else(|| {
            io::Error::other("Native audio stream has no result release callback.")
        })?;
        let read = unsafe { next(self.stream.context) };
        if read.is_null() {
            return Err(io::Error::other(
                "Native audio stream returned a null read result.",
            ));
        }
        let status = unsafe { (*read).status };
        match status {
            NATIVE_BYTE_STREAM_READ_CHUNK => {
                let bytes = unsafe { (*read).bytes };
                if bytes.len < 0 || (bytes.len > 0 && bytes.ptr.is_null()) {
                    unsafe { free_read(read) };
                    return Err(io::Error::other(
                        "Native audio stream returned invalid chunk bytes.",
                    ));
                }
                Ok(Some(NativeReadChunk {
                    read,
                    free_read,
                    offset: 0,
                }))
            }
            NATIVE_BYTE_STREAM_READ_DONE | NATIVE_BYTE_STREAM_READ_CANCELED => {
                unsafe { free_read(read) };
                self.completed = true;
                Ok(None)
            }
            NATIVE_BYTE_STREAM_READ_ERROR => {
                let error = unsafe { read_optional_native_error(read) };
                unsafe { free_read(read) };
                Err(io::Error::other(error))
            }
            other => {
                unsafe { free_read(read) };
                Err(io::Error::other(format!(
                    "Native audio stream returned unknown status {other}."
                )))
            }
        }
    }
}

impl Read for NativeStreamReader {
    fn read(&mut self, output: &mut [u8]) -> io::Result<usize> {
        if output.is_empty() {
            return Ok(0);
        }
        loop {
            if let Some(chunk) = self.current.as_mut() {
                let copied = chunk.copy_into(output);
                if chunk.is_consumed() {
                    self.current = None;
                }
                if copied > 0 {
                    return Ok(copied);
                }
            }
            self.current = self.next_read()?;
            if self.current.is_none() {
                return Ok(0);
            }
        }
    }
}

impl Drop for NativeStreamReader {
    fn drop(&mut self) {
        self.current = None;
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

unsafe impl Send for NativeStreamReader {}

struct NativeReadChunk {
    read: *mut NativeByteStreamRead,
    free_read: NativeByteStreamFreeRead,
    offset: usize,
}

impl NativeReadChunk {
    fn copy_into(&mut self, output: &mut [u8]) -> usize {
        let bytes = unsafe { (*self.read).bytes };
        let len = usize::try_from(bytes.len).unwrap_or(0);
        let remaining = len.saturating_sub(self.offset);
        let copied = remaining.min(output.len());
        if copied > 0 {
            let input = unsafe { std::slice::from_raw_parts(bytes.ptr.add(self.offset), copied) };
            output[..copied].copy_from_slice(input);
            self.offset += copied;
        }
        copied
    }

    fn is_consumed(&self) -> bool {
        let len = unsafe { (*self.read).bytes.len };
        self.offset >= usize::try_from(len).unwrap_or(0)
    }
}

impl Drop for NativeReadChunk {
    fn drop(&mut self) {
        unsafe { (self.free_read)(self.read) };
    }
}

unsafe fn read_optional_native_error(read: *mut NativeByteStreamRead) -> String {
    let error = unsafe { (*read).error };
    if error.len <= 0 || error.ptr.is_null() {
        return "Native audio stream read failed.".to_string();
    }
    let bytes = unsafe { std::slice::from_raw_parts(error.ptr, error.len as usize) };
    String::from_utf8_lossy(bytes).into_owned()
}

fn create_result_error(error: impl Into<String>) -> NativeOpenAiAudioCreateResult {
    NativeOpenAiAudioCreateResult {
        handle: 0,
        error: c_string_ptr(error.into()),
    }
}

fn transcription_result_error(error: impl Into<String>) -> NativeOpenAiAudioTranscriptionResult {
    NativeOpenAiAudioTranscriptionResult {
        status_code: 0,
        body: std::ptr::null_mut(),
        content_type: std::ptr::null_mut(),
        request_id: std::ptr::null_mut(),
        error: c_string_ptr(error.into()),
    }
}

fn c_string_ptr(value: String) -> *mut c_char {
    CString::new(value.replace('\0', "\\0"))
        .expect("sanitized CString")
        .into_raw()
}

fn optional_c_string_ptr(value: Option<String>) -> *mut c_char {
    value.map(c_string_ptr).unwrap_or(std::ptr::null_mut())
}

unsafe fn free_c_string(value: *mut c_char) {
    if !value.is_null() {
        let _ = unsafe { CString::from_raw(value) };
    }
}

#[cfg(test)]
mod tests {
    use std::collections::VecDeque;
    use std::ffi::c_void;
    use std::sync::Arc;
    use std::sync::atomic::AtomicBool;

    use dart_edge_core::{NATIVE_BYTE_STREAM_ABI_VERSION, NativeBytes, NativeOwnedBytes};

    use super::*;

    struct FakeStreamContext {
        chunks: VecDeque<Vec<u8>>,
        canceled: Arc<AtomicBool>,
        released: Arc<AtomicBool>,
    }

    #[repr(C)]
    struct FakeRead {
        read: NativeByteStreamRead,
        bytes: Vec<u8>,
    }

    impl FakeRead {
        fn chunk(bytes: Vec<u8>) -> *mut NativeByteStreamRead {
            let mut value = Box::new(Self {
                read: NativeByteStreamRead {
                    status: NATIVE_BYTE_STREAM_READ_CHUNK,
                    bytes: NativeOwnedBytes::empty(),
                    error: NativeBytes::empty(),
                },
                bytes,
            });
            value.read.bytes = NativeOwnedBytes {
                ptr: value.bytes.as_mut_ptr(),
                len: value.bytes.len() as isize,
            };
            Box::into_raw(value).cast()
        }

        fn done() -> *mut NativeByteStreamRead {
            Box::into_raw(Box::new(Self {
                read: NativeByteStreamRead {
                    status: NATIVE_BYTE_STREAM_READ_DONE,
                    bytes: NativeOwnedBytes::empty(),
                    error: NativeBytes::empty(),
                },
                bytes: Vec::new(),
            }))
            .cast()
        }
    }

    unsafe extern "C" fn fake_next(context: *mut c_void) -> *mut NativeByteStreamRead {
        let context = unsafe { &mut *context.cast::<FakeStreamContext>() };
        context
            .chunks
            .pop_front()
            .map(FakeRead::chunk)
            .unwrap_or_else(FakeRead::done)
    }

    unsafe extern "C" fn fake_cancel(context: *mut c_void) {
        let context = unsafe { &*context.cast::<FakeStreamContext>() };
        context.canceled.store(true, Ordering::Relaxed);
    }

    unsafe extern "C" fn fake_free_read(read: *mut NativeByteStreamRead) {
        if !read.is_null() {
            let _ = unsafe { Box::from_raw(read.cast::<FakeRead>()) };
        }
    }

    unsafe extern "C" fn fake_release(context: *mut c_void) {
        if !context.is_null() {
            let context = unsafe { Box::from_raw(context.cast::<FakeStreamContext>()) };
            context.released.store(true, Ordering::Relaxed);
        }
    }

    fn fake_stream(chunks: Vec<Vec<u8>>) -> (NativeByteStream, Arc<AtomicBool>, Arc<AtomicBool>) {
        let canceled = Arc::new(AtomicBool::new(false));
        let released = Arc::new(AtomicBool::new(false));
        let context = Box::new(FakeStreamContext {
            chunks: chunks.into(),
            canceled: canceled.clone(),
            released: released.clone(),
        });
        (
            NativeByteStream {
                abi_version: NATIVE_BYTE_STREAM_ABI_VERSION,
                struct_size: std::mem::size_of::<NativeByteStream>(),
                context: Box::into_raw(context).cast(),
                next: Some(fake_next),
                cancel: Some(fake_cancel),
                free_read: Some(fake_free_read),
                release: Some(fake_release),
            },
            canceled,
            released,
        )
    }

    #[test]
    fn builds_default_and_v1_transcription_endpoints() {
        assert_eq!(
            transcription_endpoint("https://api.openai.com", false)
                .unwrap()
                .as_str(),
            "https://api.openai.com/v1/audio/transcriptions"
        );
        assert_eq!(
            transcription_endpoint("https://provider.example/openai/v1/", false)
                .unwrap()
                .as_str(),
            "https://provider.example/openai/v1/audio/transcriptions"
        );
    }

    #[test]
    fn rejects_plain_http_without_explicit_opt_in() {
        assert!(transcription_endpoint("http://127.0.0.1:8000", false).is_err());
        assert!(transcription_endpoint("http://127.0.0.1:8000", true).is_ok());
    }

    #[test]
    fn native_stream_layout_matches_shared_abi() {
        assert!(std::mem::size_of::<NativeByteStream>() > 0);
    }

    #[test]
    fn reads_and_releases_native_stream_chunks() {
        let (stream, canceled, released) =
            fake_stream(vec![b"native".to_vec(), b"-audio".to_vec()]);
        let mut reader = NativeStreamReader::new(stream).unwrap();
        let mut output = Vec::new();
        reader.read_to_end(&mut output).unwrap();
        drop(reader);

        assert_eq!(output, b"native-audio");
        assert!(!canceled.load(Ordering::Relaxed));
        assert!(released.load(Ordering::Relaxed));
    }

    #[test]
    fn cancels_native_stream_when_request_stops_early() {
        let (stream, canceled, released) = fake_stream(vec![b"audio".to_vec()]);
        drop(NativeStreamReader::new(stream).unwrap());

        assert!(canceled.load(Ordering::Relaxed));
        assert!(released.load(Ordering::Relaxed));
    }
}
