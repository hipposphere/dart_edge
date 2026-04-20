import 'package:dart_edge_sip/dart_edge_sip.dart';

import '../config/callo_engine_config.dart';
import '../logging/callo_logger.dart';
import '../media/gemini_live_media_app.dart';
import '../sip/assistant_sip_dialplan.dart';

final class CalloEngine {
  CalloEngine({required this.config, CalloLogger? logger})
    : logger = logger ?? CalloLogger.silent,
      _sip = _createSip(config, logger ?? CalloLogger.silent);

  final CalloEngineConfig config;
  final CalloLogger logger;
  final DartEdgeSip _sip;

  Stream<SipEvent> get events => _sip.events;

  bool get isStarted => _sip.isStarted;

  Future<void> start() => _sip.start();

  Future<void> stop() => _sip.stop();

  Future<void> dispose() => _sip.dispose();
}

DartEdgeSip _createSip(CalloEngineConfig config, CalloLogger logger) {
  return DartEdgeSip(
    config: config.sipConfig,
    dialplan: AssistantSipDialplan(
      assistantUser: config.assistantUser,
      mediaAppId: GeminiLiveMediaApp.defaultId,
    ),
    mediaApps: [GeminiLiveMediaApp(config.gemini, logger: logger)],
  );
}
