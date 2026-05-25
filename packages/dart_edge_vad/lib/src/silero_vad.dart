import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'native/dart_edge_vad_native.dart';
import 'native_pcm16_buffer.dart';
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

  /// Warm native Silero inference before the first real detection request.
  ///
  /// Use [sessionCount] greater than one to eagerly populate multiple native
  /// sessions from the shared pool for concurrent traffic.
  Future<void> initialize({int sessionCount = 1}) async {
    RangeError.checkValueInInterval(sessionCount, 1, 32, 'sessionCount');
    final warmup = Int16List(model.windowSizeSamples);
    await Future.wait([
      for (var i = 0; i < sessionCount; i += 1)
        detect(pcm16KhzMono: warmup, sampleRateHz: model.sampleRateHz),
    ]);
  }

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
    final requestJson = sileroVadRequestJson(
      model: model,
      options: options,
      sampleRateHz: sampleRateHz,
    );

    final resultJson = await Isolate.run(() {
      final input = transferable.materialize().asUint8List();
      return DartEdgeVadNative.detectSilero(requestJson, input);
    });

    return readVadResult(
      jsonDecode(resultJson) as Map<String, Object?>,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: pcm16KhzMono.length,
    );
  }

  /// Detect speech from a native-memory PCM16 buffer without copying the input
  /// in the Dart FFI wrapper.
  Future<VadResult> detectNativeBuffer({
    required NativePcm16Buffer pcm16KhzMono,
    required int sampleRateHz,
  }) {
    return detectNativePointer(
      pcm16BytesPtr: pcm16KhzMono.bytesPtr,
      pcm16ByteLength: pcm16KhzMono.byteLength,
      sampleLength: pcm16KhzMono.sampleLength,
      sampleRateHz: sampleRateHz,
    );
  }

  /// Detect speech from native PCM16 bytes.
  ///
  /// The pointer must remain valid until the returned future completes.
  Future<VadResult> detectNativePointer({
    required Pointer<Uint8> pcm16BytesPtr,
    required int pcm16ByteLength,
    required int sampleLength,
    required int sampleRateHz,
  }) async {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Silero VAD ${model.version} expects ${model.sampleRateHz} Hz audio.',
      );
    }
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    RangeError.checkNotNegative(sampleLength, 'sampleLength');
    if (pcm16ByteLength != sampleLength * 2) {
      throw ArgumentError.value(
        pcm16ByteLength,
        'pcm16ByteLength',
        'PCM16 byte length must be exactly sampleLength * 2.',
      );
    }

    final requestJson = sileroVadRequestJson(
      model: model,
      options: options,
      sampleRateHz: sampleRateHz,
    );
    final pcm16BytesAddress = pcm16BytesPtr.address;

    final resultJson = await Isolate.run(() {
      final inputPtr = pcm16BytesAddress == 0
          ? nullptr
          : Pointer<Uint8>.fromAddress(pcm16BytesAddress);
      return DartEdgeVadNative.detectSileroPointer(
        requestJson,
        inputPtr,
        pcm16ByteLength,
      );
    });

    return readVadResult(
      jsonDecode(resultJson) as Map<String, Object?>,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: sampleLength,
    );
  }
}

String sileroVadRequestJson({
  required SileroVadModel model,
  required SileroVadOptions options,
  required int sampleRateHz,
}) {
  return jsonEncode({
    'modelVersion': model.version,
    'sampleRateHz': sampleRateHz,
    'windowSizeSamples': model.windowSizeSamples,
    'threshold': options.threshold,
    'negThreshold': options.resolvedNegThreshold,
    'minSpeechDurationMs': options.minSpeechDuration.inMilliseconds,
    'minSilenceDurationMs': options.minSilenceDuration.inMilliseconds,
    'speechPadMs': options.speechPad.inMilliseconds,
  });
}

VadResult readVadResult(
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
