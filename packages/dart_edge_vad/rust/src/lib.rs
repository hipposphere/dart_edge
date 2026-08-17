use std::ffi::{CStr, CString, c_char};
use std::os::raw::c_void;
use std::sync::{
    Mutex, MutexGuard,
    atomic::{AtomicUsize, Ordering},
};

use dart_edge_core::{
    NativeCompletionPort, NativeJobPool, NativeJobSubmitError, initialize_dart_api_dl,
};
use once_cell::sync::Lazy;
use ort::session::{Session, builder::GraphOptimizationLevel};
use ort::value::TensorRef;
use serde::{Deserialize, Serialize};

const DART_EDGE_VAD_NATIVE_ABI_VERSION: i32 = 2;
const SILERO_CONTEXT_SAMPLES_16KHZ: usize = 64;
const SILERO_VAD_V6_2_1: &[u8] = include_bytes!("../models/silero_vad_v6.2.1.onnx");

static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));
static NEXT_SILERO_SESSION: AtomicUsize = AtomicUsize::new(0);
static SILERO_SESSIONS: Lazy<Vec<Mutex<Option<Result<Session, String>>>>> = Lazy::new(|| {
    (0..silero_session_pool_size())
        .map(|_| Mutex::new(None))
        .collect()
});

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SileroDetectRequest {
    model_version: String,
    sample_rate_hz: u32,
    window_size_samples: usize,
    threshold: f32,
    neg_threshold: f32,
    min_speech_duration_ms: u64,
    min_silence_duration_ms: u64,
    speech_pad_ms: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeVadResult {
    sample_rate_hz: u32,
    total_samples: usize,
    has_speech: bool,
    segments: Vec<NativeVadSegment>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeVadSegment {
    start_sample: usize,
    end_sample: usize,
    start_ms: u64,
    end_ms: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeVadStreamResult {
    sample_rate_hz: u32,
    total_samples: usize,
    processed_samples: usize,
    has_speech: bool,
    finished: bool,
    segments: Vec<NativeVadSegment>,
    probabilities: Vec<f32>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeVadTrimRequest {
    #[serde(flatten)]
    vad: SileroDetectRequest,
    max_pending_bytes: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeVadTrimRange {
    source_start_sample: usize,
    source_end_sample: usize,
    output_start_sample: usize,
    output_end_sample: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeVadTrimResultJson {
    sample_rate_hz: u32,
    total_samples: usize,
    processed_samples: usize,
    output_samples: usize,
    buffered_bytes: usize,
    has_speech: bool,
    speech_active: bool,
    finished: bool,
    segments: Vec<NativeVadSegment>,
    ranges: Vec<NativeVadTrimRange>,
}

#[repr(C)]
pub struct DartEdgeVadTrimProcessResult {
    output_ptr: *mut u8,
    output_len: usize,
    output_capacity: usize,
    result_json: *mut c_char,
}

struct SileroScratch {
    input_samples: Vec<f32>,
    sample_rate: [i64; 1],
}

impl SileroScratch {
    fn new(window_size_samples: usize) -> Self {
        Self {
            input_samples: vec![0.0; SILERO_CONTEXT_SAMPLES_16KHZ + window_size_samples],
            sample_rate: [0],
        }
    }
}

pub struct DartEdgeVadStream {
    request: SileroDetectRequest,
    state: Vec<f32>,
    context: Vec<f32>,
    scratch: SileroScratch,
    pending: Vec<f32>,
    total_samples: usize,
    processed_samples: usize,
    active_start: Option<usize>,
    silence_start: Option<usize>,
    has_speech: bool,
    finished: bool,
}

pub struct DartEdgeVadTrimStream {
    vad: DartEdgeVadStream,
    pending_pcm: Vec<u8>,
    pending_start_sample: usize,
    last_emitted_source_end: usize,
    output_samples: usize,
    max_pending_bytes: usize,
    has_speech: bool,
    finished: bool,
}

pub struct DartEdgeVadPool {
    jobs: NativeJobPool<NativeVadPoolJob, String>,
}

struct NativeVadPoolJob {
    request_json: String,
    input: Vec<u8>,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_native_abi_version() -> i32 {
    DART_EDGE_VAD_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_initialize_dart_api_dl(data: *mut c_void) -> i32 {
    match unsafe { initialize_dart_api_dl(data) } {
        Ok(()) => {
            clear_last_error();
            1
        }
        Err(error) => {
            set_last_error(error);
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_detect_silero(
    request_json: *const c_char,
    input_ptr: *const u8,
    input_len: isize,
) -> *mut c_char {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing VAD request.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<SileroDetectRequest>(&request_json) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(format!("Invalid VAD request: {error}"));
            return std::ptr::null_mut();
        }
    };
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing PCM16 byte input.");
        return std::ptr::null_mut();
    };

    match detect_silero(input, request).and_then(|result| encode_json_string(&result)) {
        Ok(value) => {
            clear_last_error();
            value
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_stream_create(
    request_json: *const c_char,
) -> *mut DartEdgeVadStream {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing VAD stream request.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<SileroDetectRequest>(&request_json) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(format!("Invalid VAD stream request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_silero_request(&request) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    clear_last_error();
    Box::into_raw(Box::new(create_vad_stream(request)))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_stream_process(
    stream: *mut DartEdgeVadStream,
    input_ptr: *const u8,
    input_len: isize,
    flush: i32,
) -> *mut c_char {
    if stream.is_null() {
        set_last_error("Missing VAD stream.");
        return std::ptr::null_mut();
    }
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing PCM16 byte input.");
        return std::ptr::null_mut();
    };

    let stream = unsafe { &mut *stream };
    match stream
        .process(input, flush != 0)
        .and_then(|result| encode_json_string(&result))
    {
        Ok(value) => {
            clear_last_error();
            value
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_stream_free(stream: *mut DartEdgeVadStream) {
    if !stream.is_null() {
        drop(unsafe { Box::from_raw(stream) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_trim_stream_create(
    request_json: *const c_char,
) -> *mut DartEdgeVadTrimStream {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing VAD trim stream request.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativeVadTrimRequest>(&request_json) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(format!("Invalid VAD trim stream request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_silero_request(&request.vad) {
        set_last_error(error);
        return std::ptr::null_mut();
    }
    if request.max_pending_bytes == 0 || request.max_pending_bytes % 2 != 0 {
        set_last_error("VAD trim maxPendingBytes must be a positive even number.");
        return std::ptr::null_mut();
    }

    clear_last_error();
    Box::into_raw(Box::new(DartEdgeVadTrimStream {
        vad: create_vad_stream(request.vad),
        pending_pcm: Vec::new(),
        pending_start_sample: 0,
        last_emitted_source_end: 0,
        output_samples: 0,
        max_pending_bytes: request.max_pending_bytes,
        has_speech: false,
        finished: false,
    }))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_trim_stream_process(
    stream: *mut DartEdgeVadTrimStream,
    input_ptr: *const u8,
    input_len: isize,
    flush: i32,
) -> *mut DartEdgeVadTrimProcessResult {
    if stream.is_null() {
        set_last_error("Missing VAD trim stream.");
        return std::ptr::null_mut();
    }
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing PCM16 byte input.");
        return std::ptr::null_mut();
    };

    match unsafe { &mut *stream }
        .process(input, flush != 0)
        .and_then(encode_trim_process_result)
    {
        Ok(value) => {
            clear_last_error();
            value
        }
        Err(error) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_trim_process_result_free(
    result: *mut DartEdgeVadTrimProcessResult,
) {
    if result.is_null() {
        return;
    }
    let result = unsafe { Box::from_raw(result) };
    if result.output_capacity > 0 && !result.output_ptr.is_null() {
        drop(unsafe {
            Vec::from_raw_parts(result.output_ptr, result.output_len, result.output_capacity)
        });
    }
    if !result.result_json.is_null() {
        drop(unsafe { CString::from_raw(result.result_json) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_trim_stream_free(stream: *mut DartEdgeVadTrimStream) {
    if !stream.is_null() {
        drop(unsafe { Box::from_raw(stream) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_pool_create(
    worker_count: usize,
    max_queue_size: usize,
    completion_port: i64,
) -> *mut DartEdgeVadPool {
    if worker_count == 0 {
        set_last_error("VAD pool worker_count must be at least 1.");
        return std::ptr::null_mut();
    }
    if max_queue_size == 0 {
        set_last_error("VAD pool max_queue_size must be at least 1.");
        return std::ptr::null_mut();
    }

    let jobs = match NativeJobPool::new_with_completion(
        worker_count,
        max_queue_size,
        NativeCompletionPort::new(completion_port),
        create_vad_pool_handler,
    ) {
        Ok(jobs) => jobs,
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    clear_last_error();
    Box::into_raw(Box::new(DartEdgeVadPool { jobs }))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_pool_submit_silero(
    pool: *mut DartEdgeVadPool,
    request_json: *const c_char,
    input_ptr: *const u8,
    input_len: isize,
) -> i64 {
    if pool.is_null() {
        set_last_error("Missing VAD pool.");
        return 0;
    }
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing VAD request.");
        return 0;
    };
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing PCM16 byte input.");
        return 0;
    };

    let pool = unsafe { &*pool };
    match pool.jobs.submit(NativeVadPoolJob {
        request_json,
        input: input.to_vec(),
    }) {
        Ok(job_id) => {
            clear_last_error();
            job_id
        }
        Err(NativeJobSubmitError::QueueFull) => {
            set_last_error("VAD pool queue is full.");
            0
        }
        Err(NativeJobSubmitError::Closed) => {
            set_last_error("VAD pool is closed.");
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_pool_take_result(
    pool: *mut DartEdgeVadPool,
    job_id: i64,
) -> *mut c_char {
    if pool.is_null() {
        set_last_error("Missing VAD pool.");
        return std::ptr::null_mut();
    }
    let pool = unsafe { &*pool };
    match pool.jobs.take_result(job_id) {
        Some(Ok(json)) => {
            clear_last_error();
            c_string(json).into_raw()
        }
        Some(Err(error)) => {
            set_last_error(error);
            std::ptr::null_mut()
        }
        None => {
            set_last_error("VAD pool job is not ready.");
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_pool_metrics(pool: *mut DartEdgeVadPool) -> *mut c_char {
    if pool.is_null() {
        set_last_error("Missing VAD pool.");
        return std::ptr::null_mut();
    }
    let pool = unsafe { &*pool };
    let metrics = pool.jobs.metrics();
    match serde_json::to_string(&serde_json::json!({
        "workerCount": metrics.worker_count,
        "maxQueueSize": metrics.max_queue_size,
        "submittedJobs": metrics.submitted_jobs,
        "acceptedJobs": metrics.accepted_jobs,
        "rejectedQueueFullJobs": metrics.rejected_queue_full_jobs,
        "rejectedClosedJobs": metrics.rejected_closed_jobs,
        "startedJobs": metrics.started_jobs,
        "completedSuccessJobs": metrics.completed_success_jobs,
        "completedErrorJobs": metrics.completed_error_jobs,
        "pendingResultCount": metrics.pending_result_count,
        "queuedJobs": metrics.queued_jobs,
        "activeJobs": metrics.active_jobs,
        "maxObservedQueuedJobs": metrics.max_observed_queued_jobs,
        "maxObservedActiveJobs": metrics.max_observed_active_jobs,
        "completionPostFailedJobs": metrics.completion_post_failed_jobs,
    })) {
        Ok(json) => {
            clear_last_error();
            c_string(json).into_raw()
        }
        Err(error) => {
            set_last_error(error.to_string());
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_pool_free(pool: *mut DartEdgeVadPool) {
    if pool.is_null() {
        return;
    }
    drop(unsafe { Box::from_raw(pool) });
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_take_last_error() -> *mut c_char {
    LAST_ERROR
        .lock()
        .unwrap()
        .take()
        .map_or(std::ptr::null_mut(), CString::into_raw)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_free_string(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

fn detect_silero(input: &[u8], request: SileroDetectRequest) -> Result<NativeVadResult, String> {
    validate_silero_request(&request)?;
    if input.len() % 2 != 0 {
        return Err("PCM16 byte input must contain complete i16 samples.".to_string());
    }

    let pcm = pcm16le_to_f32(input);
    let probabilities = run_silero_probabilities(&pcm, &request)?;
    let segments = speech_segments_from_probabilities(
        &probabilities,
        pcm.len(),
        request.sample_rate_hz,
        request.window_size_samples,
        &request,
    );

    Ok(NativeVadResult {
        sample_rate_hz: request.sample_rate_hz,
        total_samples: pcm.len(),
        has_speech: !segments.is_empty(),
        segments,
    })
}

fn detect_silero_with_session(
    input: &[u8],
    request: SileroDetectRequest,
    session: &mut Session,
) -> Result<NativeVadResult, String> {
    validate_silero_request(&request)?;
    if input.len() % 2 != 0 {
        return Err("PCM16 byte input must contain complete i16 samples.".to_string());
    }

    let pcm = pcm16le_to_f32(input);
    let probabilities = run_silero_probabilities_with_session(&pcm, &request, session)?;
    let segments = speech_segments_from_probabilities(
        &probabilities,
        pcm.len(),
        request.sample_rate_hz,
        request.window_size_samples,
        &request,
    );

    Ok(NativeVadResult {
        sample_rate_hz: request.sample_rate_hz,
        total_samples: pcm.len(),
        has_speech: !segments.is_empty(),
        segments,
    })
}

fn create_vad_pool_handler() -> impl FnMut(NativeVadPoolJob) -> Result<String, String> + Send {
    let mut session: Option<Result<Session, String>> = None;
    move |job| {
        let request = serde_json::from_str::<SileroDetectRequest>(&job.request_json)
            .map_err(|error| format!("Invalid VAD request: {error}"))?;
        if session.is_none() {
            session = Some(load_silero_session());
        }
        match session.as_mut().unwrap() {
            Ok(session) => {
                detect_silero_with_session(&job.input, request, session).and_then(|result| {
                    serde_json::to_string(&result).map_err(|error| error.to_string())
                })
            }
            Err(error) => Err(error.clone()),
        }
    }
}

fn validate_silero_request(request: &SileroDetectRequest) -> Result<(), String> {
    if request.model_version != "6.2.1" {
        return Err(format!(
            "Unsupported Silero VAD model version {}.",
            request.model_version
        ));
    }
    if request.sample_rate_hz != 16000 {
        return Err("Silero VAD v6.2.1 expects 16000 Hz PCM input.".to_string());
    }
    if request.window_size_samples != 512 {
        return Err("Silero VAD v6.2.1 expects 512-sample windows.".to_string());
    }
    Ok(())
}

fn run_silero_probabilities(
    pcm: &[f32],
    request: &SileroDetectRequest,
) -> Result<Vec<f32>, String> {
    with_silero_session(|session| run_silero_probabilities_with_session(pcm, request, session))
}

fn run_silero_probabilities_with_session(
    pcm: &[f32],
    request: &SileroDetectRequest,
    session: &mut Session,
) -> Result<Vec<f32>, String> {
    let mut probabilities = Vec::with_capacity(pcm.len().div_ceil(request.window_size_samples));
    let mut state = vec![0.0_f32; 2 * 128];
    let mut context = vec![0.0_f32; SILERO_CONTEXT_SAMPLES_16KHZ];
    let mut scratch = SileroScratch::new(request.window_size_samples);

    for chunk_start in (0..pcm.len()).step_by(request.window_size_samples) {
        let chunk_end = (chunk_start + request.window_size_samples).min(pcm.len());
        let probability = run_silero_window(
            session,
            &pcm[chunk_start..chunk_end],
            request,
            &mut state,
            &mut context,
            &mut scratch,
        )?;
        probabilities.push(probability);
    }

    Ok(probabilities)
}

fn run_silero_window(
    session: &mut Session,
    chunk: &[f32],
    request: &SileroDetectRequest,
    state: &mut Vec<f32>,
    context: &mut Vec<f32>,
    scratch: &mut SileroScratch,
) -> Result<f32, String> {
    scratch.input_samples[..SILERO_CONTEXT_SAMPLES_16KHZ].copy_from_slice(context);
    scratch.input_samples[SILERO_CONTEXT_SAMPLES_16KHZ..].fill(0.0);
    scratch.input_samples[SILERO_CONTEXT_SAMPLES_16KHZ..SILERO_CONTEXT_SAMPLES_16KHZ + chunk.len()]
        .copy_from_slice(chunk);
    scratch.sample_rate[0] = request.sample_rate_hz as i64;

    let input = TensorRef::from_array_view((
        [1_usize, scratch.input_samples.len()],
        scratch.input_samples.as_slice(),
    ))
    .map_err(|error| format!("Failed to create Silero input tensor: {error}"))?;
    let state_input = TensorRef::from_array_view(([2_usize, 1_usize, 128_usize], state.as_slice()))
        .map_err(|error| format!("Failed to create Silero state tensor: {error}"))?;
    let sample_rate = TensorRef::from_array_view(((), scratch.sample_rate.as_slice()))
        .map_err(|error| format!("Failed to create Silero sample-rate tensor: {error}"))?;

    let outputs = session
        .run(ort::inputs! {
            "input" => input,
            "state" => state_input,
            "sr" => sample_rate,
        })
        .map_err(|error| format!("Silero VAD inference failed: {error}"))?;

    let output = outputs
        .get("output")
        .ok_or_else(|| "Silero VAD output tensor is missing.".to_string())?;
    let (_, output_data) = output
        .try_extract_tensor::<f32>()
        .map_err(|error| format!("Failed to read Silero output tensor: {error}"))?;
    let probability = *output_data.first().unwrap_or(&0.0);

    let state_output = outputs
        .get("stateN")
        .or_else(|| outputs.get("state_n"))
        .ok_or_else(|| "Silero VAD state output tensor is missing.".to_string())?;
    let (_, state_data) = state_output
        .try_extract_tensor::<f32>()
        .map_err(|error| format!("Failed to read Silero state tensor: {error}"))?;
    state.copy_from_slice(state_data);
    context.clear();
    context.extend_from_slice(
        &scratch.input_samples[scratch.input_samples.len() - SILERO_CONTEXT_SAMPLES_16KHZ..],
    );

    Ok(probability)
}

fn with_silero_session<T>(
    run: impl FnOnce(&mut Session) -> Result<T, String>,
) -> Result<T, String> {
    let sessions = &*SILERO_SESSIONS;
    let start = NEXT_SILERO_SESSION.fetch_add(1, Ordering::Relaxed);

    let mut run = Some(run);
    for offset in 0..sessions.len() {
        let index = (start + offset) % sessions.len();
        if let Ok(mut guard) = sessions[index].try_lock() {
            return with_silero_session_guard(&mut guard, run.take().unwrap());
        }
    }

    let index = start % sessions.len();
    let mut guard = sessions[index].lock().unwrap();
    with_silero_session_guard(&mut guard, run.take().unwrap())
}

fn with_silero_session_guard<T>(
    guard: &mut MutexGuard<'_, Option<Result<Session, String>>>,
    run: impl FnOnce(&mut Session) -> Result<T, String>,
) -> Result<T, String> {
    if guard.is_none() {
        **guard = Some(load_silero_session());
    }

    match guard.as_mut().unwrap() {
        Ok(session) => run(session),
        Err(error) => Err(error.clone()),
    }
}

fn load_silero_session() -> Result<Session, String> {
    let builder = Session::builder()
        .map_err(|error| format!("Failed to create Silero VAD ONNX session builder: {error}"))?;
    let builder = builder
        .with_optimization_level(GraphOptimizationLevel::All)
        .map_err(|error| format!("Failed to configure Silero VAD graph optimization: {error}"))?;
    let builder = builder
        .with_intra_threads(1)
        .map_err(|error| format!("Failed to configure Silero VAD intra threads: {error}"))?;
    let mut builder = builder
        .with_inter_threads(1)
        .map_err(|error| format!("Failed to configure Silero VAD inter threads: {error}"))?;
    builder
        .commit_from_memory(SILERO_VAD_V6_2_1)
        .map_err(|error| format!("Failed to load Silero VAD ONNX model: {error}"))
}

fn silero_session_pool_size() -> usize {
    std::env::var("DART_EDGE_VAD_SESSION_POOL_SIZE")
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .filter(|value| *value > 0)
        .map(|value| value.min(32))
        .unwrap_or_else(|| {
            std::thread::available_parallelism()
                .map(usize::from)
                .unwrap_or(1)
                .clamp(1, 4)
        })
}

fn create_vad_stream(request: SileroDetectRequest) -> DartEdgeVadStream {
    DartEdgeVadStream {
        request,
        state: vec![0.0_f32; 2 * 128],
        context: vec![0.0_f32; SILERO_CONTEXT_SAMPLES_16KHZ],
        scratch: SileroScratch::new(512),
        pending: Vec::new(),
        total_samples: 0,
        processed_samples: 0,
        active_start: None,
        silence_start: None,
        has_speech: false,
        finished: false,
    }
}

struct NativeVadTrimProcessOutput {
    bytes: Vec<u8>,
    json: NativeVadTrimResultJson,
}

impl DartEdgeVadTrimStream {
    fn process(&mut self, input: &[u8], flush: bool) -> Result<NativeVadTrimProcessOutput, String> {
        if self.finished {
            return Err("VAD trim stream has already been finished.".to_string());
        }
        if input.len() % 2 != 0 {
            return Err("PCM16 byte input must contain complete i16 samples.".to_string());
        }
        let next_pending_bytes = self
            .pending_pcm
            .len()
            .checked_add(input.len())
            .ok_or_else(|| "VAD trim pending byte length overflowed.".to_string())?;
        if next_pending_bytes > self.max_pending_bytes {
            return Err(format!(
                "VAD trim pending audio would exceed its {} byte limit.",
                self.max_pending_bytes
            ));
        }
        self.pending_pcm
            .try_reserve_exact(input.len())
            .map_err(|error| format!("VAD trim could not reserve native input memory: {error}"))?;
        self.pending_pcm.extend_from_slice(input);

        let vad_result = self.vad.process(input, flush)?;
        let mut output = Vec::new();
        let mut ranges = Vec::new();

        for segment in &vad_result.segments {
            self.emit_range(
                segment.start_sample,
                segment.end_sample,
                &mut output,
                &mut ranges,
            )?;
        }

        let min_speech_samples = millis_to_samples(
            self.vad.request.min_speech_duration_ms,
            self.vad.request.sample_rate_hz,
        );
        let speech_pad_samples = millis_to_samples(
            self.vad.request.speech_pad_ms,
            self.vad.request.sample_rate_hz,
        );
        let confirmed_active_start = self.vad.active_start.filter(|start| {
            self.vad.processed_samples.saturating_sub(*start) >= min_speech_samples
        });
        if let Some(active_start) = confirmed_active_start {
            let output_end = self
                .vad
                .silence_start
                .map(|silence| silence.saturating_add(speech_pad_samples))
                .unwrap_or(self.vad.total_samples)
                .min(self.vad.total_samples);
            self.emit_range(
                active_start.saturating_sub(speech_pad_samples),
                output_end,
                &mut output,
                &mut ranges,
            )?;
        }
        self.has_speech |= confirmed_active_start.is_some() || !vad_result.segments.is_empty();

        let discard_before = if flush {
            self.vad.total_samples
        } else if let Some(active_start) = self.vad.active_start {
            if confirmed_active_start.is_some() {
                self.last_emitted_source_end
            } else {
                active_start.saturating_sub(speech_pad_samples)
            }
        } else {
            self.vad
                .processed_samples
                .saturating_sub(speech_pad_samples)
        };
        self.discard_before(discard_before);
        self.finished = flush;

        Ok(NativeVadTrimProcessOutput {
            bytes: output,
            json: NativeVadTrimResultJson {
                sample_rate_hz: vad_result.sample_rate_hz,
                total_samples: vad_result.total_samples,
                processed_samples: vad_result.processed_samples,
                output_samples: self.output_samples,
                buffered_bytes: self.pending_pcm.len(),
                has_speech: self.has_speech,
                speech_active: confirmed_active_start.is_some(),
                finished: vad_result.finished,
                segments: vad_result.segments,
                ranges,
            },
        })
    }

    fn emit_range(
        &mut self,
        requested_start: usize,
        requested_end: usize,
        output: &mut Vec<u8>,
        ranges: &mut Vec<NativeVadTrimRange>,
    ) -> Result<(), String> {
        let start = requested_start
            .max(self.pending_start_sample)
            .max(self.last_emitted_source_end);
        let end = requested_end.min(self.vad.total_samples);
        if end <= start {
            return Ok(());
        }
        let relative_start = start
            .checked_sub(self.pending_start_sample)
            .and_then(|samples| samples.checked_mul(2))
            .ok_or_else(|| "VAD trim range start overflowed.".to_string())?;
        let relative_end = end
            .checked_sub(self.pending_start_sample)
            .and_then(|samples| samples.checked_mul(2))
            .ok_or_else(|| "VAD trim range end overflowed.".to_string())?;
        if relative_end > self.pending_pcm.len() || relative_start > relative_end {
            return Err("VAD trim range is outside buffered audio.".to_string());
        }
        let byte_length = relative_end - relative_start;
        let peak_bytes = self
            .pending_pcm
            .len()
            .checked_add(output.len())
            .and_then(|bytes| bytes.checked_add(byte_length))
            .ok_or_else(|| "VAD trim working byte length overflowed.".to_string())?;
        if peak_bytes > self.max_pending_bytes {
            return Err(format!(
                "VAD trim working audio would exceed its {} byte limit.",
                self.max_pending_bytes
            ));
        }
        output
            .try_reserve_exact(byte_length)
            .map_err(|error| format!("VAD trim could not reserve native output memory: {error}"))?;
        output.extend_from_slice(&self.pending_pcm[relative_start..relative_end]);
        let output_start_sample = self.output_samples;
        let emitted_samples = end - start;
        self.output_samples = self
            .output_samples
            .checked_add(emitted_samples)
            .ok_or_else(|| "VAD trim output sample count overflowed.".to_string())?;
        ranges.push(NativeVadTrimRange {
            source_start_sample: start,
            source_end_sample: end,
            output_start_sample,
            output_end_sample: self.output_samples,
        });
        self.last_emitted_source_end = end;
        Ok(())
    }

    fn discard_before(&mut self, requested_sample: usize) {
        let end_sample = self.pending_start_sample + self.pending_pcm.len() / 2;
        let discard_sample = requested_sample
            .max(self.pending_start_sample)
            .min(end_sample);
        let discard_bytes = (discard_sample - self.pending_start_sample) * 2;
        if discard_bytes > 0 {
            self.pending_pcm.drain(..discard_bytes);
            self.pending_start_sample = discard_sample;
        }
    }
}

fn encode_trim_process_result(
    output: NativeVadTrimProcessOutput,
) -> Result<*mut DartEdgeVadTrimProcessResult, String> {
    let result_json = serde_json::to_string(&output.json)
        .map_err(|error| format!("Failed to encode VAD trim result: {error}"))?;
    let result_json = c_string(result_json).into_raw();
    let mut bytes = std::mem::ManuallyDrop::new(output.bytes);
    let (output_ptr, output_len, output_capacity) = if bytes.is_empty() {
        (std::ptr::null_mut(), 0, 0)
    } else {
        (bytes.as_mut_ptr(), bytes.len(), bytes.capacity())
    };
    Ok(Box::into_raw(Box::new(DartEdgeVadTrimProcessResult {
        output_ptr,
        output_len,
        output_capacity,
        result_json,
    })))
}

impl DartEdgeVadStream {
    fn process(&mut self, input: &[u8], flush: bool) -> Result<NativeVadStreamResult, String> {
        if self.finished {
            return Err("VAD stream has already been finished.".to_string());
        }
        if input.len() % 2 != 0 {
            return Err("PCM16 byte input must contain complete i16 samples.".to_string());
        }

        self.pending.extend(pcm16le_to_f32(input));
        self.total_samples += input.len() / 2;

        let mut probabilities = Vec::new();
        let mut segments = Vec::new();
        with_silero_session(|session| {
            while self.pending.len() >= self.request.window_size_samples {
                let chunk = self
                    .pending
                    .drain(..self.request.window_size_samples)
                    .collect::<Vec<_>>();
                let frame_start = self.processed_samples;
                self.processed_samples += self.request.window_size_samples;
                let frame_end = self.processed_samples;
                let probability = run_silero_window(
                    session,
                    &chunk,
                    &self.request,
                    &mut self.state,
                    &mut self.context,
                    &mut self.scratch,
                )?;
                probabilities.push(probability);
                self.consume_probability(probability, frame_start, frame_end, &mut segments);
            }

            if flush && !self.pending.is_empty() {
                let chunk = std::mem::take(&mut self.pending);
                let frame_start = self.processed_samples;
                self.processed_samples = self.total_samples;
                let frame_end = self.total_samples;
                let probability = run_silero_window(
                    session,
                    &chunk,
                    &self.request,
                    &mut self.state,
                    &mut self.context,
                    &mut self.scratch,
                )?;
                probabilities.push(probability);
                self.consume_probability(probability, frame_start, frame_end, &mut segments);
            }

            Ok(())
        })?;

        if flush {
            if let Some(start) = self.active_start.take() {
                append_segment(
                    &mut segments,
                    start,
                    self.total_samples,
                    self.total_samples,
                    self.request.sample_rate_hz,
                    millis_to_samples(
                        self.request.min_speech_duration_ms,
                        self.request.sample_rate_hz,
                    ),
                    millis_to_samples(self.request.speech_pad_ms, self.request.sample_rate_hz),
                );
                self.has_speech |= !segments.is_empty();
            }
            self.silence_start = None;
            self.finished = true;
        }

        Ok(NativeVadStreamResult {
            sample_rate_hz: self.request.sample_rate_hz,
            total_samples: self.total_samples,
            processed_samples: self.processed_samples,
            has_speech: self.has_speech || !segments.is_empty(),
            finished: self.finished,
            segments,
            probabilities,
        })
    }

    fn consume_probability(
        &mut self,
        probability: f32,
        frame_start: usize,
        frame_end: usize,
        segments: &mut Vec<NativeVadSegment>,
    ) {
        if probability >= self.request.threshold {
            self.active_start.get_or_insert(frame_start);
            self.silence_start = None;
            return;
        }

        let Some(start) = self.active_start else {
            return;
        };
        if probability >= self.request.neg_threshold {
            return;
        }

        let silence = *self.silence_start.get_or_insert(frame_start);
        let min_silence_samples = millis_to_samples(
            self.request.min_silence_duration_ms,
            self.request.sample_rate_hz,
        );
        if frame_end.saturating_sub(silence) < min_silence_samples {
            return;
        }

        let previous_len = segments.len();
        append_segment(
            segments,
            start,
            silence,
            self.total_samples,
            self.request.sample_rate_hz,
            millis_to_samples(
                self.request.min_speech_duration_ms,
                self.request.sample_rate_hz,
            ),
            millis_to_samples(self.request.speech_pad_ms, self.request.sample_rate_hz),
        );
        self.has_speech |= segments.len() > previous_len;
        self.active_start = None;
        self.silence_start = None;
    }
}

fn speech_segments_from_probabilities(
    probabilities: &[f32],
    total_samples: usize,
    sample_rate_hz: u32,
    window_size_samples: usize,
    request: &SileroDetectRequest,
) -> Vec<NativeVadSegment> {
    let min_speech_samples = millis_to_samples(request.min_speech_duration_ms, sample_rate_hz);
    let min_silence_samples = millis_to_samples(request.min_silence_duration_ms, sample_rate_hz);
    let speech_pad_samples = millis_to_samples(request.speech_pad_ms, sample_rate_hz);
    let mut segments = Vec::new();
    let mut active_start: Option<usize> = None;
    let mut silence_start: Option<usize> = None;

    for (index, probability) in probabilities.iter().copied().enumerate() {
        let frame_start = index * window_size_samples;
        let frame_end = frame_start + window_size_samples;

        if probability >= request.threshold {
            active_start.get_or_insert(frame_start);
            silence_start = None;
            continue;
        }

        let Some(start) = active_start else {
            continue;
        };
        if probability >= request.neg_threshold {
            continue;
        }

        let silence = *silence_start.get_or_insert(frame_start);
        if frame_end.saturating_sub(silence) < min_silence_samples {
            continue;
        }

        append_segment(
            &mut segments,
            start,
            silence,
            total_samples,
            sample_rate_hz,
            min_speech_samples,
            speech_pad_samples,
        );
        active_start = None;
        silence_start = None;
    }

    if let Some(start) = active_start {
        append_segment(
            &mut segments,
            start,
            total_samples,
            total_samples,
            sample_rate_hz,
            min_speech_samples,
            speech_pad_samples,
        );
    }

    segments
}

fn append_segment(
    segments: &mut Vec<NativeVadSegment>,
    start_sample: usize,
    end_sample: usize,
    total_samples: usize,
    sample_rate_hz: u32,
    min_speech_samples: usize,
    speech_pad_samples: usize,
) {
    if end_sample.saturating_sub(start_sample) < min_speech_samples {
        return;
    }

    let start = start_sample.saturating_sub(speech_pad_samples);
    let end = (end_sample + speech_pad_samples).min(total_samples);

    if let Some(previous) = segments.last_mut() {
        if start <= previous.end_sample {
            previous.end_sample = end;
            previous.end_ms = samples_to_millis(end, sample_rate_hz);
            return;
        }
    }

    segments.push(NativeVadSegment {
        start_sample: start,
        end_sample: end,
        start_ms: samples_to_millis(start, sample_rate_hz),
        end_ms: samples_to_millis(end, sample_rate_hz),
    });
}

fn pcm16le_to_f32(input: &[u8]) -> Vec<f32> {
    input
        .chunks_exact(2)
        .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]) as f32 / 32768.0)
        .collect()
}

fn millis_to_samples(millis: u64, sample_rate_hz: u32) -> usize {
    ((millis as u128 * sample_rate_hz as u128) / 1000) as usize
}

fn samples_to_millis(samples: usize, sample_rate_hz: u32) -> u64 {
    ((samples as u128 * 1000) / sample_rate_hz as u128) as u64
}

unsafe fn read_c_string(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }
    Some(
        unsafe { CStr::from_ptr(value) }
            .to_string_lossy()
            .into_owned(),
    )
}

unsafe fn read_bytes<'a>(ptr: *const u8, len: isize) -> Option<&'a [u8]> {
    if len < 0 || (ptr.is_null() && len > 0) {
        return None;
    }
    Some(unsafe { std::slice::from_raw_parts(ptr, len as usize) })
}

fn encode_json_string<T: Serialize>(value: &T) -> Result<*mut c_char, String> {
    let json = serde_json::to_string(value).map_err(|error| error.to_string())?;
    Ok(c_string(json).into_raw())
}

fn set_last_error(error: impl Into<String>) {
    *LAST_ERROR.lock().unwrap() = Some(c_string(error.into()));
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

fn c_string(value: String) -> CString {
    let sanitized = value.replace('\0', "");
    CString::new(sanitized).unwrap_or_else(|_| CString::new("dart_edge_vad native error").unwrap())
}
