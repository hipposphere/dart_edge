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
  stdout.writeln('Callo Engine is listening.');
  stdout.writeln('Model: ${config.gemini.model}');
  stdout.writeln('Voice: ${config.gemini.voiceName}');
  stdout.writeln('Direct SIP test URI: ${config.directSipUri}');
  stdout.writeln(
    'Registrar: ${config.testHost}:${config.bindPort} '
    '(realm ${config.realm})',
  );
  stdout.writeln('Advertised SIP/RTP address: ${config.externalAddress}');
  stdout.writeln(
    'Test endpoint: ${config.testUsername} / ${config.testPassword}',
  );
  stdout.writeln(
    'Registered endpoint call URI: ${config.registeredAssistantUri}',
  );
  stdout.writeln('Linphone registration settings:');
  stdout.writeln('  Username / User ID: ${config.testUsername}');
  stdout.writeln('  Password: ${config.testPassword}');
  stdout.writeln('  Domain / Realm: ${config.realm}');
  stdout.writeln(
    '  SIP address / Identity: sip:${config.testUsername}@${config.realm}',
  );
  stdout.writeln(
    '  Proxy / Registrar / Server: sip:${config.testHost}:${config.bindPort}',
  );
  stdout.writeln('  Transport: UDP');
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
  GEMINI_API_KEY=YOUR_KEY dart run bin/callo_engine.dart

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
  SIP_TEST_HOST
  SIP_REALM
  SIP_TEST_USERNAME
  SIP_TEST_PASSWORD
  SIP_RTP_START_PORT
  SIP_RTP_END_PORT
  SIP_EXTERNAL_ADDRESS
''';
