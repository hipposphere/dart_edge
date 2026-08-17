mod encoding;

use std::collections::BTreeMap;
use std::ffi::{CStr, CString, c_char};
use std::fs;
use std::io::{Cursor, Seek, Write};
use std::os::raw::c_void;
use std::path::Path;
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
};

use audioadapter_buffers::direct::SequentialSliceOfVecs;
use dart_edge_core::{
    NATIVE_BYTE_STREAM_ABI_VERSION, NATIVE_BYTE_STREAM_READ_CANCELED,
    NATIVE_BYTE_STREAM_READ_CHUNK, NATIVE_BYTE_STREAM_READ_DONE, NATIVE_BYTE_STREAM_READ_ERROR,
    NativeByteStream, NativeByteStreamRead, NativeBytes, NativeCompletionPort, NativeJobPool,
    NativeJobSubmitError, NativeOwnedBytes, free_owned_bytes, initialize_dart_api_dl,
    into_native_owned_bytes, read_native_bytes, read_native_string,
};
use hound::{SampleFormat, WavSpec, WavWriter};
use once_cell::sync::Lazy;
use rubato::{Async, FixedAsync, PolynomialDegree, Resampler};
use serde::{Deserialize, Serialize};
use symphonia::core::codecs::CodecParameters;
use symphonia::core::codecs::audio::well_known::{
    CODEC_ID_AAC, CODEC_ID_FLAC, CODEC_ID_MP3, CODEC_ID_PCM_F32LE, CODEC_ID_PCM_F64LE,
    CODEC_ID_PCM_S16LE, CODEC_ID_PCM_S24LE, CODEC_ID_PCM_S32LE, CODEC_ID_PCM_U16LE,
    CODEC_ID_PCM_U24LE, CODEC_ID_PCM_U32LE, CODEC_ID_VORBIS,
};
use symphonia::core::codecs::audio::{AudioCodecId, AudioDecoderOptions, CODEC_ID_NULL_AUDIO};
use symphonia::core::errors::Error as SymphoniaError;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, Track, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::{MetadataOptions, MetadataRevision, StandardTag, Tag};
use symphonia::core::units::Timestamp;
use symphonia::default::{get_codecs, get_probe};

use encoding::encode_audio;

const DART_EDGE_AUDIO_NATIVE_ABI_VERSION: i32 = 5;

static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

#[repr(C)]
pub struct NativeAudioBytesResult {
    bytes: NativeOwnedBytes,
    waveform: NativeOwnedBytes,
    result_json: *mut c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NativeAudioStreamInput {
    stream: NativeByteStream,
    file_name_hint: *const c_char,
    mime_type_hint: *const c_char,
}

#[repr(C)]
pub struct NativeAudioStreamResult {
    stream: NativeByteStream,
    content_length: i64,
    result_json: *mut c_char,
}

pub struct DartEdgeAudioPool {
    jobs: NativeJobPool<NativeAudioPoolJob, NativeAudioPoolResult, String>,
}

pub struct DartEdgeAudioWaveformSession {
    accumulator: Option<WaveformAccumulator>,
    spec: NativeWaveformSpec,
    sample_rate_hz: u32,
    channel_count: u32,
    frame_count: u64,
}

pub struct DartEdgeAudioPcm16StreamSession {
    input: Vec<u8>,
    input_sample_rate_hz: u32,
    input_channel_count: u32,
    target_format: NativeAudioTargetFormat,
    target_sample_rate: Option<u32>,
    channel_layout: NativeAudioChannelLayout,
    max_buffered_bytes: usize,
}

enum NativeAudioPoolJob {
    ProbeFile {
        request_json: String,
    },
    ProbeBytes {
        options_json: Option<String>,
        input: Vec<u8>,
    },
    ConvertFile {
        request_json: String,
    },
    ConvertBytes {
        request_json: String,
        input: Vec<u8>,
    },
    ConcatenateStreams {
        request_json: String,
        inputs: Vec<OwnedAudioStreamInput>,
    },
    FinishPcm16Stream {
        session: Box<DartEdgeAudioPcm16StreamSession>,
    },
}

enum NativeAudioPoolResult {
    FileJson(String),
    ProbeJson(String),
    ConvertedBytes {
        bytes: Vec<u8>,
        waveform: Vec<u8>,
        result_json: String,
    },
    ConvertedStream {
        stream: OwnedNativeByteStream,
        content_length: u64,
        result_json: String,
    },
}

struct OwnedAudioStreamInput {
    stream: OwnedNativeByteStream,
    file_name_hint: Option<String>,
    mime_type_hint: Option<String>,
}

struct OwnedNativeByteStream {
    descriptor: NativeByteStream,
    completed: bool,
    transferred: bool,
}

impl OwnedNativeByteStream {
    fn new(descriptor: NativeByteStream) -> Self {
        Self {
            descriptor,
            completed: false,
            transferred: false,
        }
    }

    fn mark_completed(&mut self) {
        self.completed = true;
    }

