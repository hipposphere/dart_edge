use std::mem::ManuallyDrop;
use std::ptr;

use ffmpeg::codec;
use ffmpeg::format;
use ffmpeg::format::sample::Type as SampleType;
use ffmpeg::util::frame::Audio as AudioFrame;
use ffmpeg::{ChannelLayout, Packet};
use ffmpeg_next as ffmpeg;

use super::{
    ConvertedAudio, NativeAudioMetadata, NativeAudioOutputSpec, duration_micros, encode_wav,
    float_to_i16,
};

pub(super) struct EncodedAudio {
    pub bytes: Vec<u8>,
    pub mime_type: &'static str,
    pub metadata: NativeAudioMetadata,
}

pub(super) fn encode_audio(audio: &ConvertedAudio) -> Result<EncodedAudio, String> {
    let bytes = match audio.target_format.output() {
        NativeAudioOutputSpec::WavPcm16 | NativeAudioOutputSpec::WavPcm24 => encode_wav(audio)?,
        NativeAudioOutputSpec::M4aAacLc { bit_rate } => encode_m4a_aac_lc(audio, bit_rate)?,
        NativeAudioOutputSpec::Flac { compression_level } => encode_flac(audio, compression_level)?,
    };
    let metadata = encoded_metadata(audio, bytes.len());
    Ok(EncodedAudio {
        bytes,
        mime_type: audio.target_format.mime_type(),
        metadata,
    })
}

fn encoded_metadata(audio: &ConvertedAudio, encoded_bytes: usize) -> NativeAudioMetadata {
    let channel_count = audio.samples.len() as u32;
    let frame_count = audio.samples.first().map_or(0usize, Vec::len);
    let duration_micros = duration_micros(frame_count, audio.sample_rate);
    let bit_rate = audio.target_format.target_bit_rate().or_else(|| {
        if duration_micros == 0 {
            return None;
        }
        (encoded_bytes as u128)
            .saturating_mul(8)
            .saturating_mul(1_000_000)
            .checked_div(duration_micros as u128)
            .and_then(|value| value.try_into().ok())
    });
    NativeAudioMetadata {
        duration_micros,
        container: Some(audio.target_format.container().to_string()),
        codec: Some(audio.target_format.codec_name().to_string()),
        sample_rate: Some(audio.sample_rate),
        channel_count: Some(channel_count),
        bit_rate,
        bit_depth: audio.target_format.metadata_bit_depth(),
        tags: Default::default(),
    }
}

fn encode_flac(audio: &ConvertedAudio, compression_level: u8) -> Result<Vec<u8>, String> {
    let channels = audio.samples.len();
    if channels == 0 || channels > 8 {
        return Err(format!(
            "FLAC output requires between 1 and 8 channels, got {channels}."
        ));
    }
    if compression_level > 8 {
        return Err("FLAC compression level must be between 0 and 8.".to_string());
    }

    FFMPEG_INITIALIZED.clone()?;
    let channel_layout = ChannelLayout::default(channels as i32);
    let codec = ffmpeg::encoder::find(codec::Id::FLAC)
        .ok_or_else(|| "The bundled FFmpeg build does not include its FLAC encoder.".to_string())?
        .audio()
        .map_err(|error| format!("Failed to open the FFmpeg FLAC encoder: {error}"))?;
    let mut output = DynamicOutput::new("flac", "memory.flac")?;
    let global_header = output
        .format()
        .flags()
        .contains(format::flag::Flags::GLOBAL_HEADER);
    output
        .add_stream(codec)
        .map_err(|error| format!("Failed to create the FLAC audio stream: {error}"))?;

    let context = codec::context::Context::new_with_codec(*codec);
    let mut encoder = context
        .encoder()
        .audio()
        .map_err(|error| format!("Failed to create the FLAC encoder context: {error}"))?;
    if global_header {
        encoder.set_flags(codec::flag::Flags::GLOBAL_HEADER);
    }
    encoder.set_rate(audio.sample_rate as i32);
    encoder.set_channel_layout(channel_layout);
    encoder.set_format(format::Sample::I16(SampleType::Packed));
    encoder.set_time_base((1, audio.sample_rate as i32));
    encoder.set_compression(Some(compression_level as usize));
    let mut encoder = encoder
        .open_as(codec)
        .map_err(|error| format!("Failed to initialize FLAC encoding: {error}"))?;

    {
        let mut stream = output
            .stream_mut(0)
            .ok_or_else(|| "FLAC output stream was not created.".to_string())?;
        stream.set_parameters(&encoder);
        stream.set_time_base((1, audio.sample_rate as i32));
    }
    output
        .write_header()
        .map_err(|error| format!("Failed to write the FLAC header: {error}"))?;

    let frame_size = usize::try_from(encoder.frame_size())
        .ok()
        .filter(|value| *value > 0)
        .unwrap_or(4096);
    let frame_count = audio.samples[0].len();
    let mut frame_start = 0usize;
    while frame_start < frame_count {
        let available = (frame_count - frame_start).min(frame_size);
        let mut frame = AudioFrame::new(
            format::Sample::I16(SampleType::Packed),
            available,
            channel_layout,
        );
        frame.set_rate(audio.sample_rate);
        frame.set_pts(Some(frame_start as i64));
        let required_bytes = available
            .checked_mul(channels)
            .and_then(|value| value.checked_mul(std::mem::size_of::<i16>()))
            .ok_or_else(|| "FLAC PCM frame size overflowed.".to_string())?;
        let data = frame.data_mut(0);
        if data.len() < required_bytes {
            return Err("FFmpeg allocated an undersized FLAC PCM frame.".to_string());
        }
        for frame_offset in 0..available {
            for (channel_index, samples) in audio.samples.iter().enumerate() {
                let sample = float_to_i16(samples[frame_start + frame_offset]).to_ne_bytes();
                let byte_offset = (frame_offset * channels + channel_index) * 2;
                data[byte_offset..byte_offset + 2].copy_from_slice(&sample);
            }
        }
        encoder
            .send_frame(&frame)
            .map_err(|error| format!("Failed to submit PCM to the FLAC encoder: {error}"))?;
        write_available_packets(&mut encoder, &mut output, audio.sample_rate, "FLAC")?;
        frame_start = frame_start.saturating_add(available);
    }
    encoder
        .send_eof()
        .map_err(|error| format!("Failed to flush the FLAC encoder: {error}"))?;
    write_available_packets(&mut encoder, &mut output, audio.sample_rate, "FLAC")?;
    output
        .write_trailer()
        .map_err(|error| format!("Failed to finalize the FLAC stream: {error}"))?;
    output.finish()
}

