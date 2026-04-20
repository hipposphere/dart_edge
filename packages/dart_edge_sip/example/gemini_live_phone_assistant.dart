import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:googleai_dart/googleai_dart.dart' as genai;

void _log(String message) {
  stdout.writeln('${DateTime.now().toIso8601String()} $message');
}

void _logError(String message) {
  stderr.writeln('${DateTime.now().toIso8601String()} $message');
}

Future<void> main() async {
  final settings = _ExampleSettings.fromEnvironment(Platform.environment);
  final assistant = _GeminiLivePhoneAssistant(settings.gemini);
  final sip = DartEdgeSip(
    config: settings.sipConfig,
    dialplan: _InboundAssistantDialplan(
      assistantUser: settings.assistantUser,
      mediaAppId: assistant.id,
    ),
    mediaApps: [assistant],
  );

  final subscription = sip.events.listen(
    (event) {
      _log('[sip] $event');
    },
    onError: (Object error, StackTrace stackTrace) {
      _logError('[sip:error] $error');
      _logError(stackTrace.toString());
    },
  );

  final shutdownSignal = Completer<ProcessSignal>();
  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen((signal) {
      if (!shutdownSignal.isCompleted) {
        shutdownSignal.complete(signal);
      }
    }),
    ProcessSignal.sigterm.watch().listen((signal) {
      if (!shutdownSignal.isCompleted) {
        shutdownSignal.complete(signal);
      }
    }),
  ];

  try {
    await sip.start();
    _printStartupBanner(settings);

    await shutdownSignal.future;
    stdout.writeln('');
    _log('Stopping Gemini Live phone assistant...');
  } finally {
    for (final signalSubscription in signalSubscriptions) {
      await signalSubscription.cancel();
    }
    await subscription.cancel();
    await sip.dispose();
  }
}

void _printStartupBanner(_ExampleSettings settings) {
  stdout.writeln('Gemini Live phone assistant is listening.');
  stdout.writeln('Model: ${settings.gemini.model}');
  stdout.writeln('Voice: ${settings.gemini.voiceName}');
  stdout.writeln(
    'Direct SIP test URI: sip:${settings.assistantUser}@'
    '${settings.testHost}:${settings.bindPort}',
  );
  stdout.writeln(
    'Registrar: ${settings.testHost}:${settings.bindPort} '
    '(realm ${settings.realm})',
  );
  stdout.writeln('Advertised SIP/RTP address: ${settings.externalAddress}');
  stdout.writeln(
    'Test endpoint: ${settings.testUsername} / '
    '${settings.testPassword}',
  );
  stdout.writeln(
    'Registered endpoint call URI: sip:${settings.assistantUser}@'
    '${settings.realm}',
  );
  stdout.writeln('Linphone registration settings:');
  stdout.writeln('  Username / User ID: ${settings.testUsername}');
  stdout.writeln('  Password: ${settings.testPassword}');
  stdout.writeln('  Domain / Realm: ${settings.realm}');
  stdout.writeln(
    '  SIP address / Identity: sip:${settings.testUsername}@${settings.realm}',
  );
  stdout.writeln(
    '  Proxy / Registrar / Server: sip:${settings.testHost}:'
    '${settings.bindPort}',
  );
  stdout.writeln('  Transport: UDP');
  stdout.writeln(
    'RTP port range: ${settings.rtpStartPort}-${settings.rtpEndPort}',
  );
  stdout.writeln(
    'Startup jingle: ${settings.gemini.startupJingleDuration.inSeconds}s',
  );
  stdout.writeln('Gemini client: googleai_dart Live API');
  stdout.writeln('Press Ctrl-C to stop.');
}

final class _ExampleSettings {
  const _ExampleSettings({
    required this.bindHost,
    required this.bindPort,
    required this.testHost,
    required this.realm,
    required this.assistantUser,
    required this.testEndpointId,
    required this.testExtension,
    required this.testUsername,
    required this.testPassword,
    required this.rtpStartPort,
    required this.rtpEndPort,
    required this.externalAddress,
    required this.gemini,
  });

