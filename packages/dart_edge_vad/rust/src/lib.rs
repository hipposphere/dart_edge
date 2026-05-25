use std::ffi::{CStr, CString, c_char};
use std::sync::{
    Mutex, MutexGuard,
    atomic::{AtomicUsize, Ordering},
};

use once_cell::sync::Lazy;
use ort::session::Session;
use ort::value::Tensor;
use serde::{Deserialize, Serialize};

const DART_EDGE_VAD_NATIVE_ABI_VERSION: i32 = 1;
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

struct SileroScratch {
    input_samples: Vec<f32>,
}

impl SileroScratch {
    fn new(window_size_samples: usize) -> Self {
        Self {
            input_samples: Vec::with_capacity(SILERO_CONTEXT_SAMPLES_16KHZ + window_size_samples),
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

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_vad_native_abi_version() -> i32 {
    DART_EDGE_VAD_NATIVE_ABI_VERSION
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
    Box::into_raw(Box::new(DartEdgeVadStream {
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
    }))
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
    with_silero_session(|session| {
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
    })
}

fn run_silero_window(
    session: &mut Session,
    chunk: &[f32],
    request: &SileroDetectRequest,
    state: &mut Vec<f32>,
    context: &mut Vec<f32>,
    scratch: &mut SileroScratch,
) -> Result<f32, String> {
    scratch.input_samples.clear();
    scratch.input_samples.extend_from_slice(context);
    scratch.input_samples.resize(
        SILERO_CONTEXT_SAMPLES_16KHZ + request.window_size_samples,
        0.0,
    );
    scratch.input_samples[SILERO_CONTEXT_SAMPLES_16KHZ..SILERO_CONTEXT_SAMPLES_16KHZ + chunk.len()]
        .copy_from_slice(chunk);

    let input = Tensor::from_array((
        [1_usize, scratch.input_samples.len()],
        scratch.input_samples.clone(),
    ))
    .map_err(|error| format!("Failed to create Silero input tensor: {error}"))?;
    let state_input = Tensor::from_array(([2_usize, 1_usize, 128_usize], std::mem::take(state)))
        .map_err(|error| format!("Failed to create Silero state tensor: {error}"))?;
    let sample_rate = Tensor::from_array(((), vec![request.sample_rate_hz as i64]))
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
    *state = state_data.to_vec();
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
    Session::builder()
        .and_then(|mut builder| builder.commit_from_memory(SILERO_VAD_V6_2_1))
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
