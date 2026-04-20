import 'dart:async';
import 'dart:typed_data';

import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:googleai_dart/googleai_dart.dart' as genai;

import '../audio/audio_tools.dart';
import '../config/gemini_live_config.dart';
import '../gemini/gemini_live_client.dart';
import '../logging/callo_logger.dart';

final class GeminiLiveMediaApp implements SipMediaApp {
  const GeminiLiveMediaApp(this.settings, {required this.logger});

  static const defaultId = 'gemini-live-assistant';

  final GeminiLiveConfig settings;
  final CalloLogger logger;

  @override
  String get id => defaultId;

  @override
  Future<void> run(SipMediaAppSession session) async {
    final bridge = _GeminiLiveBridge(
      settings: settings,
      session: session,
      logger: logger,
    );
    await bridge.run();
  }
}

final class _GeminiLiveBridge {
  _GeminiLiveBridge({
    required this.settings,
    required this.session,
    required this.logger,
  });

  final GeminiLiveConfig settings;
  final SipMediaAppSession session;
  final CalloLogger logger;
  final Pcm24kTo16kDownsampler _downsampler = Pcm24kTo16kDownsampler();
  bool _loggedFirstSipAudioFrame = false;
  bool _loggedFirstGeminiAudioChunk = false;

  String get _tag => '[assistant/${session.call.id}]';

  Future<void> run() async {
    logger.info('$_tag connecting to Gemini Live...');
    _startLocalJingle();
    GeminiLiveClient? client;
    var tasks = <Future<void>>[];

    try {
      final setupWaitLog = Timer(const Duration(seconds: 3), () {
        logger.info(
          '$_tag still waiting for Gemini Live setup; keep the SIP call open.',
        );
      });
      try {
        client = await GeminiLiveClient.connect(
          settings,
          logTag: _tag,
          logger: logger,
        );
      } finally {
        setupWaitLog.cancel();
      }
      if (session.media.isClosed) {
        logger.info(
          '$_tag Gemini Live setup completed after the SIP call ended.',
        );
        return;
      }
      logger.info('$_tag Gemini Live setup complete.');

      tasks = <Future<void>>[
        _pumpSipAudioToGemini(client),
        _pumpGeminiEventsToSip(client),
      ];
      final initialPrompt = settings.initialPrompt.trim();
      if (initialPrompt.isNotEmpty) {
        await client.sendRealtimeText(initialPrompt);
      }
      await Future.any(<Future<void>>[...tasks, session.media.closed]);
      if (session.media.isClosed) {
        logger.info('$_tag SIP media closed; ending Gemini Live session.');
      }
    } catch (error, stackTrace) {
      if (session.media.isClosed || _isExpectedSipMediaClosure(error)) {
        logger.info('$_tag SIP media closed; ending Gemini Live session.');
      } else {
        logger.error('$_tag bridge error: $error');
        if (!isExpectedGeminiSetupFailure(error)) {
          logger.error(stackTrace.toString());
        }
      }
    } finally {
      await client?.close();
      await Future.wait(tasks.map((task) => task.catchError((_) {})));
      logger.info('$_tag media bridge stopped.');
    }
  }

  void _startLocalJingle() {
    final duration = settings.startupJingleDuration;
    if (duration <= Duration.zero) {
      return;
    }
    unawaited(_playLocalJingle(duration));
  }

  Future<void> _playLocalJingle(Duration duration) async {
    await Future.any<void>([
      Future<void>.delayed(const Duration(milliseconds: 150)),
      session.media.closed,
    ]);
    if (session.media.isClosed) {
      return;
    }

    logger.info(
      '$_tag playing local startup jingle for ${duration.inSeconds}s.',
    );
    await session.media.playAudioBytes(buildStartupJingle(duration)).catchError(
      (Object error, StackTrace stackTrace) {
        if (!session.media.isClosed) {
          logger.error('$_tag startup jingle failed: $error');
          logger.error(stackTrace.toString());
        }
      },
    );
  }

  Future<void> _pumpSipAudioToGemini(GeminiLiveClient client) async {
    try {
      await for (final frame in session.media.incomingFrames()) {
        try {
          if (!_loggedFirstSipAudioFrame) {
            _loggedFirstSipAudioFrame = true;
            logger.info('$_tag receiving SIP audio.');
          }
          await client.sendRealtimeAudio(frame.bytes);
        } finally {
          frame.dispose();
        }
      }
    } finally {
      await client.endAudioInput();
    }
  }