  factory _ExampleSettings.fromEnvironment(Map<String, String> env) {
    final apiKey = env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Missing GEMINI_API_KEY. See example/README.md for the required '
        'environment variables.',
      );
    }

    final bindHost = env['SIP_BIND_HOST'] ?? '0.0.0.0';
    final bindPort = _parsePort(env['SIP_BIND_PORT'], fallback: 5060);
    final testHost = env['SIP_TEST_HOST'] ?? '127.0.0.1';
    final testExtension = env['SIP_TEST_EXTENSION'] ?? '1000';
    final rtpStartPort = _parsePort(env['SIP_RTP_START_PORT'], fallback: 40000);
    final rtpEndPort = _parsePort(env['SIP_RTP_END_PORT'], fallback: 40100);
    final startupJingleDuration = Duration(
      seconds: _parseNonNegativeInt(
        env['PHONE_ASSISTANT_JINGLE_SECONDS'],
        fallback: 3,
        name: 'PHONE_ASSISTANT_JINGLE_SECONDS',
      ),
    );
    final externalAddress = switch (env['SIP_EXTERNAL_ADDRESS']) {
      final value? when value.isNotEmpty => value,
      _ => testHost,
    };

    return _ExampleSettings(
      bindHost: bindHost,
      bindPort: bindPort,
      testHost: testHost,
      realm: env['SIP_REALM'] ?? testHost,
      assistantUser: env['SIP_ASSISTANT_USER'] ?? 'assistant',
      testEndpointId: env['SIP_TEST_ENDPOINT_ID'] ?? 'test-phone',
      testExtension: testExtension,
      testUsername: env['SIP_TEST_USERNAME'] ?? testExtension,
      testPassword: env['SIP_TEST_PASSWORD'] ?? 'change-me',
      rtpStartPort: rtpStartPort,
      rtpEndPort: rtpEndPort,
      externalAddress: externalAddress,
      gemini: _GeminiLiveSettings(
        apiKey: apiKey,
        model: env['GEMINI_LIVE_MODEL'] ?? 'gemini-3.1-flash-live-preview',
        voiceName: env['GEMINI_VOICE_NAME'] ?? 'Kore',
        startupJingleDuration: startupJingleDuration,
        initialPrompt:
            env['PHONE_ASSISTANT_INITIAL_PROMPT'] ??
            'Greet the caller in one short sentence and ask how you can help.',
        systemPrompt:
            env['PHONE_ASSISTANT_SYSTEM_PROMPT'] ??
            'You are a concise, helpful phone assistant. Keep answers short, '
                'speak naturally, ask follow-up questions only when needed, '
                'and avoid markdown or bullet lists because the user hears '
                'your response over the phone.',
      ),
    );
  }

  final String bindHost;
  final int bindPort;
  final String testHost;
  final String realm;
  final String assistantUser;
  final String testEndpointId;
  final String testExtension;
  final String testUsername;
  final String testPassword;
  final int rtpStartPort;
  final int rtpEndPort;
  final String? externalAddress;
  final _GeminiLiveSettings gemini;

  SipServerConfig get sipConfig => SipServerConfig(
    serverName: 'dart_edge_sip_gemini_live_example',
    engine: const PjsipEngineConfig(
      licenseMode: SipRuntimeLicenseMode.gpl,
      maxCalls: 4,
      maxConferencePorts: 32,
      enableIce: false,
      enableTurn: false,
      enableSrtp: false,
    ),
    transports: [
      SipTransportBinding.udp(host: bindHost, port: bindPort),
      SipTransportBinding.tcp(host: bindHost, port: bindPort),
    ],
    realms: [SipRealmConfig(domain: realm, realm: realm)],
    endpoints: [
      SipEndpointConfig(
        id: testEndpointId,
        extension: testExtension,
        username: testUsername,
        password: testPassword,
        realm: realm,
        displayName: 'Test phone',
      ),
    ],
    media: SipMediaConfig(
      rtpStartPort: rtpStartPort,
      rtpEndPort: rtpEndPort,
      externalAddress: externalAddress,
    ),
  );
}

int _parsePort(String? value, {required int fallback}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0 || parsed > 65535) {
    throw StateError('Invalid port value: $value');
  }
  return parsed;
}

int _parseNonNegativeInt(
  String? value, {
  required int fallback,
  required String name,
}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw StateError('Invalid $name value: $value');
  }
  return parsed;
}

final class _GeminiLiveSettings {
  const _GeminiLiveSettings({
    required this.apiKey,
    required this.model,
    required this.voiceName,
    required this.startupJingleDuration,
    required this.initialPrompt,
    required this.systemPrompt,
  });