static FFMPEG_INITIALIZED: once_cell::sync::Lazy<Result<(), String>> =
    once_cell::sync::Lazy::new(|| {
        ffmpeg::init()
            .map_err(|error| format!("Failed to initialize FFmpeg audio encoder: {error}"))
    });

fn encode_m4a_aac_lc(audio: &ConvertedAudio, bit_rate: u32) -> Result<Vec<u8>, String> {
    FFMPEG_INITIALIZED.clone()?;
    let channel_layout = match audio.samples.len() {
        1 => ChannelLayout::MONO,
        2 => ChannelLayout::STEREO,
        channels => {
            return Err(format!(
                "AAC-LC output requires mono or stereo audio, got {channels} channels."
            ));
        }
    };
    if !(8_000..=512_000).contains(&bit_rate) {
        return Err("AAC bit rate must be between 8000 and 512000 bits per second.".to_string());
    }

    let codec = ffmpeg::encoder::find(codec::Id::AAC)
        .ok_or_else(|| "The bundled FFmpeg build does not include its AAC encoder.".to_string())?
        .audio()
        .map_err(|error| format!("Failed to open the FFmpeg AAC encoder: {error}"))?;
    let mut output = DynamicOutput::new("ipod", "memory.m4a")?;
    let global_header = output
        .format()
        .flags()
        .contains(format::flag::Flags::GLOBAL_HEADER);
    output
        .add_stream(codec)
        .map_err(|error| format!("Failed to create the M4A audio stream: {error}"))?;

    let context = codec::context::Context::new_with_codec(*codec);
    let mut encoder = context
        .encoder()
        .audio()
        .map_err(|error| format!("Failed to create the AAC encoder context: {error}"))?;
    if global_header {
        encoder.set_flags(codec::flag::Flags::GLOBAL_HEADER);
    }
    encoder.set_rate(audio.sample_rate as i32);
    encoder.set_channel_layout(channel_layout);
    encoder.set_format(format::Sample::F32(SampleType::Planar));
    encoder.set_bit_rate(bit_rate as usize);
    encoder.set_time_base((1, audio.sample_rate as i32));
    let mut encoder = encoder
        .open_as(codec)
        .map_err(|error| format!("Failed to initialize AAC-LC encoding: {error}"))?;

    {
        let mut stream = output
            .stream_mut(0)
            .ok_or_else(|| "M4A output stream was not created.".to_string())?;
        stream.set_parameters(&encoder);
        stream.set_time_base((1, audio.sample_rate as i32));
    }
    output
        .write_header()
        .map_err(|error| format!("Failed to write the M4A header: {error}"))?;

    let frame_size = usize::try_from(encoder.frame_size())
        .ok()
        .filter(|value| *value > 0)
        .unwrap_or(1024);
    let frame_count = audio.samples[0].len();
    let mut frame_start = 0usize;
    while frame_start < frame_count {
        let available = (frame_count - frame_start).min(frame_size);
        let mut frame = AudioFrame::new(
            format::Sample::F32(SampleType::Planar),
            frame_size,
            channel_layout,
        );
        frame.set_rate(audio.sample_rate);
        frame.set_pts(Some(frame_start as i64));
        for (channel_index, samples) in audio.samples.iter().enumerate() {
            let plane = frame.plane_mut::<f32>(channel_index);
            plane.fill(0.0);
            plane[..available]
                .copy_from_slice(&samples[frame_start..frame_start.saturating_add(available)]);
        }
        encoder
            .send_frame(&frame)
            .map_err(|error| format!("Failed to submit PCM to the AAC encoder: {error}"))?;
        write_available_packets(&mut encoder, &mut output, audio.sample_rate, "M4A")?;
        frame_start = frame_start.saturating_add(available);
    }
    encoder
        .send_eof()
        .map_err(|error| format!("Failed to flush the AAC encoder: {error}"))?;
    write_available_packets(&mut encoder, &mut output, audio.sample_rate, "M4A")?;
    output
        .write_trailer()
        .map_err(|error| format!("Failed to finalize the M4A container: {error}"))?;
    output.finish()
}

