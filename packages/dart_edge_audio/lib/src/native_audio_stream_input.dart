import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart';

/// One single-owner native audio body consumed by a concatenation job.
final class NativeAudioStreamInput {
  const NativeAudioStreamInput({
    required this.body,
    this.fileNameHint,
    this.mimeTypeHint,
  });

  /// Native body transferred to the audio worker when the job is submitted.
  final NativeByteStreamHandle body;

  final String? fileNameHint;
  final String? mimeTypeHint;
}