  final String apiKey;
  final String model;
  final String voiceName;
  final Duration startupJingleDuration;
  final String initialPrompt;
  final String systemPrompt;
}

final class _InboundAssistantDialplan implements SipDialplan {
  const _InboundAssistantDialplan({
    required this.assistantUser,
    required this.mediaAppId,
  });

  final String assistantUser;
  final String mediaAppId;

  @override
  FutureOr<SipDialplanDecision> onInboundInvite(SipInboundInvite invite) {
    final invitedUser = _sipUriUser(invite.toUri);
    if (invitedUser != null && invitedUser != assistantUser) {
      return const SipDialplanDecision.reject(
        status: 404,
        reason: 'Unknown assistant extension',
      );
    }
    return SipDialplanDecision.routeToMediaApp(mediaAppId: mediaAppId);
  }

  @override
  FutureOr<SipDialplanDecision> onOutboundCall(SipOutboundCallRequest request) {
    return SipDialplanDecision.routeToTrunk(trunkId: request.trunkId);
  }
}

String? _sipUriUser(String uri) {
  final schemeIndex = uri.indexOf(':');
  final atIndex = uri.indexOf('@');
  if (atIndex <= 0) {
    return null;
  }
  final start = schemeIndex >= 0 ? schemeIndex + 1 : 0;
  if (start >= atIndex) {
    return null;
  }
  return uri.substring(start, atIndex);
}

final class _GeminiLivePhoneAssistant implements SipMediaApp {
  const _GeminiLivePhoneAssistant(this.settings);

  final _GeminiLiveSettings settings;

  @override
  String get id => 'gemini-live-assistant';

  @override
  Future<void> run(SipMediaAppSession session) async {
    final bridge = _GeminiLiveBridge(settings: settings, session: session);
    await bridge.run();
  }
}

final class _GeminiLiveBridge {
  _GeminiLiveBridge({required this.settings, required this.session});

  final _GeminiLiveSettings settings;
  final SipMediaAppSession session;
  final _Pcm24kTo16kDownsampler _downsampler = _Pcm24kTo16kDownsampler();
  bool _loggedFirstSipAudioFrame = false;
  bool _loggedFirstGeminiAudioChunk = false;

  String get _tag => '[assistant/${session.call.id}]';