fn write_available_packets(
    encoder: &mut codec::encoder::audio::Encoder,
    output: &mut DynamicOutput,
    sample_rate: u32,
    output_name: &str,
) -> Result<(), String> {
    let mut packet = Packet::empty();
    while encoder.receive_packet(&mut packet).is_ok() {
        packet.set_stream(0);
        let stream_time_base = output
            .stream(0)
            .ok_or_else(|| format!("{output_name} output stream disappeared."))?
            .time_base();
        packet.rescale_ts((1, sample_rate as i32), stream_time_base);
        packet
            .write_interleaved(output)
            .map_err(|error| format!("Failed to mux a packet into {output_name}: {error}"))?;
    }
    Ok(())
}

struct DynamicOutput {
    output: ManuallyDrop<format::context::Output>,
    context: *mut ffmpeg::ffi::AVFormatContext,
}

impl DynamicOutput {
    fn new(format_name: &str, file_name_hint: &str) -> Result<Self, String> {
        let format_name = std::ffi::CString::new(format_name)
            .map_err(|_| "Invalid FFmpeg output format name.".to_string())?;
        let file_name_hint = std::ffi::CString::new(file_name_hint)
            .map_err(|_| "Invalid FFmpeg output filename hint.".to_string())?;
        unsafe {
            let mut context = ptr::null_mut();
            let status = ffmpeg::ffi::avformat_alloc_output_context2(
                &mut context,
                ptr::null_mut(),
                format_name.as_ptr(),
                file_name_hint.as_ptr(),
            );
            if status < 0 || context.is_null() {
                return Err(format!(
                    "Failed to allocate an in-memory audio context ({status})."
                ));
            }
            let mut io = ptr::null_mut();
            let status = ffmpeg::ffi::avio_open_dyn_buf(&mut io);
            if status < 0 || io.is_null() {
                ffmpeg::ffi::avformat_free_context(context);
                return Err(format!(
                    "Failed to allocate an in-memory audio buffer ({status})."
                ));
            }
            (*context).pb = io;
            Ok(Self {
                output: ManuallyDrop::new(format::context::Output::wrap(context)),
                context,
            })
        }
    }

    fn finish(mut self) -> Result<Vec<u8>, String> {
        let bytes = self.close_buffer()?;
        unsafe {
            ffmpeg::ffi::avformat_free_context(self.context);
        }
        self.context = ptr::null_mut();
        Ok(bytes)
    }

    fn close_buffer(&mut self) -> Result<Vec<u8>, String> {
        unsafe {
            if self.context.is_null() || (*self.context).pb.is_null() {
                return Err("The in-memory audio buffer is already closed.".to_string());
            }
            let mut bytes_ptr = ptr::null_mut();
            let length = ffmpeg::ffi::avio_close_dyn_buf((*self.context).pb, &mut bytes_ptr);
            (*self.context).pb = ptr::null_mut();
            if length < 0 || bytes_ptr.is_null() {
                return Err(format!(
                    "Failed to close the in-memory audio buffer ({length})."
                ));
            }
            let length = length as usize;
            let source = std::slice::from_raw_parts(bytes_ptr, length);
            let mut bytes = Vec::new();
            let reserve = bytes.try_reserve_exact(length);
            if let Err(error) = reserve {
                ffmpeg::ffi::av_free(bytes_ptr.cast());
                return Err(format!("Could not reserve encoded audio memory: {error}"));
            }
            bytes.extend_from_slice(source);
            ffmpeg::ffi::av_free(bytes_ptr.cast());
            Ok(bytes)
        }
    }
}

impl std::ops::Deref for DynamicOutput {
    type Target = format::context::Output;

    fn deref(&self) -> &Self::Target {
        &self.output
    }
}

impl std::ops::DerefMut for DynamicOutput {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.output
    }
}

impl Drop for DynamicOutput {
    fn drop(&mut self) {
        if self.context.is_null() {
            return;
        }
        unsafe {
            if !(*self.context).pb.is_null() {
                let mut bytes_ptr = ptr::null_mut();
                ffmpeg::ffi::avio_close_dyn_buf((*self.context).pb, &mut bytes_ptr);
                if !bytes_ptr.is_null() {
                    ffmpeg::ffi::av_free(bytes_ptr.cast());
                }
                (*self.context).pb = ptr::null_mut();
            }
            ffmpeg::ffi::avformat_free_context(self.context);
        }
        self.context = ptr::null_mut();
        // `output` is intentionally not dropped because its destructor would
        // free the same AVFormatContext a second time.
        let _ = &self.output;
    }
}
