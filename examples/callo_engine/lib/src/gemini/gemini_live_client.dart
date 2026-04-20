import 'dart:async';
import 'dart:typed_data';

import 'package:googleai_dart/googleai_dart.dart' as genai;

import '../config/gemini_live_config.dart';
import '../logging/callo_logger.dart';

final class GeminiLiveClient {
  GeminiLiveClient._({
    required genai.GoogleAIClient client,
    required genai.LiveClient liveClient,
    required genai.LiveSession session,
  }) : _client = client,
       _liveClient = liveClient,
       _session = session;

  final genai.GoogleAIClient _client;
  final genai.LiveClient _liveClient;
  final genai.LiveSession _session;

  bool _audioEnded = false;
  bool _closed = false;

  Stream<genai.BidiGenerateContentServerMessage> get messages =>
      _session.messages;

  static Future<GeminiLiveClient> connect(
    GeminiLiveConfig settings, {
    required String logTag,
    required CalloLogger logger,
  }) async {
    final model = geminiLiveModelId(settings.model);

    try {
      return await _connectWithConfig(
        settings,
        logTag: logTag,
        logger: logger,
        model: model,
        minimalConfig: false,
      );
    } catch (error) {
      if (!_shouldRetryGeminiMinimalConfig(error)) {
        rethrow;
      }

      logger.info(
        '$logTag retrying Gemini Live setup with minimal config '
        '(responseModalities=AUDIO only).',
      );
      try {
        return await _connectWithConfig(
          settings,
          logTag: logTag,
          logger: logger,
          model: model,
          minimalConfig: true,
        );
      } catch (minimalError) {
        throw StateError(
          'Gemini Live SDK setup failed for model ${settings.model} with both '
          'the full phone-assistant config and the minimal AUDIO-only config. '
          'Full config error: $error. Minimal config error: $minimalError',
        );
      }
    }
  }

  static Future<GeminiLiveClient> _connectWithConfig(
    GeminiLiveConfig settings, {
    required String logTag,
    required CalloLogger logger,
    required String model,
    required bool minimalConfig,
  }) async {
    final client = createGeminiSdkClient(settings);
    final liveClient = client.createLiveClient();
    final liveConfig = _buildGeminiLiveConfig(settings, minimal: minimalConfig);

    final configDescription = minimalConfig
        ? 'minimal audio config'
        : 'voice=${settings.voiceName}, transcription=on, vad=auto';
    logger.info(
      '$logTag opening Gemini Live SDK session '
      '(sdk=googleai_dart, api=v1beta, model=$model, '
      '$configDescription).',
    );
    final stopwatch = Stopwatch()..start();

    try {
      final session = await liveClient.connect(
        model: model,
        liveConfig: liveConfig,
      );
      stopwatch.stop();
      logger.info(
        '$logTag Gemini Live SDK session connected in '
        '${stopwatch.elapsedMilliseconds}ms'
        '${session.sessionId == null ? '' : ' (sessionId=${session.sessionId})'}.',
      );
      return GeminiLiveClient._(
        client: client,
        liveClient: liveClient,
        session: session,
      );
    } catch (error) {
      stopwatch.stop();
      await liveClient.close();
      client.close();
      if (error case genai.LiveConnectionException(:final message)) {
        throw StateError('Gemini Live SDK connection failed: $message');
      }
      if (error case genai.LiveSessionSetupException(:final message)) {
        throw StateError(
          'Gemini Live SDK setup failed for model ${settings.model} after '
          '${stopwatch.elapsedMilliseconds}ms: $message. Check that the API '
          'key has Live API access and that the selected model supports Live '
          'audio sessions.',
        );
      }
      if (error case genai.GoogleAIException(:final message)) {
        throw StateError('Gemini SDK error: $message');
      }
      final description = error.toString();
      if (_isWebSocketClosedSetupError(error)) {
        throw StateError(
          'Gemini Live SDK closed the WebSocket during setup after '
          '${stopwatch.elapsedMilliseconds}ms. This usually means the server '
          'rejected the session before setup completed. Check the API key, '
          'Live API access, and GEMINI_LIVE_MODEL=${settings.model}. '
          'The current default is $defaultGeminiLiveModel. '
          'SDK detail: $description',
        );
      }
      throw StateError('Gemini Live SDK failed during setup: $description');
    }
  }

  Future<void> sendRealtimeText(String text) async {
    if (_closed || !_session.isConnected || text.trim().isEmpty) {
      return;
    }
    _session.sendText(text.trim());
  }

  Future<void> sendRealtimeAudio(Uint8List bytes) async {
    if (_closed || !_session.isConnected || bytes.isEmpty) {
      return;
    }
    _session.sendAudio(bytes);
  }

  Future<void> endAudioInput() async {
    if (_closed || !_session.isConnected || _audioEnded) {
      return;
    }
    _audioEnded = true;
    _session.signalAudioStreamEnd();
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _session.close();
    await _liveClient.close();
    _client.close();
  }
}

genai.GoogleAIClient createGeminiSdkClient(
  GeminiLiveConfig settings, {
  Duration timeout = const Duration(seconds: 45),
}) {
  return genai.GoogleAIClient(
    config: genai.GoogleAIConfig.googleAI(
      apiVersion: genai.ApiVersion.v1beta,
      authProvider: genai.ApiKeyProvider(settings.apiKey),
      timeout: timeout,
    ),
  );
}

String geminiLiveModelId(String model) {
  final trimmed = model.trim();
  if (trimmed.startsWith('models/')) {
    return trimmed.substring('models/'.length);
  }
  return trimmed;
}

bool isExpectedGeminiSetupFailure(Object error) {
  final message = error.toString();
  return message.contains('Gemini Live SDK') ||
      message.contains('Live API access') ||
      message.contains('WebSocketConnectionClosed');
}

genai.LiveConfig _buildGeminiLiveConfig(
  GeminiLiveConfig settings, {
  required bool minimal,
}) {
  if (minimal) {
    return genai.LiveConfig(
      generationConfig: genai.LiveGenerationConfig.audioOnly(),
    );
  }

  return genai.LiveConfig(
    generationConfig: genai.LiveGenerationConfig.audioOnly(
      speechConfig: genai.SpeechConfig.withVoice(settings.voiceName),
    ),
    systemInstruction: genai.Content(
      parts: [genai.TextPart(settings.systemPrompt)],
    ),
    inputAudioTranscription: genai.AudioTranscriptionConfig.enabled(),
    outputAudioTranscription: genai.AudioTranscriptionConfig.enabled(),
    realtimeInputConfig: genai.RealtimeInputConfig.withVAD(
      silenceDurationMs: 500,
      activityHandling: genai.ActivityHandling.startOfActivityInterrupts,
    ),
  );
}

bool _shouldRetryGeminiMinimalConfig(Object error) {
  final message = error.toString();
  return message.contains('Gemini Live SDK setup failed') ||
      message.contains('Gemini Live SDK closed the WebSocket') ||
      message.contains('Gemini Live SDK failed during setup');
}

bool _isWebSocketClosedSetupError(Object error) {
  var current = error;
  for (var depth = 0; depth < 8; depth += 1) {
    final description = current.toString();
    if (description.contains('WebSocketConnectionClosed')) {
      return true;
    }
    if (current case genai.GoogleAIException(:final cause?)) {
      current = cause;
      continue;
    }
    return false;
  }
  return false;
}
