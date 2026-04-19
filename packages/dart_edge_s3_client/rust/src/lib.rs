use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use aws_config::BehaviorVersion;
use aws_credential_types::Credentials;
use aws_sdk_s3::config::Builder as S3ConfigBuilder;
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::Client;
use aws_types::region::Region;
use dart_edge_core::{NativeOwnedBytes, free_owned_bytes, into_native_owned_bytes};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use tokio::runtime::{Builder, Runtime};

const DART_EDGE_S3_CLIENT_NATIVE_ABI_VERSION: i32 = 1;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static CLIENTS: Lazy<Mutex<HashMap<i64, Client>>> = Lazy::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));
static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to create dart_edge_s3_client runtime")
});

#[repr(C)]
pub struct NativeS3BytesResult {
    bytes: NativeOwnedBytes,
    result_json: *mut c_char,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeS3ClientConfig {
    region: String,
    endpoint: Option<String>,
    access_key_id: Option<String>,
    secret_access_key: Option<String>,
    session_token: Option<String>,
    #[serde(default)]
    force_path_style: bool,
    #[serde(default)]
    allow_http: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeObjectRef {
    bucket: String,
    key: String,
    version_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativePutObjectBytesRequest {
    bucket: String,
    key: String,
    content_type: Option<String>,
    cache_control: Option<String>,
    content_disposition: Option<String>,
    content_encoding: Option<String>,
    content_language: Option<String>,
    #[serde(default)]
    metadata: HashMap<String, String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativePutObjectResult {
    bucket: String,
    key: String,
    e_tag: Option<String>,
    version_id: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeDeleteObjectResult {
    bucket: String,
    key: String,
    delete_marker: Option<bool>,
    version_id: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeObjectMetadata {
    bucket: String,
    key: String,
    version_id: Option<String>,
    e_tag: Option<String>,
    content_type: Option<String>,
    content_length: i64,
    cache_control: Option<String>,
    content_disposition: Option<String>,
    content_encoding: Option<String>,
    content_language: Option<String>,
    metadata: HashMap<String, String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeGetObjectBytesResultJson {
    metadata: NativeObjectMetadata,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_native_abi_version() -> i32 {
    DART_EDGE_S3_CLIENT_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_create(config_json: *const c_char) -> i64 {
    let Some(config_json) = (unsafe { read_c_string(config_json) }) else {
        set_last_error("Missing S3 client config JSON.");
        return 0;
    };

    let config = match serde_json::from_str::<NativeS3ClientConfig>(&config_json) {
        Ok(config) => config,
        Err(error) => {
            set_last_error(format!("Invalid S3 client config: {error}"));
            return 0;
        }
    };

    let client = match RUNTIME.block_on(build_client(config)) {
        Ok(client) => client,
        Err(error) => {
            set_last_error(error);
            return 0;
        }
    };

    let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
    CLIENTS.lock().unwrap().insert(handle, client);
    clear_last_error();
    handle
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_dispose(handle: i64) {
    CLIENTS.lock().unwrap().remove(&handle);
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_put_object_bytes(
    handle: i64,
    request_json: *const c_char,
    bytes_ptr: *const u8,
    bytes_len: isize,
) -> *mut c_char {
    let Some(client) = client_for_handle(handle) else {
        set_last_error("Unknown dart_edge_s3_client handle.");
        return std::ptr::null_mut();
    };
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing putObject request JSON.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativePutObjectBytesRequest>(&request_json) {
        Ok(request) => request,
        Err(error) => {
            set_last_error(format!("Invalid putObject request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_put_request(&request) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    let bytes = match unsafe { read_input_bytes(bytes_ptr, bytes_len) } {
        Some(bytes) => bytes,
        None => {
            set_last_error("Invalid putObject byte input.");
            return std::ptr::null_mut();
        }
    };

    match RUNTIME.block_on(put_object_bytes(client, request, bytes)) {
        Ok(result) => encode_json_string(&result),
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_get_object_bytes(
    handle: i64,
    request_json: *const c_char,
) -> *mut NativeS3BytesResult {
    let Some(client) = client_for_handle(handle) else {
        set_last_error("Unknown dart_edge_s3_client handle.");
        return std::ptr::null_mut();
    };
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing getObject request JSON.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativeObjectRef>(&request_json) {
        Ok(request) => request,
        Err(error) => {
            set_last_error(format!("Invalid getObject request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_object_ref(&request) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    match RUNTIME.block_on(get_object_bytes(client, request)) {
        Ok(result) => {
            clear_last_error();
            result
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_head_object(
    handle: i64,
    request_json: *const c_char,
) -> *mut c_char {
    let Some(client) = client_for_handle(handle) else {
        set_last_error("Unknown dart_edge_s3_client handle.");
        return std::ptr::null_mut();
    };
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing headObject request JSON.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativeObjectRef>(&request_json) {
        Ok(request) => request,
        Err(error) => {
            set_last_error(format!("Invalid headObject request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_object_ref(&request) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    match RUNTIME.block_on(head_object(client, request)) {
        Ok(result) => encode_json_string(&result),
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_delete_object(
    handle: i64,
    request_json: *const c_char,
) -> *mut c_char {
    let Some(client) = client_for_handle(handle) else {
        set_last_error("Unknown dart_edge_s3_client handle.");
        return std::ptr::null_mut();
    };
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing deleteObject request JSON.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativeObjectRef>(&request_json) {
        Ok(request) => request,
        Err(error) => {
            set_last_error(format!("Invalid deleteObject request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_object_ref(&request) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    match RUNTIME.block_on(delete_object(client, request)) {
        Ok(result) => encode_json_string(&result),
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_bytes_result(value: *mut NativeS3BytesResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let value = Box::from_raw(value);
        free_owned_bytes(value.bytes);
        if !value.result_json.is_null() {
            let _ = CString::from_raw(value.result_json);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_take_last_error() -> *mut c_char {
    LAST_ERROR
        .lock()
        .unwrap()
        .take()
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_s3_client_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

async fn build_client(config: NativeS3ClientConfig) -> Result<Client, String> {
    validate_client_config(&config)?;

    let mut loader = aws_config::defaults(BehaviorVersion::latest())
        .region(Region::new(config.region.clone()));

    if let (Some(access_key_id), Some(secret_access_key)) =
        (config.access_key_id.clone(), config.secret_access_key.clone())
    {
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
    request: NativePutObjectBytesRequest,
    bytes: Vec<u8>,
) -> Result<NativePutObjectResult, String> {
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

    Ok(NativePutObjectResult {
        bucket,
        key,
        e_tag: response.e_tag().map(ToOwned::to_owned),
        version_id: response.version_id().map(ToOwned::to_owned),
    })
}

async fn get_object_bytes(
    client: Client,
    request: NativeObjectRef,
) -> Result<*mut NativeS3BytesResult, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client.get_object().bucket(&request.bucket).key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to get S3 object '{bucket}/{key}': {error}"))?;

    let version_id = response.version_id().map(ToOwned::to_owned);
    let e_tag = response.e_tag().map(ToOwned::to_owned);
    let content_type = response.content_type().map(ToOwned::to_owned);
    let content_length = response.content_length().unwrap_or(0);
    let cache_control = response.cache_control().map(ToOwned::to_owned);
    let content_disposition = response.content_disposition().map(ToOwned::to_owned);
    let content_encoding = response.content_encoding().map(ToOwned::to_owned);
    let content_language = response.content_language().map(ToOwned::to_owned);
    let metadata = response.metadata().cloned().unwrap_or_default();

    let collected = response
        .body
        .collect()
        .await
        .map_err(|error| format!("Failed to read S3 object body '{bucket}/{key}': {error}"))?;
    let bytes = collected.into_bytes().to_vec();

    let result_json = NativeGetObjectBytesResultJson {
        metadata: NativeObjectMetadata {
            bucket,
            key,
            version_id,
            e_tag,
            content_type,
            content_length,
            cache_control,
            content_disposition,
            content_encoding,
            content_language,
            metadata,
        },
    };

    encode_bytes_result(bytes, &result_json)
}

async fn head_object(
    client: Client,
    request: NativeObjectRef,
) -> Result<NativeObjectMetadata, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client.head_object().bucket(&request.bucket).key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to head S3 object '{bucket}/{key}': {error}"))?;

    Ok(NativeObjectMetadata {
        bucket,
        key,
        version_id: response.version_id().map(ToOwned::to_owned),
        e_tag: response.e_tag().map(ToOwned::to_owned),
        content_type: response.content_type().map(ToOwned::to_owned),
        content_length: response.content_length().unwrap_or(0),
        cache_control: response.cache_control().map(ToOwned::to_owned),
        content_disposition: response.content_disposition().map(ToOwned::to_owned),
        content_encoding: response.content_encoding().map(ToOwned::to_owned),
        content_language: response.content_language().map(ToOwned::to_owned),
        metadata: response.metadata().cloned().unwrap_or_default(),
    })
}

async fn delete_object(
    client: Client,
    request: NativeObjectRef,
) -> Result<NativeDeleteObjectResult, String> {
    let bucket = request.bucket.clone();
    let key = request.key.clone();

    let mut operation = client.delete_object().bucket(&request.bucket).key(&request.key);
    if let Some(version_id) = request.version_id.as_ref() {
        operation = operation.version_id(version_id);
    }

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to delete S3 object '{bucket}/{key}': {error}"))?;

    Ok(NativeDeleteObjectResult {
        bucket,
        key,
        delete_marker: response.delete_marker(),
        version_id: response.version_id().map(ToOwned::to_owned),
    })
}

fn client_for_handle(handle: i64) -> Option<Client> {
    CLIENTS.lock().unwrap().get(&handle).cloned()
}

fn validate_client_config(config: &NativeS3ClientConfig) -> Result<(), String> {
    if config.region.trim().is_empty() {
        return Err("S3 client region must not be empty.".to_string());
    }

    match (&config.access_key_id, &config.secret_access_key) {
        (Some(_), Some(_)) | (None, None) => {}
        _ => {
            return Err(
                "S3 client accessKeyId and secretAccessKey must be provided together."
                    .to_string(),
            );
        }
    }

    if config.session_token.is_some() && config.access_key_id.is_none() {
        return Err(
            "S3 client sessionToken requires accessKeyId and secretAccessKey."
                .to_string(),
        );
    }

    if let Some(endpoint) = config.endpoint.as_ref() {
        if endpoint.trim().is_empty() {
            return Err("S3 client endpoint must not be empty when provided.".to_string());
        }
        if endpoint.starts_with("http://") && !config.allow_http {
            return Err(
                "HTTP S3 endpoints require allowHttp: true in S3ClientConfig."
                    .to_string(),
            );
        }
    }

    Ok(())
}

fn validate_object_ref(request: &NativeObjectRef) -> Result<(), String> {
    if request.bucket.trim().is_empty() {
        return Err("S3 object bucket must not be empty.".to_string());
    }
    if request.key.trim().is_empty() {
        return Err("S3 object key must not be empty.".to_string());
    }
    Ok(())
}

fn validate_put_request(request: &NativePutObjectBytesRequest) -> Result<(), String> {
    if request.bucket.trim().is_empty() {
        return Err("putObject bucket must not be empty.".to_string());
    }
    if request.key.trim().is_empty() {
        return Err("putObject key must not be empty.".to_string());
    }
    Ok(())
}

fn encode_json_string<T: Serialize>(value: &T) -> *mut c_char {
    match serde_json::to_string(value) {
        Ok(json) => match CString::new(json) {
            Ok(json) => {
                clear_last_error();
                json.into_raw()
            }
            Err(error) => {
                set_last_error(format!("Failed to encode S3 JSON payload: {error}"));
                std::ptr::null_mut()
            }
        },
        Err(error) => {
            set_last_error(format!("Failed to serialize S3 JSON payload: {error}"));
            std::ptr::null_mut()
        }
    }
}

fn encode_bytes_result<T: Serialize>(
    bytes: Vec<u8>,
    result: &T,
) -> Result<*mut NativeS3BytesResult, String> {
    let result_json = serde_json::to_string(result)
        .map_err(|error| format!("Failed to encode S3 JSON payload: {error}"))?;
    let result_json =
        CString::new(result_json).map_err(|error| format!("Failed to encode C string: {error}"))?;

    Ok(Box::into_raw(Box::new(NativeS3BytesResult {
        bytes: into_native_owned_bytes(bytes),
        result_json: result_json.into_raw(),
    })))
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

fn set_last_error(message: impl Into<String>) {
    let owned = message.into();
    *LAST_ERROR.lock().unwrap() = CString::new(owned).ok();
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
