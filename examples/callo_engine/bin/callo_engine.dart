import 'dart:async';
import 'dart:io';

import 'package:callo_engine/callo_engine.dart';

Future<void> main(List<String> arguments) async {
  final options = _CliOptions.parse(arguments);
  if (options.help) {
    stdout.write(_usage);
    return;
  }

  final logger = CalloLogger(info: _log, error: _logError);
  final config = CalloEngineConfig.fromEnvironment(
    Platform.environment,
    geminiApiKey: options.geminiApiKey,
  );
  final engine = CalloEngine(config: config, logger: logger);
  final subscription = engine.events.listen(
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
    await engine.start();
    _printStartupBanner(config);

    await shutdownSignal.future;
    stdout.writeln('');
    _log('Stopping Callo Engine...');
  } finally {
    for (final signalSubscription in signalSubscriptions) {
      await signalSubscription.cancel();
    }
    await subscription.cancel();
    await engine.dispose();
  }
}

void _printStartupBanner(CalloEngineConfig config) {
  stdout.writeln('Callo Engine is connected to the SIP trunk.');
  stdout.writeln('Model: ${config.gemini.model}');
  stdout.writeln('Voice: ${config.gemini.voiceName}');
  stdout.writeln(
    'SIP trunk: ${config.trunkId} -> ${config.trunkServerUri} '
    '(realm ${config.trunkRealm}, user ${config.trunkUsername})',
  );
  stdout.writeln(
    'Local SIP listener: ${config.bindHost}:${config.bindPort} '
    '(registrar disabled)',
  );
  stdout.writeln(
    'Advertised SIP/RTP address: '
    '${config.externalAddress ?? 'auto/PJSIP default'}',
  );
  stdout.writeln(
    'Inbound calls from the trunk route to assistant user '
    '${config.assistantUser}.',
  );
  stdout.writeln(
    'Set CALLO_ASSISTANT_USER=* if the trunk delivers calls to phone numbers.',
  );
  stdout.writeln('RTP port range: ${config.rtpStartPort}-${config.rtpEndPort}');
  stdout.writeln(
    'Startup jingle: ${config.gemini.startupJingleDuration.inSeconds}s',
  );
  stdout.writeln('Gemini client: googleai_dart Live API');
}

void _log(String message) {
  stdout.writeln('${DateTime.now().toIso8601String()} $message');
}

void _logError(String message) {
  stderr.writeln('${DateTime.now().toIso8601String()} $message');
}

final class _CliOptions {
  const _CliOptions({required this.help, this.geminiApiKey});

  factory _CliOptions.parse(List<String> arguments) {
    var help = false;
    String? geminiApiKey;

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      switch (argument) {
        case '-h' || '--help':
          help = true;
        case '--gemini-api-key' || '--api-key':
          index += 1;
          if (index >= arguments.length) {
            throw StateError('$argument requires a value.');
          }
          geminiApiKey = arguments[index];
        case String() when argument.startsWith('--gemini-api-key='):
          geminiApiKey = argument.substring('--gemini-api-key='.length);
        case String() when argument.startsWith('--api-key='):
          geminiApiKey = argument.substring('--api-key='.length);
        default:
          throw StateError('Unknown argument: $argument\n\n$_usage');
      }
    }

    return _CliOptions(help: help, geminiApiKey: geminiApiKey);
  }

  final bool help;
  final String? geminiApiKey;
}

const _usage = '''
Callo Engine

Start:
  dart run bin/callo_engine.dart --gemini-api-key YOUR_KEY

Environment alternative:
  GEMINI_API_KEY=YOUR_KEY \
  SIP_TRUNK_USERNAME=YOUR_SIP_USERNAME \
  SIP_TRUNK_PASSWORD=YOUR_SIP_PASSWORD \
  dart run bin/callo_engine.dart

Options:
  --gemini-api-key, --api-key  Gemini API key used for Live API sessions.
  -h, --help                   Print this help.

Common environment variables:
  GEMINI_LIVE_MODEL
  GEMINI_VOICE_NAME
  CALLO_SYSTEM_PROMPT
  CALLO_INITIAL_PROMPT
  CALLO_JINGLE_SECONDS
  CALLO_ASSISTANT_USER
  SIP_BIND_HOST
  SIP_BIND_PORT
  SIP_PUBLIC_ADDRESS
  SIP_TRUNK_ID
  SIP_TRUNK_SERVER_URI
  SIP_TRUNK_USERNAME
  SIP_TRUNK_PASSWORD
  SIP_TRUNK_REALM
  SIP_RTP_START_PORT
  SIP_RTP_END_PORT
  SIP_EXTERNAL_ADDRESS
''';
