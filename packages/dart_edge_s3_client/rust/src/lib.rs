use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};

use aws_config::BehaviorVersion;
use aws_credential_types::Credentials;
use aws_sdk_s3::Client;
use aws_sdk_s3::config::Builder as S3ConfigBuilder;
use aws_sdk_s3::primitives::ByteStream;
use aws_types::region::Region;
use dart_edge_core::{NativeOwnedBytes, free_owned_bytes, into_native_owned_bytes};
use once_cell::sync::Lazy;
use tokio::runtime::{Builder, Runtime};

const DART_EDGE_S3_CLIENT_NATIVE_ABI_VERSION: i32 = 2;

static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);
static CLIENTS: Lazy<Mutex<HashMap<i64, Client>>> = Lazy::new(|| Mutex::new(HashMap::new()));
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

struct S3ClientConfig {
    region: Option<String>,
    endpoint: Option<String>,
    access_key_id: Option<String>,
    secret_access_key: Option<String>,
    session_token: Option<String>,
    force_path_style: bool,
    allow_http: bool,
}

struct ObjectRef {
    bucket: String,
    key: String,
    version_id: Option<String>,
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

    let response = operation
        .send()
        .await
        .map_err(|error| format!("Failed to get S3 object '{bucket}/{key}': {error}"))?;

    let metadata = ObjectMetadata {
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
