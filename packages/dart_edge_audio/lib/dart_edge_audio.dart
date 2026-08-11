/// Native-backed audio probing and conversion utilities for Dart Edge.
///
/// Import this library when you want coarse-grained metadata extraction and
/// WAV conversion helpers backed by a bundled Rust implementation.
library;

export 'src/audio_bytes_conversion_request.dart';
export 'src/audio_bytes_conversion_result.dart';
export 'src/audio_channel_layout.dart';
export 'src/audio_file_conversion_request.dart';
export 'src/audio_file_conversion_result.dart';
export 'src/audio_metadata.dart';
export 'src/audio_probe_mode.dart';
export 'src/audio_target_format.dart';
export 'src/audio_waveform.dart';
export 'src/audio_waveform_analysis_request.dart';
export 'src/audio_waveform_analysis_result.dart';
export 'src/dart_edge_audio.dart';
export 'src/native_audio_pool.dart';
export 'src/native_audio_stream_conversion_result.dart';
export 'src/native_audio_stream_input.dart';
export 'src/native_audio_waveform_session.dart';
