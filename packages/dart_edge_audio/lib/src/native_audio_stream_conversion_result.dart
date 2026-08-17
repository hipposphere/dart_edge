import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart';

import 'audio_metadata.dart';

/// Converted audio that stays native until a consumer reads or adopts it.
final class NativeAudioStreamConversionResult {
  const NativeAudioStreamConversionResult({
    required this.body,
    required this.contentLength,
    required this.mimeType,
    required this.metadata,
    this.fileExtension = '',
  });

  /// Single-owner native body suitable for `NativeBinaryStreamResponse`.
  final NativeByteStreamHandle body;

  final int contentLength;
  final String mimeType;

  /// Recommended extension for the encoded output, without a leading dot.
  ///
  /// This is empty only for manually constructed legacy results.
  final String fileExtension;
  final AudioMetadata metadata;

  /// Cancels and releases the native body when it is not transferred onward.
  Future<void> close() => body.close();

  factory NativeAudioStreamConversionResult.fromJson(
    Map<String, Object?> json, {
    required NativeByteStreamHandle body,
    required int contentLength,
  }) {
    return NativeAudioStreamConversionResult(
      body: body,
      contentLength: contentLength,
      mimeType: json['mimeType'] as String,
      fileExtension: json['fileExtension'] as String? ?? '',
      metadata: AudioMetadata.fromJson(
        json['metadata'] as Map<String, Object?>,
      ),
    );
  }
}