  Future<void> run() async {
    _log('$_tag connecting to Gemini Live...');
    _startLocalJingle();
    _GeminiLiveClient? client;
    var tasks = <Future<void>>[];

    try {
      final setupWaitLog = Timer(const Duration(seconds: 3), () {
        _log(
          '$_tag still waiting for Gemini Live setup; keep the SIP call open.',
        );
      });
      try {
        client = await _GeminiLiveClient.connect(settings, logTag: _tag);
      } finally {
        setupWaitLog.cancel();
      }
      if (session.media.isClosed) {
        _log('$_tag Gemini Live setup completed after the SIP call ended.');
        return;
      }
      _log('$_tag Gemini Live setup complete.');

      tasks = <Future<void>>[
        _pumpSipAudioToGemini(client),
        _pumpGeminiEventsToSip(client),
      ];
      final initialPrompt = settings.initialPrompt.trim();
      if (initialPrompt.isNotEmpty) {
        await client.sendRealtimeText(initialPrompt);
      }
      await Future.any(<Future<void>>[...tasks, session.media.closed]);
    } catch (error, stackTrace) {
      if (session.media.isClosed) {
        _logError(
          '$_tag Gemini Live setup failed after the SIP call ended: $error',
        );
      } else {
        _logError('$_tag bridge error: $error');
        if (!_isExpectedGeminiSetupFailure(error)) {
          _logError(stackTrace.toString());
        }
      }
    } finally {
      await client?.close();
      await Future.wait(tasks.map((task) => task.catchError((_) {})));
      _log('$_tag media bridge stopped.');
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

    _log('$_tag playing local startup jingle for ${duration.inSeconds}s.');
    await session.media
        .playAudioBytes(_buildStartupJingle(duration))
        .catchError((Object error, StackTrace stackTrace) {
          if (!session.media.isClosed) {
            _logError('$_tag startup jingle failed: $error');
            _logError(stackTrace.toString());
          }
        });
  }

  Future<void> _pumpSipAudioToGemini(_GeminiLiveClient client) async {
    try {
      await for (final frame in session.media.incomingFrames()) {
        try {
          if (!_loggedFirstSipAudioFrame) {
            _loggedFirstSipAudioFrame = true;
            _log('$_tag receiving SIP audio.');
          }
          await client.sendRealtimeAudio(frame.copyBytes());
        } finally {
          frame.dispose();
        }
      }
    } finally {
      await client.endAudioInput();
    }
  }

  Future<void> _pumpGeminiEventsToSip(_GeminiLiveClient client) async {
    await for (final message in client.messages) {
      switch (message) {
        case genai.BidiGenerateContentSetupComplete(:final sessionId):
          _log(
            '$_tag Gemini setupComplete received'
            '${sessionId == null ? '' : ' (sessionId=$sessionId)'}.',
          );

        case genai.BidiGenerateContentServerContent():
          await _handleServerContent(message);

        case genai.GoAway(:final timeLeft):
          _log('$_tag Gemini goAway received: timeLeft=$timeLeft');

        case genai.SessionResumptionUpdate(:final newHandle, :final resumable):
          _log(
            '$_tag Gemini session resumption update: resumable=$resumable, '
            'handle=${newHandle == null ? 'none' : 'received'}.',
          );

        case genai.BidiGenerateContentToolCall(:final functionCalls):
          _log(
            '$_tag Gemini requested ${functionCalls.length} tool call(s), '
            'but this example has no tools configured.',
          );

        case genai.BidiGenerateContentToolCallCancellation(:final ids):
          _log('$_tag Gemini cancelled tool calls: ${ids.length}.');

        case genai.UnknownServerMessage(:final rawJson):
          _log('$_tag unknown Gemini Live message keys: ${rawJson.keys}.');
      }
    }
  }

  Future<void> _handleServerContent(
    genai.BidiGenerateContentServerContent serverContent,
  ) async {
    final inputText = serverContent.inputTranscription?.text;
    if (inputText != null && inputText.trim().isNotEmpty) {
      _log('$_tag caller: ${inputText.trim()}');
    }

    final outputText = serverContent.outputTranscription?.text;
    if (outputText != null && outputText.trim().isNotEmpty) {
      _log('$_tag model: ${outputText.trim()}');
    }

    if (serverContent.interrupted == true) {
      _log('$_tag Gemini interrupted current response.');
      if (!session.media.isClosed) {
        await session.media.clearPlaybackQueue();
      }
    }

    if (serverContent.turnComplete == true) {
      _log('$_tag Gemini turn complete.');
    }
    if (serverContent.generationComplete == true) {
      _log('$_tag Gemini generation complete.');
    }

    final parts = serverContent.modelTurn?.parts;
    if (parts == null || parts.isEmpty) {
      return;
    }

    for (final part in parts) {
      switch (part) {
        case genai.TextPart(:final text):
          if (text.trim().isNotEmpty) {
            _log('$_tag text: ${text.trim()}');
          }

        case genai.InlineDataPart(:final inlineData):
          await _handleInlineData(inlineData);

        default:
          _log('$_tag ignoring Gemini part type ${part.runtimeType}.');
      }
    }
  }

  Future<void> _handleInlineData(genai.Blob inlineData) async {
    final mimeType = inlineData.mimeType;
    if (!mimeType.startsWith('audio/pcm')) {
      _log('$_tag ignoring Gemini inline data mimeType=$mimeType.');
      return;
    }

    final decoded = Uint8List.fromList(inlineData.toBytes());
    final sampleRateHz = _audioRateFromMimeType(mimeType) ?? 24000;
    final playbackBytes = switch (sampleRateHz) {
      16000 => decoded,
      24000 => _downsampler.convert(decoded),
      _ => Uint8List(0),
    };
    if (playbackBytes.isEmpty) {
      if (sampleRateHz != 16000 && sampleRateHz != 24000) {
        _logError(
          '$_tag ignoring Gemini audio chunk with unsupported rate '
          '$sampleRateHz Hz ($mimeType).',
        );
      }
      return;
    }

    if (!session.media.isClosed) {
      if (!_loggedFirstGeminiAudioChunk) {
        _loggedFirstGeminiAudioChunk = true;
        _log('$_tag playing Gemini audio.');
      }
      await session.media.playAudioBytes(playbackBytes);
    }
  }
}

final class _GeminiLiveClient {
  _GeminiLiveClient._({
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

  static Future<_GeminiLiveClient> connect(
    _GeminiLiveSettings settings, {
    required String logTag,
  }) async {
    final client = genai.GoogleAIClient(
      config: genai.GoogleAIConfig.googleAI(
        apiVersion: genai.ApiVersion.v1beta,
        authProvider: genai.ApiKeyProvider(settings.apiKey),
        timeout: const Duration(seconds: 45),
      ),
    );
    final liveClient = client.createLiveClient();
    final model = _modelId(settings.model);
    final liveConfig = genai.LiveConfig(
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

    _log(
      '$logTag opening Gemini Live SDK session '
      '(sdk=googleai_dart, api=v1beta, model=$model, '
      'voice=${settings.voiceName}).',
    );
    final stopwatch = Stopwatch()..start();

    try {
      final session = await liveClient.connect(
        model: model,
        liveConfig: liveConfig,
      );
      stopwatch.stop();
      _log(
        '$logTag Gemini Live SDK session connected in '
        '${stopwatch.elapsedMilliseconds}ms'
        '${session.sessionId == null ? '' : ' (sessionId=${session.sessionId})'}.',
      );
      return _GeminiLiveClient._(
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

bool _isExpectedGeminiSetupFailure(Object error) {
  final message = error.toString();
  return message.contains('Gemini Live SDK') ||
      message.contains('Live API access') ||
      message.contains('WebSocketConnectionClosed');
}

String _modelId(String model) {
  final trimmed = model.trim();
  if (trimmed.startsWith('models/')) {
    return trimmed.substring('models/'.length);
  }
  return trimmed;
}

Uint8List _buildStartupJingle(Duration duration) {
  const sampleRateHz = 16000;
  const frameFadeSamples = sampleRateHz ~/ 100;
  const amplitude = 0.20 * 32767;
  const notes = <double>[523.25, 659.25, 783.99, 659.25, 587.33, 739.99];
  final sampleCount = sampleRateHz * duration.inMilliseconds ~/ 1000;
  final output = Uint8List(sampleCount * 2);
  final view = ByteData.sublistView(output);

  for (var index = 0; index < sampleCount; index += 1) {
    final seconds = index / sampleRateHz;
    final noteIndex = ((seconds * 4).floor()) % notes.length;
    final frequency = notes[noteIndex];
    final fadeIn = math.min(1.0, index / frameFadeSamples);
    final fadeOut = math.min(1.0, (sampleCount - index - 1) / frameFadeSamples);
    final envelope = math.min(fadeIn, fadeOut);
    final carrier = math.sin(2 * math.pi * frequency * seconds);
    final overtone = 0.18 * math.sin(2 * math.pi * frequency * 2 * seconds);
    final sample = ((carrier + overtone) * amplitude * envelope).round();
    view.setInt16(index * 2, sample.clamp(-32768, 32767), Endian.little);
  }

  return output;
}

final class _Pcm24kTo16kDownsampler {
  final List<int> _pending = <int>[];

  Uint8List convert(Uint8List input) {
    if (input.isEmpty && _pending.isEmpty) {
      return Uint8List(0);
    }

    final combined = Uint8List(_pending.length + input.length)
      ..setAll(0, _pending)
      ..setAll(_pending.length, input);
    final evenLength = combined.length - (combined.length % 2);
    final processLength = (evenLength ~/ 6) * 6;
    if (processLength == 0) {
      _pending
        ..clear()
        ..addAll(combined);
      return Uint8List(0);
    }

    final output = Uint8List((processLength ~/ 6) * 4);
    final inputView = ByteData.sublistView(combined, 0, processLength);
    final outputView = ByteData.sublistView(output);

    var outputOffset = 0;
    for (var inputOffset = 0; inputOffset < processLength; inputOffset += 6) {
      final first = inputView.getInt16(inputOffset, Endian.little);
      final second = inputView.getInt16(inputOffset + 2, Endian.little);
      final third = inputView.getInt16(inputOffset + 4, Endian.little);

      outputView.setInt16(outputOffset, first, Endian.little);
      outputOffset += 2;
      outputView.setInt16(
        outputOffset,
        ((second + third) ~/ 2).clamp(-32768, 32767),
        Endian.little,
      );
      outputOffset += 2;
    }

    _pending
      ..clear()
      ..addAll(combined.sublist(processLength));
    return output;
  }
}

int? _audioRateFromMimeType(String mimeType) {
  final match = RegExp(r'rate=(\d+)').firstMatch(mimeType);
  return match == null ? null : int.tryParse(match.group(1)!);
}
