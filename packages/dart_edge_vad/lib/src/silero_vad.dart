import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'native/dart_edge_vad_native.dart';
import 'vad.dart';
import 'vad_result.dart';

/// Supported Silero VAD ONNX model metadata.
final class SileroVadModel {
  const SileroVadModel({
    required this.version,
    required this.sampleRateHz,
    required this.windowSizeSamples,
    required this.inputName,
    required this.stateInputName,
    required this.sampleRateInputName,
    required this.outputName,
    required this.stateOutputName,
  });

  /// Latest model line supported by this package.
  ///
  /// Silero VAD v6.2.1 was released upstream in February 2025. The commonly
  /// distributed ONNX artifact is fixed at 16 kHz audio.
  static const latest = v6_2_1;

  static const v6_2_1 = SileroVadModel(
    version: '6.2.1',
    sampleRateHz: 16000,
    windowSizeSamples: 512,
    inputName: 'input',
    stateInputName: 'state',
    sampleRateInputName: 'sr',
    outputName: 'output',
    stateOutputName: 'stateN',
  );

  final String version;
  final int sampleRateHz;
  final int windowSizeSamples;
  final String inputName;
  final String stateInputName;
  final String sampleRateInputName;
  final String outputName;
  final String stateOutputName;
}

/// Tunables that match Silero's timestamp post-processing concepts.
final class SileroVadOptions {
  const SileroVadOptions({
    this.threshold = 0.5,
    this.negThreshold,
    this.minSpeechDuration = const Duration(milliseconds: 250),
    this.minSilenceDuration = const Duration(milliseconds: 100),
    this.speechPad = const Duration(milliseconds: 30),
  }) : assert(threshold > 0 && threshold < 1),
       assert(negThreshold == null || negThreshold > 0),
       assert(negThreshold == null || negThreshold < threshold);

  final double threshold;
  final double? negThreshold;
  final Duration minSpeechDuration;
  final Duration minSilenceDuration;
  final Duration speechPad;

  double get resolvedNegThreshold => negThreshold ?? threshold - 0.15;
}

/// Silero VAD detector facade.
final class SileroVad implements Vad {
  SileroVad({
    this.model = SileroVadModel.latest,
    this.options = const SileroVadOptions(),
  });

  final SileroVadModel model;

  final SileroVadOptions options;

  @override
  Future<VadResult> detect({
    required Int16List pcm16KhzMono,
    required int sampleRateHz,
  }) async {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Silero VAD ${model.version} expects ${model.sampleRateHz} Hz audio.',
      );
    }

    final bytes = Uint8List.view(
      pcm16KhzMono.buffer,
      pcm16KhzMono.offsetInBytes,
      pcm16KhzMono.lengthInBytes,
    );
    final transferable = TransferableTypedData.fromList([bytes]);
    final requestJson = jsonEncode({
      'modelVersion': model.version,
      'sampleRateHz': sampleRateHz,
      'windowSizeSamples': model.windowSizeSamples,
      'threshold': options.threshold,
      'negThreshold': options.resolvedNegThreshold,
      'minSpeechDurationMs': options.minSpeechDuration.inMilliseconds,
      'minSilenceDurationMs': options.minSilenceDuration.inMilliseconds,
      'speechPadMs': options.speechPad.inMilliseconds,
    });

    final resultJson = await Isolate.run(() {
      final input = transferable.materialize().asUint8List();
      return DartEdgeVadNative.detectSilero(requestJson, input);
    });

    return _readVadResult(
      jsonDecode(resultJson) as Map<String, Object?>,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: pcm16KhzMono.length,
    );
  }
}

VadResult _readVadResult(
  Map<String, Object?> json, {
  required int expectedSampleRateHz,
  required int expectedTotalSamples,
}) {
  final sampleRateHz = json['sampleRateHz'] as int? ?? expectedSampleRateHz;
  final totalSamples = json['totalSamples'] as int? ?? expectedTotalSamples;
  final rawSegments = json['segments'] as List<Object?>? ?? const <Object?>[];
  final segments = rawSegments.map((rawSegment) {
    final segment = rawSegment as Map<String, Object?>;
    return VadSegment(
      startSample: segment['startSample'] as int,
      endSample: segment['endSample'] as int,
      sampleRateHz: sampleRateHz,
    );
  }).toList();

  return VadResult(
    segments: segments,
    sampleRateHz: sampleRateHz,
    totalSamples: totalSamples,
  );
}
