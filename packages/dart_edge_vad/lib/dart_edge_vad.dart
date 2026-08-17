/// Voice activity detection and audio trimming APIs for Dart Edge.
///
/// Import this library when you need to detect speech segments in normalized
/// PCM audio and trim PCM or WAV payloads to those segments.
library;

export 'src/audio_trimmer.dart';
export 'src/native_pcm16_buffer.dart';
export 'src/native_vad.dart';
export 'src/native_vad_stream.dart';
export 'src/native_vad_trim_stream.dart';
export 'src/vad.dart';
export 'src/vad_result.dart';
export 'src/wav_audio.dart';