  Future<void> _pumpGeminiEventsToSip(GeminiLiveClient client) async {
    await for (final message in client.messages) {
      if (session.media.isClosed) {
        break;
      }
      switch (message) {
        case genai.BidiGenerateContentSetupComplete(:final sessionId):
          logger.info(
            '$_tag Gemini setupComplete received'
            '${sessionId == null ? '' : ' (sessionId=$sessionId)'}.',
          );

        case genai.BidiGenerateContentServerContent():
          await _handleServerContent(message);

        case genai.GoAway(:final timeLeft):
          logger.info('$_tag Gemini goAway received: timeLeft=$timeLeft');

        case genai.SessionResumptionUpdate(:final newHandle, :final resumable):
          logger.info(
            '$_tag Gemini session resumption update: resumable=$resumable, '
            'handle=${newHandle == null ? 'none' : 'received'}.',
          );

        case genai.BidiGenerateContentToolCall(:final functionCalls):
          logger.info(
            '$_tag Gemini requested ${functionCalls.length} tool call(s), '
            'but Callo Engine has no tools configured.',
          );

        case genai.BidiGenerateContentToolCallCancellation(:final ids):
          logger.info('$_tag Gemini cancelled tool calls: ${ids.length}.');

        case genai.UnknownServerMessage(:final rawJson):
          logger.info(
            '$_tag unknown Gemini Live message keys: ${rawJson.keys}.',
          );
      }
    }
  }

  bool _isExpectedSipMediaClosure(Object error) {
    return switch (error) {
      StateError(:final message) =>
        message == 'The SIP realtime media session has already been closed.' ||
            message == 'No SIP media app is attached to this call.',
      _ => false,
    };
  }

  Future<void> _handleServerContent(
    genai.BidiGenerateContentServerContent serverContent,
  ) async {
    final inputText = serverContent.inputTranscription?.text;
    if (inputText != null && inputText.trim().isNotEmpty) {
      logger.info('$_tag caller: ${inputText.trim()}');
    }

    final outputText = serverContent.outputTranscription?.text;
    if (outputText != null && outputText.trim().isNotEmpty) {
      logger.info('$_tag model: ${outputText.trim()}');
    }

    if (serverContent.interrupted == true) {
      logger.info('$_tag Gemini interrupted current response.');
      if (!session.media.isClosed) {
        await session.media.clearPlaybackQueue();
      }
    }

    if (serverContent.turnComplete == true) {
      logger.info('$_tag Gemini turn complete.');
    }
    if (serverContent.generationComplete == true) {
      logger.info('$_tag Gemini generation complete.');
    }

    final parts = serverContent.modelTurn?.parts;
    if (parts == null || parts.isEmpty) {
      return;
    }

    for (final part in parts) {
      switch (part) {
        case genai.TextPart(:final text):
          if (text.trim().isNotEmpty) {
            logger.info('$_tag text: ${text.trim()}');
          }

        case genai.InlineDataPart(:final inlineData):
          await _handleInlineData(inlineData);

        default:
          logger.info('$_tag ignoring Gemini part type ${part.runtimeType}.');
      }
    }
  }

  Future<void> _handleInlineData(genai.Blob inlineData) async {
    final mimeType = inlineData.mimeType;
    if (!mimeType.startsWith('audio/pcm')) {
      logger.info('$_tag ignoring Gemini inline data mimeType=$mimeType.');
      return;
    }

    final decoded = Uint8List.fromList(inlineData.toBytes());
    final sampleRateHz = audioRateFromMimeType(mimeType) ?? 24000;
    final playbackBytes = switch (sampleRateHz) {
      16000 => decoded,
      24000 => _downsampler.convert(decoded),
      _ => Uint8List(0),
    };
    if (playbackBytes.isEmpty) {
      if (sampleRateHz != 16000 && sampleRateHz != 24000) {
        logger.error(
          '$_tag ignoring Gemini audio chunk with unsupported rate '
          '$sampleRateHz Hz ($mimeType).',
        );
      }
      return;
    }

    if (!session.media.isClosed) {
      if (!_loggedFirstGeminiAudioChunk) {
        _loggedFirstGeminiAudioChunk = true;
        logger.info('$_tag playing Gemini audio.');
      }
      await session.media.playAudioBytes(playbackBytes);
    }
  }
}