    fn into_descriptor(mut self) -> NativeByteStream {
        self.transferred = true;
        self.descriptor
    }
}

impl Drop for OwnedNativeByteStream {
    fn drop(&mut self) {
        if self.transferred {
            return;
        }
        unsafe {
            if !self.completed
                && let Some(cancel) = self.descriptor.cancel
            {
                cancel(self.descriptor.context);
            }
            if let Some(release) = self.descriptor.release {
                release(self.descriptor.context);
            }
        }
    }
}

unsafe impl Send for OwnedNativeByteStream {}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeProbeBytesRequest {
    file_name_hint: Option<String>,
    mime_type_hint: Option<String>,
    #[serde(default)]
    mode: NativeAudioProbeMode,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeProbeFileRequest {
    path: String,
    #[serde(default)]
    mode: NativeAudioProbeMode,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeFileConversionRequest {
    input_path: String,
    output_path: String,
    target_format: NativeAudioTargetFormat,
    target_sample_rate: Option<u32>,
    #[serde(default)]
    channel_layout: NativeAudioChannelLayout,
    #[serde(default)]
    overwrite_existing: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeBytesConversionRequest {
    file_name_hint: Option<String>,
    mime_type_hint: Option<String>,
    target_format: NativeAudioTargetFormat,
    target_sample_rate: Option<u32>,
    #[serde(default)]
    channel_layout: NativeAudioChannelLayout,
    waveform: Option<NativeWaveformSpec>,
    #[serde(default)]
    waveform_only: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeWaveformSpec {
    base_interval_micros: u64,
    level_factors: Vec<u32>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeStreamingWaveformRequest {
    sample_rate_hz: u32,
    channel_count: u32,
    waveform: NativeWaveformSpec,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativePcm16StreamRequest {
    input_sample_rate_hz: u32,
    input_channel_count: u32,
    target_format: NativeAudioTargetFormat,
    target_sample_rate: Option<u32>,
    #[serde(default)]
    channel_layout: NativeAudioChannelLayout,
    max_buffered_bytes: usize,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeStreamConcatenationRequest {
    target_format: NativeAudioTargetFormat,
    target_sample_rate: Option<u32>,
    #[serde(default)]
    channel_layout: NativeAudioChannelLayout,
}

#[derive(Deserialize, Clone, Copy)]
#[serde(untagged)]
enum NativeAudioTargetFormat {
    Legacy(NativeLegacyAudioTargetFormat),
    Output(NativeAudioOutputSpec),
}

#[derive(Deserialize, Clone, Copy)]
#[serde(rename_all = "camelCase")]
enum NativeLegacyAudioTargetFormat {
    WavPcm16,
    WavPcm24,
}

#[derive(Deserialize, Clone, Copy)]
#[serde(tag = "format", rename_all = "camelCase")]
enum NativeAudioOutputSpec {
    WavPcm16,
    WavPcm24,
    M4aAacLc {
        #[serde(default = "default_aac_bit_rate")]
        bit_rate: u32,
    },
    Flac {
        #[serde(default = "default_flac_compression_level")]
        compression_level: u8,
    },
}

fn default_aac_bit_rate() -> u32 {
    48_000
}

fn default_flac_compression_level() -> u8 {
    5
}

#[derive(Default, Deserialize, Clone, Copy)]
#[serde(rename_all = "camelCase")]
enum NativeAudioProbeMode {
    #[default]
    Adaptive,
    Shallow,
    Full,
}

impl NativeAudioTargetFormat {
    fn validate(self) -> Result<(), String> {
        match self.output() {
            NativeAudioOutputSpec::M4aAacLc { bit_rate }
                if !(8_000..=512_000).contains(&bit_rate) =>
            {
                Err("AAC bit rate must be between 8000 and 512000 bits per second.".to_string())
            }
            NativeAudioOutputSpec::Flac { compression_level } if compression_level > 8 => {
                Err("FLAC compression level must be between 0 and 8.".to_string())
            }
            _ => Ok(()),
        }
    }

    fn output(self) -> NativeAudioOutputSpec {
        match self {
            Self::Legacy(NativeLegacyAudioTargetFormat::WavPcm16) => {
                NativeAudioOutputSpec::WavPcm16
            }
            Self::Legacy(NativeLegacyAudioTargetFormat::WavPcm24) => {
                NativeAudioOutputSpec::WavPcm24
            }
            Self::Output(output) => output,
        }
    }

    fn pcm_bit_depth(self) -> Result<u16, String> {
        match self.output() {
            NativeAudioOutputSpec::WavPcm16 => Ok(16),
            NativeAudioOutputSpec::WavPcm24 => Ok(24),
            NativeAudioOutputSpec::Flac { .. } => Ok(16),
            NativeAudioOutputSpec::M4aAacLc { .. } => {
                Err("AAC output does not expose a PCM bit depth.".to_string())
            }
        }
    }

    fn metadata_bit_depth(self) -> Option<u32> {
        match self.output() {
            NativeAudioOutputSpec::WavPcm16 | NativeAudioOutputSpec::Flac { .. } => Some(16),
            NativeAudioOutputSpec::WavPcm24 => Some(24),
            NativeAudioOutputSpec::M4aAacLc { .. } => None,
        }
    }

    fn codec_name(self) -> &'static str {
        match self.output() {
            NativeAudioOutputSpec::WavPcm16 => "pcm_s16le",
            NativeAudioOutputSpec::WavPcm24 => "pcm_s24le",
            NativeAudioOutputSpec::M4aAacLc { .. } => "aac",
            NativeAudioOutputSpec::Flac { .. } => "flac",
        }
    }

    fn container(self) -> &'static str {
        match self.output() {
            NativeAudioOutputSpec::WavPcm16 | NativeAudioOutputSpec::WavPcm24 => "wav",
            NativeAudioOutputSpec::M4aAacLc { .. } => "mp4",
            NativeAudioOutputSpec::Flac { .. } => "flac",
        }
    }

    fn mime_type(self) -> &'static str {
        match self.output() {
            NativeAudioOutputSpec::WavPcm16 | NativeAudioOutputSpec::WavPcm24 => "audio/wav",
            NativeAudioOutputSpec::M4aAacLc { .. } => "audio/mp4",
            NativeAudioOutputSpec::Flac { .. } => "audio/flac",
        }
    }

    fn file_extension(self) -> &'static str {
        match self.output() {
            NativeAudioOutputSpec::WavPcm16 | NativeAudioOutputSpec::WavPcm24 => "wav",
            NativeAudioOutputSpec::M4aAacLc { .. } => "m4a",
            NativeAudioOutputSpec::Flac { .. } => "flac",
        }
    }

    fn target_bit_rate(self) -> Option<u32> {
        match self.output() {
            NativeAudioOutputSpec::M4aAacLc { bit_rate } => Some(bit_rate),
            _ => None,
        }
    }
}

#[derive(Default, Deserialize, Clone, Copy)]
#[serde(rename_all = "camelCase")]
enum NativeAudioChannelLayout {
    #[default]
    KeepSource,
    Mono,
    Stereo,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeAudioMetadata {
    duration_micros: u64,
    container: Option<String>,
    codec: Option<String>,
    sample_rate: Option<u32>,
    channel_count: Option<u32>,
    bit_rate: Option<u32>,
    bit_depth: Option<u32>,
    tags: BTreeMap<String, String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeFileConversionResult {
    output_path: String,
    mime_type: String,
    file_extension: String,
    metadata: NativeAudioMetadata,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeBytesConversionResultJson {
    mime_type: String,
    file_extension: String,
    metadata: NativeAudioMetadata,
    #[serde(skip_serializing_if = "Option::is_none")]
    waveform: Option<NativeWaveformResultJson>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeWaveformResultJson {
    base_interval_micros: u64,
    levels: Vec<NativeWaveformLevelJson>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeWaveformLevelJson {
    factor: u32,
    interval_micros: u64,
    byte_offset: usize,
    byte_length: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeStreamingWaveformResultJson {
    sample_rate_hz: u32,
    channel_count: u32,
    frame_count: u64,
    waveform: NativeWaveformResultJson,
}

struct DecodedAudio {
    samples: Vec<Vec<f32>>,
    sample_rate: u32,
    container: Option<String>,
    codec: Option<String>,
    bit_rate: Option<u32>,
    bit_depth: Option<u32>,
    tags: BTreeMap<String, String>,
}

struct ConvertedAudio {
    samples: Vec<Vec<f32>>,
    sample_rate: u32,
    target_format: NativeAudioTargetFormat,
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_native_abi_version() -> i32 {
    DART_EDGE_AUDIO_NATIVE_ABI_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_initialize_dart_api_dl(data: *mut c_void) -> i32 {
    match unsafe { initialize_dart_api_dl(data) } {
        Ok(()) => {
            clear_last_error();
            1
        }
        Err(error) if error == "Dart API DL initialization raced." => {
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
pub extern "C" fn dart_edge_audio_probe_file(path: *const c_char) -> *mut c_char {
    let Some(input) = (unsafe { read_c_string(path) }) else {
        set_last_error("Missing audio input path.");
        return std::ptr::null_mut();
    };
    let request =
        serde_json::from_str::<NativeProbeFileRequest>(&input).unwrap_or(NativeProbeFileRequest {
            path: input,
            mode: NativeAudioProbeMode::Adaptive,
        });

    match probe_file(&request.path, request.mode).and_then(|metadata| encode_json_string(&metadata))
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
pub extern "C" fn dart_edge_audio_probe_bytes(
    options_json: *const c_char,
    input_ptr: *const u8,
    input_len: isize,
) -> *mut c_char {
    let options = match read_optional_json::<NativeProbeBytesRequest>(options_json) {
        Ok(value) => value.unwrap_or(NativeProbeBytesRequest {
            file_name_hint: None,
            mime_type_hint: None,
            mode: NativeAudioProbeMode::Adaptive,
        }),
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing audio byte input.");
        return std::ptr::null_mut();
    };

    match probe_bytes(
        input,
        options.file_name_hint.as_deref(),
        options.mime_type_hint.as_deref(),
        options.mode,
    )
    .and_then(|metadata| encode_json_string(&metadata))
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
pub extern "C" fn dart_edge_audio_convert_file(request_json: *const c_char) -> *mut c_char {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing audio conversion request.");
        return std::ptr::null_mut();
    };

    let request = match serde_json::from_str::<NativeFileConversionRequest>(&request_json) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(format!("Invalid audio conversion request: {error}"));
            return std::ptr::null_mut();
        }
    };

    match convert_file(request).and_then(|result| encode_json_string(&result)) {
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
pub extern "C" fn dart_edge_audio_convert_bytes(
    request_json: *const c_char,
    input_ptr: *const u8,
    input_len: isize,
) -> *mut NativeAudioBytesResult {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing audio conversion request.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativeBytesConversionRequest>(&request_json) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(format!("Invalid audio conversion request: {error}"));
            return std::ptr::null_mut();
        }
    };
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing audio byte input.");
        return std::ptr::null_mut();
    };

    match convert_bytes(input, request) {
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
pub extern "C" fn dart_edge_audio_waveform_create(
    request_json: *const c_char,
) -> *mut DartEdgeAudioWaveformSession {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing streaming waveform request.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativeStreamingWaveformRequest>(&request_json) {
        Ok(value) => value,
        Err(error) => {
            set_last_error(format!("Invalid streaming waveform request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if request.sample_rate_hz == 0 || request.sample_rate_hz > 768_000 {
        set_last_error("Streaming waveform sampleRateHz must be between 1 and 768000.");
        return std::ptr::null_mut();
    }
    if request.channel_count == 0 || request.channel_count > 32 {
        set_last_error("Streaming waveform channelCount must be between 1 and 32.");
        return std::ptr::null_mut();
    }
    if let Err(error) = validate_waveform_spec(&request.waveform) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    let accumulator = WaveformAccumulator::new(
        request.sample_rate_hz,
        request.waveform.base_interval_micros,
    );
    clear_last_error();
    Box::into_raw(Box::new(DartEdgeAudioWaveformSession {
        accumulator: Some(accumulator),
        spec: request.waveform,
        sample_rate_hz: request.sample_rate_hz,
        channel_count: request.channel_count,
        frame_count: 0,
    }))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_waveform_add_pcm16(
    session: *mut DartEdgeAudioWaveformSession,
    input_ptr: *const u8,
    input_len: isize,
) -> i32 {
    if session.is_null() {
        set_last_error("Missing streaming waveform session.");
        return 0;
    }
    if input_len < 0 {
        set_last_error("Streaming PCM16 byte length must not be negative.");
        return 0;
    }
    if input_len == 0 {
        clear_last_error();
        return 1;
    }
    if input_ptr.is_null() {
        set_last_error("Missing streaming PCM16 input.");
        return 0;
    }
    let input = unsafe { std::slice::from_raw_parts(input_ptr, input_len as usize) };
    match unsafe { &mut *session }.add_pcm16(input) {
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
pub extern "C" fn dart_edge_audio_waveform_finish(
    session: *mut DartEdgeAudioWaveformSession,
) -> *mut NativeAudioBytesResult {
    if session.is_null() {
        set_last_error("Missing streaming waveform session.");
        return std::ptr::null_mut();
    }
    match unsafe { &mut *session }.finish() {
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
pub extern "C" fn dart_edge_audio_waveform_free(session: *mut DartEdgeAudioWaveformSession) {
    if !session.is_null() {
        drop(unsafe { Box::from_raw(session) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pcm16_stream_create(
    request_json: *const c_char,
) -> *mut DartEdgeAudioPcm16StreamSession {
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing PCM16 stream request.");
        return std::ptr::null_mut();
    };
    let request = match serde_json::from_str::<NativePcm16StreamRequest>(&request_json) {
        Ok(request) => request,
        Err(error) => {
            set_last_error(format!("Invalid PCM16 stream request: {error}"));
            return std::ptr::null_mut();
        }
    };
    if let Err(error) = validate_pcm16_stream_request(&request) {
        set_last_error(error);
        return std::ptr::null_mut();
    }

    clear_last_error();
    Box::into_raw(Box::new(DartEdgeAudioPcm16StreamSession {
        input: Vec::new(),
        input_sample_rate_hz: request.input_sample_rate_hz,
        input_channel_count: request.input_channel_count,
        target_format: request.target_format,
        target_sample_rate: request.target_sample_rate,
        channel_layout: request.channel_layout,
        max_buffered_bytes: request.max_buffered_bytes,
    }))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pcm16_stream_add(
    session: *mut DartEdgeAudioPcm16StreamSession,
    input_ptr: *const u8,
    input_len: isize,
) -> i32 {
    if session.is_null() {
        set_last_error("Missing PCM16 stream session.");
        return 0;
    }
    if input_len < 0 {
        set_last_error("PCM16 stream input length must not be negative.");
        return 0;
    }
    if input_len > 0 && input_ptr.is_null() {
        set_last_error("Missing PCM16 stream input.");
        return 0;
    }
    let input = if input_len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(input_ptr, input_len as usize) }
    };

    match unsafe { &mut *session }.add_pcm16(input) {
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
pub extern "C" fn dart_edge_audio_pcm16_stream_free(session: *mut DartEdgeAudioPcm16StreamSession) {
    if !session.is_null() {
        drop(unsafe { Box::from_raw(session) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_create(
    worker_count: usize,
    max_queue_size: usize,
    completion_port: i64,
) -> *mut DartEdgeAudioPool {
    if worker_count == 0 {
        set_last_error("Audio pool worker_count must be at least 1.");
        return std::ptr::null_mut();
    }
    if max_queue_size == 0 {
        set_last_error("Audio pool max_queue_size must be at least 1.");
        return std::ptr::null_mut();
    }

    let jobs = match NativeJobPool::new_with_completion(
        worker_count,
        max_queue_size,
        NativeCompletionPort::new(completion_port),
        create_audio_pool_handler,
    ) {
        Ok(jobs) => jobs,
        Err(error) => {
            set_last_error(error);
            return std::ptr::null_mut();
        }
    };

    clear_last_error();
    Box::into_raw(Box::new(DartEdgeAudioPool { jobs }))
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_submit_probe_file(
    pool: *mut DartEdgeAudioPool,
    request_json: *const c_char,
) -> i64 {
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return 0;
    }
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing audio probe request.");
        return 0;
    };

    submit_audio_pool_job(
        unsafe { &*pool },
        NativeAudioPoolJob::ProbeFile { request_json },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_submit_probe_bytes(
    pool: *mut DartEdgeAudioPool,
    options_json: *const c_char,
    input_ptr: *const u8,
    input_len: isize,
) -> i64 {
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return 0;
    }
    let options_json = unsafe { read_c_string(options_json) };
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing audio byte input.");
        return 0;
    };

    submit_audio_pool_job(
        unsafe { &*pool },
        NativeAudioPoolJob::ProbeBytes {
            options_json,
            input,
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_submit_convert_file(
    pool: *mut DartEdgeAudioPool,
    request_json: *const c_char,
) -> i64 {
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return 0;
    }
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing audio conversion request.");
        return 0;
    };

    submit_audio_pool_job(
        unsafe { &*pool },
        NativeAudioPoolJob::ConvertFile { request_json },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_submit_convert_bytes(
    pool: *mut DartEdgeAudioPool,
    request_json: *const c_char,
    input_ptr: *const u8,
    input_len: isize,
) -> i64 {
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return 0;
    }
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing audio conversion request.");
        return 0;
    };
    let Some(input) = (unsafe { read_bytes(input_ptr, input_len) }) else {
        set_last_error("Missing audio byte input.");
        return 0;
    };

    submit_audio_pool_job(
        unsafe { &*pool },
        NativeAudioPoolJob::ConvertBytes {
            request_json,
            input,
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_submit_concatenate_streams(
    pool: *mut DartEdgeAudioPool,
    request_json: *const c_char,
    inputs: *const NativeAudioStreamInput,
    input_count: isize,
) -> i64 {
    let inputs = match unsafe { take_audio_stream_inputs(inputs, input_count) } {
        Ok(inputs) => inputs,
        Err(error) => {
            set_last_error(error);
            return 0;
        }
    };
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return 0;
    }
    let Some(request_json) = (unsafe { read_c_string(request_json) }) else {
        set_last_error("Missing audio stream concatenation request.");
        return 0;
    };

    submit_audio_pool_job(
        unsafe { &*pool },
        NativeAudioPoolJob::ConcatenateStreams {
            request_json,
            inputs,
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_submit_pcm16_stream_finish(
    pool: *mut DartEdgeAudioPool,
    session: *mut DartEdgeAudioPcm16StreamSession,
) -> i64 {
    if session.is_null() {
        set_last_error("Missing PCM16 stream session.");
        return 0;
    }
    // This ABI adopts the session before validating the pool so ownership is
    // deterministic on every return path.
    let session = unsafe { Box::from_raw(session) };
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return 0;
    }
    submit_audio_pool_job(
        unsafe { &*pool },
        NativeAudioPoolJob::FinishPcm16Stream { session },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_take_file_result(
    pool: *mut DartEdgeAudioPool,
    job_id: i64,
) -> *mut c_char {
    let Some(result) = take_audio_pool_result(pool, job_id) else {
        return std::ptr::null_mut();
    };
    match result {
        NativeAudioPoolResult::FileJson(json) => {
            clear_last_error();
            c_string(json).into_raw()
        }
        NativeAudioPoolResult::ProbeJson(_)
        | NativeAudioPoolResult::ConvertedBytes { .. }
        | NativeAudioPoolResult::ConvertedStream { .. } => {
            set_last_error("Audio pool job result is not a file result.");
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_take_probe_result(
    pool: *mut DartEdgeAudioPool,
    job_id: i64,
) -> *mut c_char {
    let Some(result) = take_audio_pool_result(pool, job_id) else {
        return std::ptr::null_mut();
    };
    match result {
        NativeAudioPoolResult::ProbeJson(json) => {
            clear_last_error();
            c_string(json).into_raw()
        }
        NativeAudioPoolResult::FileJson(_)
        | NativeAudioPoolResult::ConvertedBytes { .. }
        | NativeAudioPoolResult::ConvertedStream { .. } => {
            set_last_error("Audio pool job result is not a probe result.");
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_take_convert_result(
    pool: *mut DartEdgeAudioPool,
    job_id: i64,
) -> *mut NativeAudioBytesResult {
    let Some(result) = take_audio_pool_result(pool, job_id) else {
        return std::ptr::null_mut();
    };
    match result {
        NativeAudioPoolResult::ConvertedBytes {
            bytes,
            waveform,
            result_json,
        } => match encode_bytes_result_json(bytes, waveform, result_json) {
            Ok(value) => {
                clear_last_error();
                value
            }
            Err(error) => {
                set_last_error(error);
                std::ptr::null_mut()
            }
        },
        NativeAudioPoolResult::FileJson(_)
        | NativeAudioPoolResult::ProbeJson(_)
        | NativeAudioPoolResult::ConvertedStream { .. } => {
            set_last_error("Audio pool job result is not a conversion result.");
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_take_stream_result(
    pool: *mut DartEdgeAudioPool,
    job_id: i64,
) -> *mut NativeAudioStreamResult {
    let Some(result) = take_audio_pool_result(pool, job_id) else {
        return std::ptr::null_mut();
    };
    match result {
        NativeAudioPoolResult::ConvertedStream {
            stream,
            content_length,
            result_json,
        } => {
            let Ok(content_length) = i64::try_from(content_length) else {
                set_last_error("Concatenated audio is too large for the native ABI.");
                return std::ptr::null_mut();
            };
            let result_json = c_string(result_json).into_raw();
            clear_last_error();
            Box::into_raw(Box::new(NativeAudioStreamResult {
                stream: stream.into_descriptor(),
                content_length,
                result_json,
            }))
        }
        NativeAudioPoolResult::FileJson(_)
        | NativeAudioPoolResult::ProbeJson(_)
        | NativeAudioPoolResult::ConvertedBytes { .. } => {
            set_last_error("Audio pool job result is not a stream result.");
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_pool_metrics(pool: *mut DartEdgeAudioPool) -> *mut c_char {
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return std::ptr::null_mut();
    }
    let metrics = unsafe { &*pool }.jobs.metrics();
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
pub extern "C" fn dart_edge_audio_pool_free(pool: *mut DartEdgeAudioPool) {
    if pool.is_null() {
        return;
    }
    drop(unsafe { Box::from_raw(pool) });
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_free_bytes_result(value: *mut NativeAudioBytesResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let value = Box::from_raw(value);
        free_owned_bytes(value.bytes);
        free_owned_bytes(value.waveform);
        if !value.result_json.is_null() {
            let _ = CString::from_raw(value.result_json);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_free_stream_result(value: *mut NativeAudioStreamResult) {
    if value.is_null() {
        return;
    }
    unsafe {
        let value = Box::from_raw(value);
        free_c_string(value.result_json);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_dispose_stream_result(value: *mut NativeAudioStreamResult) {
    if value.is_null() {
        return;
    }
    unsafe {
        let value = Box::from_raw(value);
        if let Some(cancel) = value.stream.cancel {
            cancel(value.stream.context);
        }
        if let Some(release) = value.stream.release {
            release(value.stream.context);
        }
        free_c_string(value.result_json);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_take_last_error() -> *mut c_char {
    LAST_ERROR
        .lock()
        .unwrap()
        .take()
        .map_or(std::ptr::null_mut(), CString::into_raw)
}

#[unsafe(no_mangle)]
pub extern "C" fn dart_edge_audio_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

fn probe_file(path: &str, mode: NativeAudioProbeMode) -> Result<NativeAudioMetadata, String> {
    let bytes = fs::read(path).map_err(|error| format!("Failed to read audio file: {error}"))?;
    let file_name = Path::new(path)
        .file_name()
        .and_then(|value| value.to_str())
        .map(ToOwned::to_owned);
    probe_audio(bytes, file_name.as_deref(), None, mode)
}

fn probe_bytes(
    bytes: Vec<u8>,
    file_name_hint: Option<&str>,
    mime_type_hint: Option<&str>,
    mode: NativeAudioProbeMode,
) -> Result<NativeAudioMetadata, String> {
    probe_audio(bytes, file_name_hint, mime_type_hint, mode)
}

fn probe_audio(
    bytes: Vec<u8>,
    file_name_hint: Option<&str>,
    mime_type_hint: Option<&str>,
    mode: NativeAudioProbeMode,
) -> Result<NativeAudioMetadata, String> {
    match mode {
        NativeAudioProbeMode::Full => {
            let decoded = decode_audio(bytes, file_name_hint, mime_type_hint)?;
            Ok(decoded.metadata())
        }
        NativeAudioProbeMode::Shallow => shallow_probe_audio(bytes, file_name_hint, mime_type_hint),
        NativeAudioProbeMode::Adaptive => {
            let metadata = shallow_probe_audio(bytes.clone(), file_name_hint, mime_type_hint)?;
            if metadata.duration_micros > 0 {
                Ok(metadata)
            } else {
                let decoded = decode_audio(bytes, file_name_hint, mime_type_hint)?;
                Ok(decoded.metadata())
            }
        }
    }
}

fn shallow_probe_audio(
    bytes: Vec<u8>,
    file_name_hint: Option<&str>,
    mime_type_hint: Option<&str>,
) -> Result<NativeAudioMetadata, String> {
    let mut tags = collect_riff_info_tags(&bytes);
    let mut hint = Hint::new();
    if let Some(extension) = file_name_hint
        .and_then(|value| Path::new(value).extension())
        .and_then(|value| value.to_str())
    {
        hint.with_extension(extension);
    }
    if let Some(mime_type_hint) = mime_type_hint {
        hint.mime_type(mime_type_hint);
    }

    let media_stream = MediaSourceStream::new(Box::new(Cursor::new(bytes)), Default::default());
    let mut format = get_probe()
        .probe(
            &hint,
            media_stream,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|error| format!("Failed to probe audio input: {error}"))?;
    tags.extend(collect_tags(&mut *format));

    let Some(track) = format
        .first_track_known_codec(TrackType::Audio)
        .or_else(|| format.first_track(TrackType::Audio))
    else {
        return Err("No supported audio track found.".to_string());
    };
    let Some(CodecParameters::Audio(codec_params)) = &track.codec_params else {
        return Err("No supported audio track found.".to_string());
    };

    Ok(metadata_from_track(
        track,
        codec_params,
        guess_container(file_name_hint, mime_type_hint),
        tags,
    ))
}

fn convert_file(
    request: NativeFileConversionRequest,
) -> Result<NativeFileConversionResult, String> {
    validate_sample_rate(request.target_sample_rate)?;
    request.target_format.validate()?;

    if !request.overwrite_existing && Path::new(&request.output_path).exists() {
        return Err("Output file already exists.".to_string());
    }

    let bytes = fs::read(&request.input_path)
        .map_err(|error| format!("Failed to read audio file: {error}"))?;
    let file_name = Path::new(&request.input_path)
        .file_name()
        .and_then(|value| value.to_str());
    let decoded = decode_audio(bytes, file_name, None)?;
    let converted = convert_audio(
        decoded,
        request.target_sample_rate,
        request.channel_layout,
        request.target_format,
    )?;
    let encoded = encode_audio(&converted)?;

    fs::write(&request.output_path, encoded.bytes)
        .map_err(|error| format!("Failed to write converted audio file: {error}"))?;

    Ok(NativeFileConversionResult {
        output_path: request.output_path,
        mime_type: encoded.mime_type.to_string(),
        file_extension: request.target_format.file_extension().to_string(),
        metadata: encoded.metadata,
    })
}

fn convert_bytes(
    bytes: Vec<u8>,
    request: NativeBytesConversionRequest,
) -> Result<*mut NativeAudioBytesResult, String> {
    let result = convert_bytes_payload(bytes, request)?;
    match result {
        NativeAudioPoolResult::ConvertedBytes {
            bytes,
            waveform,
            result_json,
        } => encode_bytes_result_json(bytes, waveform, result_json),
        NativeAudioPoolResult::FileJson(_)
        | NativeAudioPoolResult::ProbeJson(_)
        | NativeAudioPoolResult::ConvertedStream { .. } => {
            Err("Unexpected audio conversion result.".to_string())
        }
    }
}

fn convert_bytes_payload(
    bytes: Vec<u8>,
    request: NativeBytesConversionRequest,
) -> Result<NativeAudioPoolResult, String> {
    validate_sample_rate(request.target_sample_rate)?;
    request.target_format.validate()?;

    let decoded = decode_audio(
        bytes,
        request.file_name_hint.as_deref(),
        request.mime_type_hint.as_deref(),
    )?;
    let converted = convert_audio(
        decoded,
        request.target_sample_rate,
        request.channel_layout,
        request.target_format,
    )?;
    let (waveform_bytes, waveform) = match request.waveform {
        Some(spec) => {
            validate_waveform_spec(&spec)?;
            let waveform = generate_waveform(&converted, &spec)?;
            (waveform.bytes, Some(waveform.json))
        }
        None if request.waveform_only => {
            return Err("waveform is required when waveformOnly is true.".to_string());
        }
        None => (Vec::new(), None),
    };
    let encoded = if request.waveform_only {
        None
    } else {
        Some(encode_audio(&converted)?)
    };
    let result_json = NativeBytesConversionResultJson {
        mime_type: encoded
            .as_ref()
            .map_or_else(
                || request.target_format.mime_type(),
                |value| value.mime_type,
            )
            .to_string(),
        file_extension: request.target_format.file_extension().to_string(),
        metadata: encoded
            .as_ref()
            .map_or_else(|| converted.metadata(), |value| value.metadata.clone()),
        waveform,
    };
    let result_json = serde_json::to_string(&result_json)
        .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;

    Ok(NativeAudioPoolResult::ConvertedBytes {
        bytes: encoded.map_or_else(Vec::new, |value| value.bytes),
        waveform: waveform_bytes,
        result_json,
    })
}

fn concatenate_audio_streams(
    mut inputs: Vec<OwnedAudioStreamInput>,
    request: NativeStreamConcatenationRequest,
) -> Result<NativeAudioPoolResult, String> {
    validate_sample_rate(request.target_sample_rate)?;
    request.target_format.validate()?;
    let first_input = inputs
        .first_mut()
        .ok_or_else(|| "At least one native audio stream is required.".to_string())?;
    let first_bytes = read_native_stream_to_end(&mut first_input.stream)?;
    let first_decoded = decode_audio(
        first_bytes,
        first_input.file_name_hint.as_deref(),
        first_input.mime_type_hint.as_deref(),
    )?;
    let mut first = convert_audio(
        first_decoded,
        request.target_sample_rate,
        request.channel_layout,
        request.target_format,
    )?;
    let sample_rate = first.sample_rate;
    let channel_count = first.samples.len();
    if !matches!(
        request.target_format.output(),
        NativeAudioOutputSpec::WavPcm16 | NativeAudioOutputSpec::WavPcm24
    ) {
        for input in inputs.iter_mut().skip(1) {
            let bytes = read_native_stream_to_end(&mut input.stream)?;
            let decoded = decode_audio(
                bytes,
                input.file_name_hint.as_deref(),
                input.mime_type_hint.as_deref(),
            )?;
            let converted = convert_audio(
                decoded,
                request.target_sample_rate,
                request.channel_layout,
                request.target_format,
            )?;
            if converted.sample_rate != sample_rate || converted.samples.len() != channel_count {
                return Err(
                    "Converted audio streams have incompatible sample rates or channels."
                        .to_string(),
                );
            }
            for (target, source) in first.samples.iter_mut().zip(converted.samples) {
                target
                    .try_reserve_exact(source.len())
                    .map_err(|error| format!("Could not reserve concatenated audio: {error}"))?;
                target.extend(source);
            }
        }
        let encoded = encode_audio(&first)?;
        let content_length = encoded.bytes.len() as u64;
        let result_json = serde_json::to_string(&NativeBytesConversionResultJson {
            mime_type: encoded.mime_type.to_string(),
            file_extension: request.target_format.file_extension().to_string(),
            metadata: encoded.metadata,
            waveform: None,
        })
        .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
        return Ok(NativeAudioPoolResult::ConvertedStream {
            stream: OwnedNativeByteStream::new(native_memory_byte_stream(encoded.bytes)),
            content_length,
            result_json,
        });
    }
    let mut total_frame_count = first.samples.first().map_or(0usize, Vec::len);
    let mut output = Cursor::new(Vec::new());
    let spec = WavSpec {
        channels: channel_count as u16,
        sample_rate,
        bits_per_sample: request.target_format.pcm_bit_depth()?,
        sample_format: SampleFormat::Int,
    };

    {
        let mut writer = WavWriter::new(&mut output, spec)
            .map_err(|error| format!("Failed to create WAV stream output: {error}"))?;
        write_converted_audio(&mut writer, &first)?;

        for input in inputs.iter_mut().skip(1) {
            let bytes = read_native_stream_to_end(&mut input.stream)?;
            let decoded = decode_audio(
                bytes,
                input.file_name_hint.as_deref(),
                input.mime_type_hint.as_deref(),
            )?;
            let converted = convert_audio(
                decoded,
                request.target_sample_rate,
                request.channel_layout,
                request.target_format,
            )?;
            if converted.sample_rate != sample_rate || converted.samples.len() != channel_count {
                return Err(
                    "Converted audio streams have incompatible sample rates or channels."
                        .to_string(),
                );
            }
            total_frame_count = total_frame_count
                .saturating_add(converted.samples.first().map_or(0usize, Vec::len));
            write_converted_audio(&mut writer, &converted)?;
        }
        writer
            .finalize()
            .map_err(|error| format!("Failed to finalize WAV stream output: {error}"))?;
    }

    let content_length = output.get_ref().len() as u64;
    let bit_depth = u32::from(request.target_format.pcm_bit_depth()?);
    let bit_rate = (sample_rate as u64)
        .saturating_mul(channel_count as u64)
        .saturating_mul(bit_depth as u64)
        .try_into()
        .ok();
    let result_json = serde_json::to_string(&NativeBytesConversionResultJson {
        mime_type: "audio/wav".to_string(),
        file_extension: request.target_format.file_extension().to_string(),
        metadata: NativeAudioMetadata {
            duration_micros: duration_micros(total_frame_count, sample_rate),
            container: Some(request.target_format.container().to_string()),
            codec: Some(request.target_format.codec_name().to_string()),
            sample_rate: Some(sample_rate),
            channel_count: Some(channel_count as u32),
            bit_rate,
            bit_depth: Some(bit_depth),
            tags: BTreeMap::new(),
        },
        waveform: None,
    })
    .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;

    Ok(NativeAudioPoolResult::ConvertedStream {
        stream: OwnedNativeByteStream::new(native_memory_byte_stream(output.into_inner())),
        content_length,
        result_json,
    })
}

fn write_converted_audio<W: Write + Seek>(
    writer: &mut WavWriter<W>,
    audio: &ConvertedAudio,
) -> Result<(), String> {
    let frame_count = audio.samples.first().map_or(0usize, Vec::len);
    for frame_index in 0..frame_count {
        for channel in &audio.samples {
            match audio.target_format.output() {
                NativeAudioOutputSpec::WavPcm16 => writer
                    .write_sample(float_to_i16(channel[frame_index]))
                    .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                NativeAudioOutputSpec::WavPcm24 => writer
                    .write_sample(float_to_i24(channel[frame_index]))
                    .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                _ => return Err("Compressed output cannot use the WAV sample writer.".to_string()),
            }
        }
    }
    Ok(())
}

fn read_native_stream_to_end(stream: &mut OwnedNativeByteStream) -> Result<Vec<u8>, String> {
    if !stream.descriptor.is_valid() {
        return Err("Invalid native audio input stream descriptor.".to_string());
    }
    let next = stream
        .descriptor
        .next
        .ok_or_else(|| "Native audio input stream has no next callback.".to_string())?;
    let free_read = stream
        .descriptor
        .free_read
        .ok_or_else(|| "Native audio input stream has no result release callback.".to_string())?;
    let mut output = Vec::new();

    loop {
        let read_ptr = unsafe { next(stream.descriptor.context) };
        if read_ptr.is_null() {
            return Err("Native audio input stream returned a null result.".to_string());
        }
        let outcome = unsafe {
            let read = &*read_ptr;
            match read.status {
                NATIVE_BYTE_STREAM_READ_CHUNK => {
                    let bytes = read_native_bytes(NativeBytes {
                        ptr: read.bytes.ptr,
                        len: read.bytes.len,
                    })
                    .ok_or_else(|| {
                        "Native audio input stream returned invalid chunk bytes.".to_string()
                    });
                    bytes.map(|bytes| {
                        output.extend_from_slice(bytes);
                        false
                    })
                }
                NATIVE_BYTE_STREAM_READ_DONE => Ok(true),
                NATIVE_BYTE_STREAM_READ_CANCELED => {
                    Err("Native audio input stream was canceled.".to_string())
                }
                NATIVE_BYTE_STREAM_READ_ERROR => Err(read_native_string(read.error)
                    .unwrap_or_else(|| "Native audio input stream failed.".to_string())),
                status => Err(format!(
                    "Native audio input stream returned unknown status {status}."
                )),
            }
        };
        unsafe { free_read(read_ptr) };
        if outcome? {
            stream.mark_completed();
            return Ok(output);
        }
    }
}

const NATIVE_MEMORY_STREAM_CHUNK_SIZE: usize = 64 * 1024;

struct NativeMemoryStreamContext {
    bytes: Arc<Vec<u8>>,
    offset: Mutex<usize>,
    canceled: AtomicBool,
}

#[repr(C)]
struct NativeMemoryStreamRead {
    read: NativeByteStreamRead,
    _bytes: Option<Arc<Vec<u8>>>,
    _error: Option<CString>,
}

impl NativeMemoryStreamRead {
    fn chunk(owner: Arc<Vec<u8>>, start: usize, end: usize) -> Self {
        let view = NativeOwnedBytes {
            ptr: unsafe { owner.as_ptr().add(start) }.cast_mut(),
            len: (end - start) as isize,
        };
        Self {
            read: NativeByteStreamRead {
                status: NATIVE_BYTE_STREAM_READ_CHUNK,
                bytes: view,
                error: NativeBytes::empty(),
            },
            _bytes: Some(owner),
            _error: None,
        }
    }

    fn terminal(status: i32) -> Self {
        Self {
            read: NativeByteStreamRead {
                status,
                bytes: NativeOwnedBytes::empty(),
                error: NativeBytes::empty(),
            },
            _bytes: None,
            _error: None,
        }
    }

    fn error(error: impl Into<String>) -> Self {
        let error = c_string(error);
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
            _bytes: None,
            _error: Some(error),
        }
    }

    fn into_raw(self) -> *mut NativeByteStreamRead {
        Box::into_raw(Box::new(self)).cast::<NativeByteStreamRead>()
    }
}

fn native_memory_byte_stream(bytes: Vec<u8>) -> NativeByteStream {
    let context = Box::into_raw(Box::new(NativeMemoryStreamContext {
        bytes: Arc::new(bytes),
        offset: Mutex::new(0),
        canceled: AtomicBool::new(false),
    }));
    NativeByteStream {
        abi_version: NATIVE_BYTE_STREAM_ABI_VERSION,
        struct_size: std::mem::size_of::<NativeByteStream>(),
        context: context.cast::<c_void>(),
        next: Some(native_memory_stream_next),
        cancel: Some(native_memory_stream_cancel),
        free_read: Some(native_memory_stream_free_read),
        release: Some(native_memory_stream_release),
    }
}

unsafe extern "C" fn native_memory_stream_next(context: *mut c_void) -> *mut NativeByteStreamRead {
    let Some(context) = (unsafe { context.cast::<NativeMemoryStreamContext>().as_ref() }) else {
        return NativeMemoryStreamRead::error("Missing native WAV stream context.").into_raw();
    };
    if context.canceled.load(Ordering::Acquire) {
        return NativeMemoryStreamRead::terminal(NATIVE_BYTE_STREAM_READ_CANCELED).into_raw();
    }
    let mut offset = match context.offset.lock() {
        Ok(offset) => offset,
        Err(_) => {
            return NativeMemoryStreamRead::error("Native WAV stream offset lock was poisoned.")
                .into_raw();
        }
    };
    if *offset >= context.bytes.len() {
        return NativeMemoryStreamRead::terminal(NATIVE_BYTE_STREAM_READ_DONE).into_raw();
    }
    let start = *offset;
    let end = start
        .saturating_add(NATIVE_MEMORY_STREAM_CHUNK_SIZE)
        .min(context.bytes.len());
    *offset = end;
    NativeMemoryStreamRead::chunk(Arc::clone(&context.bytes), start, end).into_raw()
}

unsafe extern "C" fn native_memory_stream_cancel(context: *mut c_void) {
    if let Some(context) = unsafe { context.cast::<NativeMemoryStreamContext>().as_ref() } {
        context.canceled.store(true, Ordering::Release);
    }
}

unsafe extern "C" fn native_memory_stream_free_read(value: *mut NativeByteStreamRead) {
    if !value.is_null() {
        unsafe { drop(Box::from_raw(value.cast::<NativeMemoryStreamRead>())) };
    }
}

unsafe extern "C" fn native_memory_stream_release(context: *mut c_void) {
    if !context.is_null() {
        unsafe { drop(Box::from_raw(context.cast::<NativeMemoryStreamContext>())) };
    }
}

fn create_audio_pool_handler()
-> impl FnMut(NativeAudioPoolJob) -> Result<NativeAudioPoolResult, String> + Send {
    move |job| match job {
        NativeAudioPoolJob::ProbeFile { request_json } => {
            let request = serde_json::from_str::<NativeProbeFileRequest>(&request_json)
                .map_err(|error| format!("Invalid audio probe request: {error}"))?;
            let metadata = probe_file(&request.path, request.mode)?;
            let json = serde_json::to_string(&metadata)
                .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
            Ok(NativeAudioPoolResult::FileJson(json))
        }
        NativeAudioPoolJob::ProbeBytes {
            options_json,
            input,
        } => {
            let options = match options_json {
                Some(options_json) => {
                    serde_json::from_str::<NativeProbeBytesRequest>(&options_json)
                        .map_err(|error| format!("Invalid JSON payload: {error}"))?
                }
                None => NativeProbeBytesRequest {
                    file_name_hint: None,
                    mime_type_hint: None,
                    mode: NativeAudioProbeMode::Adaptive,
                },
            };
            let metadata = probe_bytes(
                input,
                options.file_name_hint.as_deref(),
                options.mime_type_hint.as_deref(),
                options.mode,
            )?;
            let json = serde_json::to_string(&metadata)
                .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
            Ok(NativeAudioPoolResult::ProbeJson(json))
        }
        NativeAudioPoolJob::ConvertFile { request_json } => {
            let request = serde_json::from_str::<NativeFileConversionRequest>(&request_json)
                .map_err(|error| format!("Invalid audio conversion request: {error}"))?;
            let result = convert_file(request)?;
            let json = serde_json::to_string(&result)
                .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
            Ok(NativeAudioPoolResult::FileJson(json))
        }
        NativeAudioPoolJob::ConvertBytes {
            request_json,
            input,
        } => {
            let request = serde_json::from_str::<NativeBytesConversionRequest>(&request_json)
                .map_err(|error| format!("Invalid audio conversion request: {error}"))?;
            convert_bytes_payload(input, request)
        }
        NativeAudioPoolJob::ConcatenateStreams {
            request_json,
            inputs,
        } => {
            let request = serde_json::from_str::<NativeStreamConcatenationRequest>(&request_json)
                .map_err(|error| {
                format!("Invalid audio stream concatenation request: {error}")
            })?;
            concatenate_audio_streams(inputs, request)
        }
        NativeAudioPoolJob::FinishPcm16Stream { session } => session.finish_pool_result(),
    }
}

fn submit_audio_pool_job(pool: &DartEdgeAudioPool, job: NativeAudioPoolJob) -> i64 {
    match pool.jobs.submit(job) {
        Ok(job_id) => {
            clear_last_error();
            job_id
        }
        Err(NativeJobSubmitError::QueueFull) => {
            set_last_error("Audio pool queue is full.");
            0
        }
        Err(NativeJobSubmitError::Closed) => {
            set_last_error("Audio pool is closed.");
            0
        }
    }
}

fn take_audio_pool_result(
    pool: *mut DartEdgeAudioPool,
    job_id: i64,
) -> Option<NativeAudioPoolResult> {
    if pool.is_null() {
        set_last_error("Missing audio pool.");
        return None;
    }
    match unsafe { &*pool }.jobs.take_result(job_id) {
        Some(Ok(result)) => Some(result),
        Some(Err(error)) => {
            set_last_error(error);
            None
        }
        None => {
            set_last_error("Audio pool job is not ready.");
            None
        }
    }
}

fn decode_audio(
    bytes: Vec<u8>,
    file_name_hint: Option<&str>,
    mime_type_hint: Option<&str>,
) -> Result<DecodedAudio, String> {
    let mut hint = Hint::new();
    if let Some(extension) = file_name_hint
        .and_then(|value| Path::new(value).extension())
        .and_then(|value| value.to_str())
    {
        hint.with_extension(extension);
    }
    if let Some(mime_type_hint) = mime_type_hint {
        hint.mime_type(mime_type_hint);
    }

    let mut tags = collect_riff_info_tags(&bytes);
    let media_stream = MediaSourceStream::new(Box::new(Cursor::new(bytes)), Default::default());
    let mut format = get_probe()
        .probe(
            &hint,
            media_stream,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|error| format!("Failed to probe audio input: {error}"))?;
    tags.extend(collect_tags(&mut *format));

    let (track_id, codec_params) = {
        let Some(track) = format
            .first_track_known_codec(TrackType::Audio)
            .or_else(|| format.first_track(TrackType::Audio))
        else {
            return Err("No supported audio track found.".to_string());
        };
        let Some(CodecParameters::Audio(codec_params)) = &track.codec_params else {
            return Err("No supported audio track found.".to_string());
        };

        (track.id, codec_params.clone())
    };

    let mut decoder = get_codecs()
        .make_audio_decoder(&codec_params, &AudioDecoderOptions::default())
        .map_err(|error| format!("Failed to create audio decoder: {error}"))?;

    let mut sample_rate = codec_params.sample_rate.unwrap_or(0);
    let mut channel_count = codec_params
        .channels
        .map(|channels| channels.count())
        .unwrap_or(0);
    let mut samples = if channel_count == 0 {
        Vec::new()
    } else {
        vec![Vec::new(); channel_count]
    };
    let bit_depth = codec_params.bits_per_sample;
    tags.extend(collect_tags(&mut *format));

    loop {
        let packet = match format.next_packet() {
            Ok(Some(packet)) => packet,
            Ok(None) => break,
            Err(SymphoniaError::IoError(error))
                if error.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                break;
            }
            Err(SymphoniaError::ResetRequired) => {
                return Err("Unsupported mid-stream format reset.".to_string());
            }
            Err(error) => {
                return Err(format!("Failed to read audio packets: {error}"));
            }
        };

        if packet.track_id != track_id {
            continue;
        }

        let decoded = decoder
            .decode(&packet)
            .map_err(|error| format!("Failed to decode audio packet: {error}"))?;
        let spec = decoded.spec();

        if sample_rate == 0 {
            sample_rate = spec.rate();
        }

        let decoded_channels = spec.channels().count();
        if channel_count == 0 {
            channel_count = decoded_channels;
            samples = vec![Vec::new(); channel_count];
        } else if channel_count != decoded_channels {
            return Err("Audio stream changed channel count during decode.".to_string());
        }

        let mut interleaved = Vec::with_capacity(decoded.samples_interleaved());
        decoded.copy_to_vec_interleaved::<f32>(&mut interleaved);

        for frame in interleaved.chunks(channel_count) {
            for (index, sample) in frame.iter().enumerate() {
                samples[index].push(*sample);
            }
        }
    }

    if sample_rate == 0 || samples.is_empty() || samples[0].is_empty() {
        return Err("No decodable audio frames found.".to_string());
    }

    tags.extend(collect_tags(&mut *format));

    Ok(DecodedAudio {
        samples,
        sample_rate,
        container: guess_container(file_name_hint, mime_type_hint),
        codec: guess_codec_name(codec_params.codec),
        bit_rate: None,
        bit_depth,
        tags,
    })
}

fn convert_audio(
    decoded: DecodedAudio,
    target_sample_rate: Option<u32>,
    channel_layout: NativeAudioChannelLayout,
    target_format: NativeAudioTargetFormat,
) -> Result<ConvertedAudio, String> {
    let remixed = remix_channels(decoded.samples, channel_layout)?;
    let sample_rate = target_sample_rate.unwrap_or(decoded.sample_rate);
    let samples = if sample_rate == decoded.sample_rate {
        remixed
    } else {
        resample(remixed, decoded.sample_rate, sample_rate)?
    };

    Ok(ConvertedAudio {
        samples,
        sample_rate,
        target_format,
    })
}

fn remix_channels(
    samples: Vec<Vec<f32>>,
    channel_layout: NativeAudioChannelLayout,
) -> Result<Vec<Vec<f32>>, String> {
    if samples.is_empty() {
        return Err("Audio input does not contain any channels.".to_string());
    }

    let frame_count = samples[0].len();
    if samples.iter().any(|channel| channel.len() != frame_count) {
        return Err("Audio channel buffers are misaligned.".to_string());
    }

    let remixed = match channel_layout {
        NativeAudioChannelLayout::KeepSource => samples,
        NativeAudioChannelLayout::Mono => {
            if samples.len() == 1 {
                samples
            } else {
                let mut mono = Vec::new();
                mono.try_reserve_exact(frame_count)
                    .map_err(|error| format!("Could not reserve mono audio output: {error}"))?;
                for frame_index in 0..frame_count {
                    let total: f32 = samples.iter().map(|channel| channel[frame_index]).sum();
                    mono.push(total / samples.len() as f32);
                }
                vec![mono]
            }
        }
        NativeAudioChannelLayout::Stereo => {
            if samples.len() == 2 {
                samples
            } else if samples.len() == 1 {
                let source = samples.into_iter().next().expect("one channel");
                let mut duplicate = Vec::new();
                duplicate
                    .try_reserve_exact(frame_count)
                    .map_err(|error| format!("Could not reserve stereo audio output: {error}"))?;
                duplicate.extend_from_slice(&source);
                vec![source, duplicate]
            } else {
                let mut left = Vec::new();
                let mut right = Vec::new();
                left.try_reserve_exact(frame_count).map_err(|error| {
                    format!("Could not reserve left-channel audio output: {error}")
                })?;
                right.try_reserve_exact(frame_count).map_err(|error| {
                    format!("Could not reserve right-channel audio output: {error}")
                })?;

                for frame_index in 0..frame_count {
                    let mut left_total = 0.0f32;
                    let mut left_count = 0usize;
                    let mut right_total = 0.0f32;
                    let mut right_count = 0usize;

                    for (channel_index, channel) in samples.iter().enumerate() {
                        if channel_index % 2 == 0 {
                            left_total += channel[frame_index];
                            left_count += 1;
                        } else {
                            right_total += channel[frame_index];
                            right_count += 1;
                        }
                    }

                    left.push(left_total / left_count as f32);
                    right.push(if right_count == 0 {
                        left[left.len() - 1]
                    } else {
                        right_total / right_count as f32
                    });
                }

                vec![left, right]
            }
        }
    };

    Ok(remixed)
}

fn resample(
    samples: Vec<Vec<f32>>,
    input_rate: u32,
    output_rate: u32,
) -> Result<Vec<Vec<f32>>, String> {
    if input_rate == output_rate {
        return Ok(samples);
    }
    if samples.is_empty() || samples[0].is_empty() {
        return Err("Audio input does not contain any frames to resample.".to_string());
    }

    let mut resampler = Async::<f32>::new_poly(
        output_rate as f64 / input_rate as f64,
        1.0,
        PolynomialDegree::Septic,
        samples[0].len(),
        samples.len(),
        FixedAsync::Input,
    )
    .map_err(|error| format!("Failed to create audio resampler: {error}"))?;

    let input = SequentialSliceOfVecs::new(&samples, samples.len(), samples[0].len())
        .map_err(|error| format!("Failed to prepare audio resampler input: {error}"))?;
    let output = resampler
        .process(&input, 0, None)
        .map_err(|error| format!("Failed to resample audio: {error}"))?;

    let channel_count = samples.len();
    let output = output.take_data();
    let output_frame_count = output.len() / channel_count;
    let mut resampled = Vec::new();
    resampled
        .try_reserve_exact(channel_count)
        .map_err(|error| format!("Could not reserve resampled audio channels: {error}"))?;
    for _ in 0..channel_count {
        let mut channel = Vec::new();
        channel
            .try_reserve_exact(output_frame_count)
            .map_err(|error| format!("Could not reserve resampled audio output: {error}"))?;
        resampled.push(channel);
    }
    for frame in output.chunks(channel_count) {
        for (index, sample) in frame.iter().enumerate() {
            resampled[index].push(*sample);
        }
    }
    Ok(resampled)
}

fn encode_wav(audio: &ConvertedAudio) -> Result<Vec<u8>, String> {
    if audio.samples.is_empty() || audio.samples[0].is_empty() {
        return Err("Audio conversion did not produce any output samples.".to_string());
    }

    let frame_count = audio.samples[0].len();
    let spec = WavSpec {
        channels: audio.samples.len() as u16,
        sample_rate: audio.sample_rate,
        bits_per_sample: audio.target_format.pcm_bit_depth()?,
        sample_format: SampleFormat::Int,
    };

    let bytes_per_sample = usize::from(audio.target_format.pcm_bit_depth()?).div_ceil(8);
    let expected_bytes = frame_count
        .checked_mul(audio.samples.len())
        .and_then(|value| value.checked_mul(bytes_per_sample))
        .and_then(|value| value.checked_add(64))
        .ok_or_else(|| "WAV output size overflowed.".to_string())?;
    let mut wav = Vec::new();
    wav.try_reserve_exact(expected_bytes)
        .map_err(|error| format!("Could not reserve WAV output: {error}"))?;
    let mut cursor = Cursor::new(wav);
    {
        let mut writer = WavWriter::new(&mut cursor, spec)
            .map_err(|error| format!("Failed to create WAV writer: {error}"))?;

        for frame_index in 0..frame_count {
            for channel in &audio.samples {
                match audio.target_format.output() {
                    NativeAudioOutputSpec::WavPcm16 => writer
                        .write_sample(float_to_i16(channel[frame_index]))
                        .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                    NativeAudioOutputSpec::WavPcm24 => writer
                        .write_sample(float_to_i24(channel[frame_index]))
                        .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                    _ => {
                        return Err("Compressed output cannot use the WAV encoder.".to_string());
                    }
                }
            }
        }

        writer
            .finalize()
            .map_err(|error| format!("Failed to finalize WAV output: {error}"))?;
    }

    Ok(cursor.into_inner())
}

struct EncodedWaveform {
    bytes: Vec<u8>,
    json: NativeWaveformResultJson,
}

struct WaveformAccumulator {
    sample_rate: u32,
    interval_micros: u64,
    frames_seen: u64,
    bucket_index: u64,
    current_min: i8,
    current_max: i8,
    has_current: bool,
    base_peaks: Vec<i8>,
}

impl DartEdgeAudioPcm16StreamSession {
    fn add_pcm16(&mut self, input: &[u8]) -> Result<(), String> {
        let bytes_per_frame = usize::try_from(self.input_channel_count)
            .ok()
            .and_then(|channels| channels.checked_mul(2))
            .ok_or_else(|| "PCM16 stream frame size is too large.".to_string())?;
        if input.len() % bytes_per_frame != 0 {
            return Err(format!(
                "PCM16 stream input must contain complete {}-channel frames.",
                self.input_channel_count
            ));
        }
        let next_length = self
            .input
            .len()
            .checked_add(input.len())
            .ok_or_else(|| "PCM16 stream input length overflowed.".to_string())?;
        if next_length > self.max_buffered_bytes {
            return Err(format!(
                "PCM16 stream exceeded its {} byte buffer limit.",
                self.max_buffered_bytes
            ));
        }
        self.input
            .try_reserve_exact(input.len())
            .map_err(|error| format!("PCM16 stream could not reserve native memory: {error}"))?;
        self.input.extend_from_slice(input);
        Ok(())
    }

    fn finish(self) -> Result<*mut NativeAudioStreamResult, String> {
        let NativeAudioPoolResult::ConvertedStream {
            stream,
            content_length,
            result_json,
        } = self.finish_pool_result()?
        else {
            unreachable!("PCM16 finish must produce a stream result")
        };
        let content_length = i64::try_from(content_length)
            .map_err(|_| "PCM16 stream output is too large for the native ABI.".to_string())?;
        Ok(Box::into_raw(Box::new(NativeAudioStreamResult {
            stream: stream.into_descriptor(),
            content_length,
            result_json: c_string(result_json).into_raw(),
        })))
    }

    fn finish_pool_result(self) -> Result<NativeAudioPoolResult, String> {
        if self.input.is_empty() {
            return Err("PCM16 stream does not contain audio.".to_string());
        }
        let decoded = decode_pcm16_le(
            self.input,
            self.input_sample_rate_hz,
            self.input_channel_count,
        )?;
        let converted = convert_audio(
            decoded,
            self.target_sample_rate,
            self.channel_layout,
            self.target_format,
        )?;
        let encoded = encode_audio(&converted)?;
        let content_length = encoded.bytes.len() as u64;
        let result_json = serde_json::to_string(&NativeBytesConversionResultJson {
            mime_type: encoded.mime_type.to_string(),
            file_extension: self.target_format.file_extension().to_string(),
            metadata: encoded.metadata,
            waveform: None,
        })
        .map_err(|error| format!("Failed to encode PCM16 stream result: {error}"))?;

        Ok(NativeAudioPoolResult::ConvertedStream {
            stream: OwnedNativeByteStream::new(native_memory_byte_stream(encoded.bytes)),
            content_length,
            result_json,
        })
    }
}

fn validate_pcm16_stream_request(request: &NativePcm16StreamRequest) -> Result<(), String> {
    validate_sample_rate(Some(request.input_sample_rate_hz))?;
    validate_sample_rate(request.target_sample_rate)?;
    request.target_format.validate()?;
    if request.input_channel_count == 0 || request.input_channel_count > 32 {
        return Err("PCM16 stream inputChannelCount must be between 1 and 32.".to_string());
    }
    if request.max_buffered_bytes == 0 {
        return Err("PCM16 stream maxBufferedBytes must be at least 1.".to_string());
    }
    Ok(())
}

fn decode_pcm16_le(
    input: Vec<u8>,
    sample_rate: u32,
    channel_count: u32,
) -> Result<DecodedAudio, String> {
    let channel_count = usize::try_from(channel_count)
        .map_err(|_| "PCM16 stream channel count is too large.".to_string())?;
    let bytes_per_frame = channel_count
        .checked_mul(2)
        .ok_or_else(|| "PCM16 stream frame size is too large.".to_string())?;
    if input.len() % bytes_per_frame != 0 {
        return Err("PCM16 stream ended with an incomplete frame.".to_string());
    }

    let frame_count = input.len() / bytes_per_frame;
    let mut samples = Vec::new();
    samples
        .try_reserve_exact(channel_count)
        .map_err(|error| format!("Could not reserve PCM channel buffers: {error}"))?;
    for _ in 0..channel_count {
        let mut channel = Vec::new();
        channel
            .try_reserve_exact(frame_count)
            .map_err(|error| format!("Could not reserve decoded PCM samples: {error}"))?;
        samples.push(channel);
    }
    for frame in input.chunks_exact(bytes_per_frame) {
        for (channel_index, sample_bytes) in frame.chunks_exact(2).enumerate() {
            let sample = i16::from_le_bytes([sample_bytes[0], sample_bytes[1]]);
            samples[channel_index].push(f32::from(sample) / 32768.0);
        }
    }

    Ok(DecodedAudio {
        samples,
        sample_rate,
        container: None,
        codec: Some("pcm_s16le".to_string()),
        bit_rate: sample_rate
            .checked_mul(channel_count as u32)
            .and_then(|value| value.checked_mul(16)),
        bit_depth: Some(16),
        tags: BTreeMap::new(),
    })
}

impl DartEdgeAudioWaveformSession {
    fn add_pcm16(&mut self, input: &[u8]) -> Result<(), String> {
        let bytes_per_frame = usize::try_from(self.channel_count)
            .ok()
            .and_then(|channels| channels.checked_mul(2))
            .ok_or_else(|| "Streaming waveform frame size is too large.".to_string())?;
        if input.len() % bytes_per_frame != 0 {
            return Err(format!(
                "Streaming PCM16 input must contain complete {}-channel frames.",
                self.channel_count
            ));
        }
        let accumulator = self
            .accumulator
            .as_mut()
            .ok_or_else(|| "Streaming waveform session is already finished.".to_string())?;

        for frame in input.chunks_exact(bytes_per_frame) {
            let mut visualization_sample = 0.0f32;
            for sample_bytes in frame.chunks_exact(2) {
                let sample = i16::from_le_bytes([sample_bytes[0], sample_bytes[1]]);
                visualization_sample += f32::from(sample) / 32768.0;
            }
            accumulator.observe(visualization_sample / self.channel_count as f32);
            self.frame_count = self
                .frame_count
                .checked_add(1)
                .ok_or_else(|| "Streaming waveform frame count overflowed.".to_string())?;
        }
        Ok(())
    }

    fn finish(&mut self) -> Result<*mut NativeAudioBytesResult, String> {
        let accumulator = self
            .accumulator
            .take()
            .ok_or_else(|| "Streaming waveform session is already finished.".to_string())?;
        let waveform = accumulator.finish(&self.spec)?;
        let result_json = serde_json::to_string(&NativeStreamingWaveformResultJson {
            sample_rate_hz: self.sample_rate_hz,
            channel_count: self.channel_count,
            frame_count: self.frame_count,
            waveform: waveform.json,
        })
        .map_err(|error| format!("Failed to encode streaming waveform result: {error}"))?;
        encode_bytes_result_json(Vec::new(), waveform.bytes, result_json)
    }
}

impl WaveformAccumulator {
    fn new(sample_rate: u32, interval_micros: u64) -> Self {
        Self {
            sample_rate,
            interval_micros,
            frames_seen: 0,
            bucket_index: 0,
            current_min: 0,
            current_max: 0,
            has_current: false,
            base_peaks: Vec::new(),
        }
    }

    fn observe(&mut self, sample: f32) {
        let peak = float_to_waveform_i8(sample);
        if self.has_current {
            self.current_min = self.current_min.min(peak);
            self.current_max = self.current_max.max(peak);
        } else {
            self.current_min = peak;
            self.current_max = peak;
            self.has_current = true;
        }
        self.frames_seen += 1;
        if u128::from(self.frames_seen) * 1_000_000
            >= u128::from(self.bucket_index + 1)
                * u128::from(self.sample_rate)
                * u128::from(self.interval_micros)
        {
            self.flush();
        }
    }

    fn flush(&mut self) {
        if !self.has_current {
            return;
        }
        self.base_peaks.push(self.current_min);
        self.base_peaks.push(self.current_max);
        self.bucket_index += 1;
        self.has_current = false;
    }

    fn finish(mut self, spec: &NativeWaveformSpec) -> Result<EncodedWaveform, String> {
        self.flush();
        let mut bytes = Vec::new();
        let mut levels = Vec::with_capacity(spec.level_factors.len());
        for &factor in &spec.level_factors {
            let level = aggregate_waveform(&self.base_peaks, factor as usize);
            let byte_offset = bytes.len();
            bytes.extend(level.into_iter().map(|value| value as u8));
            let byte_length = bytes.len() - byte_offset;
            levels.push(NativeWaveformLevelJson {
                factor,
                interval_micros: spec
                    .base_interval_micros
                    .checked_mul(u64::from(factor))
                    .ok_or_else(|| "waveform interval is too large.".to_string())?,
                byte_offset,
                byte_length,
            });
        }
        Ok(EncodedWaveform {
            bytes,
            json: NativeWaveformResultJson {
                base_interval_micros: spec.base_interval_micros,
                levels,
            },
        })
    }
}

fn encode_wav_with_waveform(
    audio: &ConvertedAudio,
    waveform_spec: &NativeWaveformSpec,
) -> Result<(Vec<u8>, EncodedWaveform), String> {
    if audio.samples.is_empty() || audio.samples[0].is_empty() {
        return Err("Audio conversion did not produce any output samples.".to_string());
    }
    let frame_count = audio.samples[0].len();
    let spec = WavSpec {
        channels: audio.samples.len() as u16,
        sample_rate: audio.sample_rate,
        bits_per_sample: audio.target_format.pcm_bit_depth()?,
        sample_format: SampleFormat::Int,
    };
    let mut waveform =
        WaveformAccumulator::new(audio.sample_rate, waveform_spec.base_interval_micros);
    let mut cursor = Cursor::new(Vec::new());
    {
        let mut writer = WavWriter::new(&mut cursor, spec)
            .map_err(|error| format!("Failed to create WAV writer: {error}"))?;
        for frame_index in 0..frame_count {
            let mut visualization_sample = 0.0f32;
            for channel in &audio.samples {
                let sample = channel[frame_index];
                visualization_sample += sample;
                match audio.target_format.output() {
                    NativeAudioOutputSpec::WavPcm16 => writer
                        .write_sample(float_to_i16(sample))
                        .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                    NativeAudioOutputSpec::WavPcm24 => writer
                        .write_sample(float_to_i24(sample))
                        .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                    _ => {
                        return Err("Compressed output cannot use the WAV encoder.".to_string());
                    }
                }
            }
            waveform.observe(visualization_sample / audio.samples.len() as f32);
        }
        writer
            .finalize()
            .map_err(|error| format!("Failed to finalize WAV output: {error}"))?;
    }
    Ok((cursor.into_inner(), waveform.finish(waveform_spec)?))
}

fn generate_waveform(
    audio: &ConvertedAudio,
    waveform_spec: &NativeWaveformSpec,
) -> Result<EncodedWaveform, String> {
    if audio.samples.is_empty() || audio.samples[0].is_empty() {
        return Err("Audio conversion did not produce any output samples.".to_string());
    }
    let frame_count = audio.samples[0].len();
    let mut waveform =
        WaveformAccumulator::new(audio.sample_rate, waveform_spec.base_interval_micros);
    for frame_index in 0..frame_count {
        let visualization_sample = audio
            .samples
            .iter()
            .map(|channel| channel[frame_index])
            .sum::<f32>()
            / audio.samples.len() as f32;
        waveform.observe(visualization_sample);
    }
    waveform.finish(waveform_spec)
}

fn aggregate_waveform(base: &[i8], factor: usize) -> Vec<i8> {
    if factor == 1 {
        return base.to_vec();
    }
    let mut output = Vec::with_capacity(base.len().div_ceil(factor));
    for pairs in base.chunks(factor * 2) {
        let mut minimum = i8::MAX;
        let mut maximum = i8::MIN;
        for pair in pairs.chunks_exact(2) {
            minimum = minimum.min(pair[0]);
            maximum = maximum.max(pair[1]);
        }
        output.push(minimum);
        output.push(maximum);
    }
    output
}

fn float_to_waveform_i8(sample: f32) -> i8 {
    (sample.clamp(-1.0, 1.0) * 127.0).round() as i8
}

fn collect_tags(format: &mut dyn FormatReader) -> BTreeMap<String, String> {
    let mut metadata = format.metadata();
    let revision = metadata.skip_to_latest();
    collect_metadata_tags(revision)
}

fn collect_riff_info_tags(bytes: &[u8]) -> BTreeMap<String, String> {
    let mut tags = BTreeMap::new();
    if bytes.len() < 12 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return tags;
    }

    let mut offset = 12usize;
    while offset + 8 <= bytes.len() {
        let chunk_id = &bytes[offset..offset + 4];
        let chunk_len = read_le_u32(bytes, offset + 4) as usize;
        let payload_offset = offset + 8;
        let payload_end = payload_offset.saturating_add(chunk_len);
        if payload_end > bytes.len() {
            break;
        }

        if chunk_id == b"LIST"
            && chunk_len >= 4
            && &bytes[payload_offset..payload_offset + 4] == b"INFO"
        {
            collect_riff_info_list_tags(&mut tags, &bytes[payload_offset + 4..payload_end]);
        }

        offset = payload_end + (chunk_len & 1);
    }

    tags
}

fn collect_riff_info_list_tags(tags: &mut BTreeMap<String, String>, bytes: &[u8]) {
    let mut offset = 0usize;
    while offset + 8 <= bytes.len() {
        let tag_id = std::str::from_utf8(&bytes[offset..offset + 4]).unwrap_or_default();
        let tag_len = read_le_u32(bytes, offset + 4) as usize;
        let value_offset = offset + 8;
        let value_end = value_offset.saturating_add(tag_len);
        if value_end > bytes.len() {
            break;
        }

        let key = normalize_raw_tag_key(tag_id);
        let value = String::from_utf8_lossy(&bytes[value_offset..value_end])
            .trim_matches(char::from(0))
            .trim()
            .to_string();
        if !key.is_empty() && !value.is_empty() {
            tags.entry(key).or_insert(value);
        }

        offset = value_end + (tag_len & 1);
    }
}

fn read_le_u32(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes([
        bytes[offset],
        bytes[offset + 1],
        bytes[offset + 2],
        bytes[offset + 3],
    ])
}

fn collect_metadata_tags(revision: Option<&MetadataRevision>) -> BTreeMap<String, String> {
    let mut tags = BTreeMap::new();
    if let Some(revision) = revision {
        collect_tag_list(&mut tags, &revision.media.tags);
        for track in &revision.per_track {
            collect_tag_list(&mut tags, &track.metadata.tags);
        }
    }

    tags
}

fn collect_tag_list(tags: &mut BTreeMap<String, String>, source: &[Tag]) {
    for tag in source {
        let key = tag
            .std
            .as_ref()
            .and_then(standard_tag_name)
            .map(ToOwned::to_owned)
            .unwrap_or_else(|| normalize_raw_tag_key(&tag.raw.key));
        let value = tag.raw.value.to_string();
        let value = value.trim_matches(char::from(0)).trim().to_string();
        if key.is_empty() || value.trim().is_empty() {
            continue;
        }
        tags.entry(key).or_insert(value);
    }
}

fn normalize_raw_tag_key(value: &str) -> String {
    match value.trim().to_ascii_lowercase().as_str() {
        "inam" | "tit2" | "title" => "title".to_string(),
        "iart" | "tpe1" | "artist" => "artist".to_string(),
        "iprd" | "talb" | "album" => "album".to_string(),
        other => other.to_string(),
    }
}

fn standard_tag_name(key: &StandardTag) -> Option<&'static str> {
    match key {
        StandardTag::TrackTitle(_) => Some("title"),
        StandardTag::Artist(_) => Some("artist"),
        StandardTag::Album(_) => Some("album"),
        StandardTag::AlbumArtist(_) => Some("albumArtist"),
        StandardTag::Genre(_) => Some("genre"),
        StandardTag::Comment(_) => Some("comment"),
        StandardTag::Composer(_) => Some("composer"),
        StandardTag::TrackNumber(_) => Some("trackNumber"),
        StandardTag::TrackTotal(_) => Some("trackTotal"),
        StandardTag::DiscNumber(_) => Some("discNumber"),
        StandardTag::DiscTotal(_) => Some("discTotal"),
        StandardTag::RecordingDate(_)
        | StandardTag::OriginalReleaseDate(_)
        | StandardTag::ReleaseDate(_) => Some("date"),
        _ => None,
    }
}

fn guess_container(file_name_hint: Option<&str>, mime_type_hint: Option<&str>) -> Option<String> {
    file_name_hint
        .and_then(|value| {
            Path::new(value)
                .extension()
                .and_then(|value| value.to_str())
        })
        .map(normalize_container_name)
        .or_else(|| mime_type_hint.and_then(normalize_container_from_mime))
}

fn normalize_container_name(value: &str) -> String {
    match value.to_ascii_lowercase().as_str() {
        "aac" | "adts" => "aac".to_string(),
        "m4a" | "mp4" => "m4a".to_string(),
        "wav" | "wave" => "wav".to_string(),
        "mp3" => "mp3".to_string(),
        "flac" => "flac".to_string(),
        "oga" | "ogg" => "ogg".to_string(),
        other => other.to_string(),
    }
}

fn normalize_container_from_mime(value: &str) -> Option<String> {
    let mime = value.to_ascii_lowercase();
    if mime.contains("mp4") || mime.contains("m4a") {
        Some("m4a".to_string())
    } else if mime.contains("aac") {
        Some("aac".to_string())
    } else if mime.contains("mpeg") || mime.contains("mp3") {
        Some("mp3".to_string())
    } else if mime.contains("flac") {
        Some("flac".to_string())
    } else if mime.contains("ogg") {
        Some("ogg".to_string())
    } else if mime.contains("wav") || mime.contains("wave") {
        Some("wav".to_string())
    } else {
        None
    }
}

fn guess_codec_name(codec: AudioCodecId) -> Option<String> {
    match codec {
        CODEC_ID_AAC => Some("aac".to_string()),
        CODEC_ID_MP3 => Some("mp3".to_string()),
        CODEC_ID_FLAC => Some("flac".to_string()),
        CODEC_ID_VORBIS => Some("vorbis".to_string()),
        CODEC_ID_PCM_S16LE | CODEC_ID_PCM_U16LE => Some("pcm_s16le".to_string()),
        CODEC_ID_PCM_S24LE | CODEC_ID_PCM_U24LE => Some("pcm_s24le".to_string()),
        CODEC_ID_PCM_S32LE | CODEC_ID_PCM_U32LE => Some("pcm_s32le".to_string()),
        CODEC_ID_PCM_F32LE => Some("pcm_f32le".to_string()),
        CODEC_ID_PCM_F64LE => Some("pcm_f64le".to_string()),
        CODEC_ID_NULL_AUDIO => None,
        _ => Some(format!("{codec:?}").to_ascii_lowercase()),
    }
}

fn validate_sample_rate(sample_rate: Option<u32>) -> Result<(), String> {
    if matches!(sample_rate, Some(0)) {
        return Err("targetSampleRate must be at least 1.".to_string());
    }
    Ok(())
}

fn validate_waveform_spec(spec: &NativeWaveformSpec) -> Result<(), String> {
    if spec.base_interval_micros == 0 {
        return Err("waveform.baseIntervalMicros must be at least 1.".to_string());
    }
    if spec.level_factors.first() != Some(&1) {
        return Err("waveform.levelFactors must start with 1.".to_string());
    }
    let mut previous = 0;
    for &factor in &spec.level_factors {
        if factor <= previous {
            return Err(
                "waveform.levelFactors must be unique, positive, and increasing.".to_string(),
            );
        }
        spec.base_interval_micros
            .checked_mul(u64::from(factor))
            .ok_or_else(|| "waveform interval is too large.".to_string())?;
        previous = factor;
    }
    Ok(())
}

fn encode_json_string<T: Serialize>(value: &T) -> Result<*mut c_char, String> {
    let json = serde_json::to_string(value)
        .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
    Ok(c_string(json).into_raw())
}

fn encode_bytes_result_json(
    bytes: Vec<u8>,
    waveform: Vec<u8>,
    result_json: String,
) -> Result<*mut NativeAudioBytesResult, String> {
    let result_json =
        CString::new(result_json).map_err(|error| format!("Failed to encode C string: {error}"))?;
    let native_bytes = into_native_owned_bytes(bytes);
    let native_waveform = into_native_owned_bytes(waveform);

    Ok(Box::into_raw(Box::new(NativeAudioBytesResult {
        bytes: native_bytes,
        waveform: native_waveform,
        result_json: result_json.into_raw(),
    })))
}

fn c_string(value: impl Into<String>) -> CString {
    let sanitized = value.into().replace('\0', " ");
    CString::new(sanitized).unwrap_or_else(|_| {
        CString::new("dart_edge_audio native call failed.").expect("valid fallback error")
    })
}

unsafe fn free_c_string(value: *mut c_char) {
    if !value.is_null() {
        unsafe { drop(CString::from_raw(value)) };
    }
}

fn metadata_from_track(
    track: &Track,
    codec_params: &symphonia::core::codecs::audio::AudioCodecParameters,
    container: Option<String>,
    tags: BTreeMap<String, String>,
) -> NativeAudioMetadata {
    let duration_micros = track_duration_micros(track, codec_params);
    NativeAudioMetadata {
        duration_micros,
        container,
        codec: guess_codec_name(codec_params.codec),
        sample_rate: codec_params.sample_rate,
        channel_count: codec_params
            .channels
            .as_ref()
            .map(|channels| channels.count() as u32),
        bit_rate: None,
        bit_depth: codec_params.bits_per_sample,
        tags,
    }
}

fn track_duration_micros(
    track: &Track,
    codec_params: &symphonia::core::codecs::audio::AudioCodecParameters,
) -> u64 {
    if let (Some(time_base), Some(duration)) = (track.time_base, track.duration) {
        if let Ok(timestamp) = Timestamp::try_from(duration.get()) {
            if let Some(time) = time_base.calc_time(timestamp) {
                return time.as_micros().try_into().unwrap_or(0);
            }
        }
    }

    if let (Some(sample_rate), Some(num_frames)) = (codec_params.sample_rate, track.num_frames) {
        return duration_micros(num_frames as usize, sample_rate);
    }

    0
}

impl DecodedAudio {
    fn metadata(&self) -> NativeAudioMetadata {
        let channel_count = self.samples.len() as u32;
        let frame_count = self.samples.first().map_or(0usize, Vec::len);

        NativeAudioMetadata {
            duration_micros: duration_micros(frame_count, self.sample_rate),
            container: self.container.clone(),
            codec: self.codec.clone(),
            sample_rate: Some(self.sample_rate),
            channel_count: Some(channel_count),
            bit_rate: self.bit_rate,
            bit_depth: self.bit_depth,
            tags: self.tags.clone(),
        }
    }
}

impl ConvertedAudio {
    fn metadata(&self) -> NativeAudioMetadata {
        let channel_count = self.samples.len() as u32;
        let frame_count = self.samples.first().map_or(0usize, Vec::len);
        let bit_depth = self.target_format.metadata_bit_depth();
        let bit_rate = self.target_format.target_bit_rate().or_else(|| {
            bit_depth.and_then(|bit_depth| {
                (self.sample_rate as u64)
                    .saturating_mul(channel_count as u64)
                    .saturating_mul(bit_depth as u64)
                    .try_into()
                    .ok()
            })
        });

        NativeAudioMetadata {
            duration_micros: duration_micros(frame_count, self.sample_rate),
            container: Some(self.target_format.container().to_string()),
            codec: Some(self.target_format.codec_name().to_string()),
            sample_rate: Some(self.sample_rate),
            channel_count: Some(channel_count),
            bit_rate,
            bit_depth,
            tags: BTreeMap::new(),
        }
    }
}

fn duration_micros(frame_count: usize, sample_rate: u32) -> u64 {
    if sample_rate == 0 {
        return 0;
    }

    ((frame_count as u128) * 1_000_000u128 / sample_rate as u128) as u64
}

fn float_to_i16(value: f32) -> i16 {
    let clamped = value.clamp(-1.0, 1.0);
    if clamped <= -1.0 {
        i16::MIN
    } else if clamped >= 1.0 {
        i16::MAX
    } else {
        (clamped * i16::MAX as f32).round() as i16
    }
}

fn float_to_i24(value: f32) -> i32 {
    const MAX_I24: f32 = 8_388_607.0;
    const MIN_I24: f32 = -8_388_608.0;

    let clamped = (value.clamp(-1.0, 1.0) * MAX_I24).round();
    clamped.clamp(MIN_I24, MAX_I24) as i32
}

unsafe fn read_c_string(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }

    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .ok()
        .map(ToOwned::to_owned)
}

unsafe fn read_bytes(ptr: *const u8, len: isize) -> Option<Vec<u8>> {
    if ptr.is_null() || len <= 0 {
        return None;
    }

    Some(unsafe { std::slice::from_raw_parts(ptr, len as usize) }.to_vec())
}

unsafe fn take_audio_stream_inputs(
    inputs: *const NativeAudioStreamInput,
    input_count: isize,
) -> Result<Vec<OwnedAudioStreamInput>, String> {
    if input_count <= 0 {
        return Err("At least one native audio stream is required.".to_string());
    }
    if inputs.is_null() {
        return Err("Missing native audio stream inputs.".to_string());
    }
    let native_inputs = unsafe { std::slice::from_raw_parts(inputs, input_count as usize) };
    let owned_inputs = native_inputs
        .iter()
        .map(|input| OwnedAudioStreamInput {
            stream: OwnedNativeByteStream::new(input.stream),
            file_name_hint: unsafe { read_c_string(input.file_name_hint) },
            mime_type_hint: unsafe { read_c_string(input.mime_type_hint) },
        })
        .collect::<Vec<_>>();
    if owned_inputs
        .iter()
        .any(|input| !input.stream.descriptor.is_valid())
    {
        return Err("Invalid native audio stream descriptor.".to_string());
    }
    Ok(owned_inputs)
}

fn read_optional_json<T: for<'de> Deserialize<'de>>(
    ptr: *const c_char,
) -> Result<Option<T>, String> {
    let Some(payload) = (unsafe { read_c_string(ptr) }) else {
        return Ok(None);
    };

    serde_json::from_str::<T>(&payload)
        .map(Some)
        .map_err(|error| format!("Invalid JSON payload: {error}"))
}

fn set_last_error(message: impl Into<String>) {
    let message = message.into();
    let sanitized = message.replace('\0', " ");
    let c_string = CString::new(sanitized).unwrap_or_else(|_| {
        CString::new("dart_edge_audio native call failed.").expect("valid fallback error")
    });
    *LAST_ERROR.lock().unwrap() = Some(c_string);
}

fn clear_last_error() {
    *LAST_ERROR.lock().unwrap() = None;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn concatenates_native_streams_into_a_native_wav() {
        let fixture = include_bytes!("../../test/fixtures/tone.mp3");
        let inputs = vec![
            native_input(fixture, "first.mp3", "audio/mpeg"),
            native_input(fixture, "second.mp3", "audio/mpeg"),
        ];
        let result = concatenate_audio_streams(
            inputs,
            NativeStreamConcatenationRequest {
                target_format: NativeAudioTargetFormat::Legacy(
                    NativeLegacyAudioTargetFormat::WavPcm16,
                ),
                target_sample_rate: Some(16_000),
                channel_layout: NativeAudioChannelLayout::Mono,
            },
        )
        .expect("native streams should concatenate");

        let NativeAudioPoolResult::ConvertedStream {
            stream,
            content_length,
            result_json,
        } = result
        else {
            panic!("expected a converted native stream");
        };
        let mut output = OwnedNativeByteStream::new(stream.into_descriptor());
        let bytes = read_native_stream_to_end(&mut output).expect("output stream should read");
        assert_eq!(bytes.len() as u64, content_length);
        assert!(bytes.starts_with(b"RIFF"));
        assert_eq!(&bytes[8..12], b"WAVE");

        let result: serde_json::Value =
            serde_json::from_str(&result_json).expect("result metadata should decode");
        assert_eq!(result["mimeType"], "audio/wav");
        assert_eq!(result["metadata"]["sampleRate"], 16_000);
        assert_eq!(result["metadata"]["channelCount"], 1);
        assert_eq!(result["metadata"]["bitDepth"], 16);
        let duration_micros = result["metadata"]["durationMicros"]
            .as_u64()
            .expect("duration should be numeric");
        assert!((1_200_000..=1_800_000).contains(&duration_micros));
    }

    #[test]
    fn waveform_generation_preserves_wav_bytes_and_builds_levels() {
        let audio = ConvertedAudio {
            samples: vec![vec![-1.0, -0.5, 0.25, 1.0, -0.25]],
            sample_rate: 4,
            target_format: NativeAudioTargetFormat::Legacy(NativeLegacyAudioTargetFormat::WavPcm16),
        };
        let spec = NativeWaveformSpec {
            base_interval_micros: 500_000,
            level_factors: vec![1, 2],
        };

        let expected_wav = encode_wav(&audio).expect("plain WAV should encode");
        let (actual_wav, waveform) =
            encode_wav_with_waveform(&audio, &spec).expect("waveform WAV should encode");

        assert_eq!(actual_wav, expected_wav);
        assert_eq!(
            waveform.bytes,
            vec![
                (-127_i8) as u8,
                (-64_i8) as u8,
                32,
                127,
                (-32_i8) as u8,
                (-32_i8) as u8,
                (-127_i8) as u8,
                127,
                (-32_i8) as u8,
                (-32_i8) as u8
            ]
        );
        assert_eq!(waveform.json.levels[0].byte_offset, 0);
        assert_eq!(waveform.json.levels[0].byte_length, 6);
        assert_eq!(waveform.json.levels[1].byte_offset, 6);
        assert_eq!(waveform.json.levels[1].byte_length, 4);

        let waveform_only = generate_waveform(&audio, &spec).expect("waveform should generate");
        assert_eq!(waveform_only.bytes, waveform.bytes);
    }

    #[test]
    fn waveform_spec_rejects_invalid_levels() {
        assert!(
            validate_waveform_spec(&NativeWaveformSpec {
                base_interval_micros: 10_000,
                level_factors: vec![1, 4, 4],
            })
            .is_err()
        );
    }

    #[test]
    fn pcm16_stream_enforces_bounds_and_returns_native_wav() {
        let mut session = DartEdgeAudioPcm16StreamSession {
            input: Vec::new(),
            input_sample_rate_hz: 16_000,
            input_channel_count: 1,
            target_format: NativeAudioTargetFormat::Legacy(NativeLegacyAudioTargetFormat::WavPcm16),
            target_sample_rate: Some(16_000),
            channel_layout: NativeAudioChannelLayout::Mono,
            max_buffered_bytes: 8,
        };
        session
            .add_pcm16(&[0, 0, 1, 0, 2, 0, 3, 0])
            .expect("complete PCM frames should be accepted");
        assert!(session.add_pcm16(&[4, 0]).is_err());

        let result_ptr = session.finish().expect("PCM should encode as WAV");
        let result = unsafe { Box::from_raw(result_ptr) };
        assert_eq!(result.content_length, 52);
        let mut stream = OwnedNativeByteStream::new(result.stream);
        let bytes = read_native_stream_to_end(&mut stream).expect("WAV stream should read");
        assert!(bytes.starts_with(b"RIFF"));
        assert_eq!(&bytes[8..12], b"WAVE");
        unsafe { free_c_string(result.result_json) };
    }

    fn native_input(
        bytes: &[u8],
        file_name_hint: &str,
        mime_type_hint: &str,
    ) -> OwnedAudioStreamInput {
        OwnedAudioStreamInput {
            stream: OwnedNativeByteStream::new(native_memory_byte_stream(bytes.to_vec())),
            file_name_hint: Some(file_name_hint.to_string()),
            mime_type_hint: Some(mime_type_hint.to_string()),
        }
    }
}
