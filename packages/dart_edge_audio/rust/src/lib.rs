use std::collections::BTreeMap;
use std::ffi::{CStr, CString, c_char};
use std::fs;
use std::io::Cursor;
use std::path::Path;
use std::sync::Mutex;

use audioadapter_buffers::direct::SequentialSliceOfVecs;
use dart_edge_core::{NativeOwnedBytes, free_owned_bytes, into_native_owned_bytes};
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

const DART_EDGE_AUDIO_NATIVE_ABI_VERSION: i32 = 1;

static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

#[repr(C)]
pub struct NativeAudioBytesResult {
    bytes: NativeOwnedBytes,
    result_json: *mut c_char,
}

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
}

#[derive(Deserialize, Clone, Copy)]
#[serde(rename_all = "camelCase")]
enum NativeAudioTargetFormat {
    WavPcm16,
    WavPcm24,
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
    fn bit_depth(self) -> u16 {
        match self {
            Self::WavPcm16 => 16,
            Self::WavPcm24 => 24,
        }
    }

    fn codec_name(self) -> &'static str {
        match self {
            Self::WavPcm16 => "pcm_s16le",
            Self::WavPcm24 => "pcm_s24le",
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

#[derive(Serialize)]
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
    metadata: NativeAudioMetadata,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct NativeBytesConversionResultJson {
    mime_type: String,
    metadata: NativeAudioMetadata,
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
pub extern "C" fn dart_edge_audio_free_bytes_result(value: *mut NativeAudioBytesResult) {
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
    let wav_bytes = encode_wav(&converted)?;

    fs::write(&request.output_path, wav_bytes)
        .map_err(|error| format!("Failed to write converted audio file: {error}"))?;

    Ok(NativeFileConversionResult {
        output_path: request.output_path,
        mime_type: "audio/wav".to_string(),
        metadata: converted.metadata(),
    })
}

fn convert_bytes(
    bytes: Vec<u8>,
    request: NativeBytesConversionRequest,
) -> Result<*mut NativeAudioBytesResult, String> {
    validate_sample_rate(request.target_sample_rate)?;

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
    let wav_bytes = encode_wav(&converted)?;
    let result_json = NativeBytesConversionResultJson {
        mime_type: "audio/wav".to_string(),
        metadata: converted.metadata(),
    };

    encode_bytes_result(wav_bytes, &result_json)
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
                let mut mono = Vec::with_capacity(frame_count);
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
                vec![samples[0].clone(), samples[0].clone()]
            } else {
                let mut left = Vec::with_capacity(frame_count);
                let mut right = Vec::with_capacity(frame_count);

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
    let mut resampled = vec![Vec::new(); channel_count];
    for frame in output.take_data().chunks(channel_count) {
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
        bits_per_sample: audio.target_format.bit_depth(),
        sample_format: SampleFormat::Int,
    };

    let mut cursor = Cursor::new(Vec::new());
    {
        let mut writer = WavWriter::new(&mut cursor, spec)
            .map_err(|error| format!("Failed to create WAV writer: {error}"))?;

        for frame_index in 0..frame_count {
            for channel in &audio.samples {
                match audio.target_format {
                    NativeAudioTargetFormat::WavPcm16 => writer
                        .write_sample(float_to_i16(channel[frame_index]))
                        .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                    NativeAudioTargetFormat::WavPcm24 => writer
                        .write_sample(float_to_i24(channel[frame_index]))
                        .map_err(|error| format!("Failed to write WAV sample: {error}"))?,
                }
            }
        }

        writer
            .finalize()
            .map_err(|error| format!("Failed to finalize WAV output: {error}"))?;
    }

    Ok(cursor.into_inner())
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

fn encode_json_string<T: Serialize>(value: &T) -> Result<*mut c_char, String> {
    let json = serde_json::to_string(value)
        .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
    CString::new(json)
        .map(CString::into_raw)
        .map_err(|error| format!("Failed to encode C string: {error}"))
}

fn encode_bytes_result<T: Serialize>(
    bytes: Vec<u8>,
    result: &T,
) -> Result<*mut NativeAudioBytesResult, String> {
    let result_json = serde_json::to_string(result)
        .map_err(|error| format!("Failed to encode JSON payload: {error}"))?;
    let result_json =
        CString::new(result_json).map_err(|error| format!("Failed to encode C string: {error}"))?;

    let native_bytes = into_native_owned_bytes(bytes);

    Ok(Box::into_raw(Box::new(NativeAudioBytesResult {
        bytes: native_bytes,
        result_json: result_json.into_raw(),
    })))
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
        let bit_depth = self.target_format.bit_depth() as u32;
        let bit_rate = (self.sample_rate as u64)
            .saturating_mul(channel_count as u64)
            .saturating_mul(bit_depth as u64)
            .try_into()
            .ok();

        NativeAudioMetadata {
            duration_micros: duration_micros(frame_count, self.sample_rate),
            container: Some("wav".to_string()),
            codec: Some(self.target_format.codec_name().to_string()),
            sample_rate: Some(self.sample_rate),
            channel_count: Some(channel_count),
            bit_rate,
            bit_depth: Some(bit_depth),
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
