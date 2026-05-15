import 'dart:async';
import 'dart:io';

import 'package:dart_edge_agent/dart_edge_agent.dart';
import 'package:dart_edge_rig/dart_edge_rig.dart';

Future<void> main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set GEMINI_API_KEY before running this example.');
    exitCode = 64;
    return;
  }

  final workspace = LocalAgentWorkspace(Directory.current);
  final agent = await RigAgent.openGeminiInteractions(
    model:
        Platform.environment['DART_EDGE_AGENT_MODEL'] ??
        'gemini-3-flash-preview',
    apiKey: apiKey,
    preamble: 'You are a concise coding assistant. Use tools when useful.',
    config: const RigGeminiInteractionsConfig(
      thinking: RigGeminiThinking(
        thinkingLevel: RigGeminiThinkingLevel.high,
        thinkingSummaries: RigGeminiThinkingSummaries.auto,
      ),
    ),
    tools: WorkspaceRigTools.all(workspace),
  );

  try {
    final session = AgentSession(
      id: 'example-session',
      runner: RigAgentModelRunner(agent),
      memory: InMemoryAgentMemoryStore(),
    );
    final terminal = _AgentTerminal();

    while (true) {
      final text = terminal.readUserText();
      if (text == null || text == '/exit' || text == '/quit') {
        break;
      }
      if (text.trim().isEmpty) {
        continue;
      }

      final ok = await terminal.streamResponse(
        session.stream(
          RigPrompt(<RigPromptMessage>[
            RigPromptMessage.user(<RigUserContent>[RigUserContent.text(text)]),
          ]),
          maxTurns: 8,
        ),
      );
      if (!ok) {
        exitCode = 1;
        return;
      }
    }
  } finally {
    agent.dispose();
  }
}

final class _AgentTerminal {
  static const _frames = ['-', r'\', '|', '/'];

  final _markdown = _AnsiMarkdownRenderer();
  Timer? _timer;
  var _frame = 0;
  var _status = 'waiting';
  var _answerStarted = false;
  var _lineIsDirty = false;

  String? readUserText() {
    _stopStatus();
    stdout.write('${_Ansi.user}you > ${_Ansi.reset}');
    return stdin.readLineSync();
  }

  Future<bool> streamResponse(Stream<AgentEvent> events) async {
    Object? usage;
    _answerStarted = false;
    _markdown.reset();
    _startStatus('thinking');

    await for (final event in events) {
      switch (event.data) {
        case AgentTextDeltaEventData(:final text):
          _beginAnswer();
          stdout.write(_markdown.render(text));
        case AgentReasoningDeltaEventData(:final text, :final kind):
          _writeThinking(text, kind: kind);
        case AgentToolCallEventData(:final name, :final argumentsJson):
          _writeToolCall(name, argumentsJson);
        case AgentToolCallDeltaEventData():
          _updateStatus('receiving tool call');
        case AgentToolResultEventData(:final internalCallId, :final resultJson):
          _writeToolResult(internalCallId, resultJson);
        case AgentPromptEventData():
          _updateStatus('prompt sent');
        case AgentCompactionEventData(:final summary):
          _writeInfo('compaction', summary ?? '');
        case AgentMemoryEventData(:final value):
          _writeInfo('memory', value.toString());
        case AgentArtifactEventData(:final value):
          _writeInfo('artifact', value.toString());
        case AgentFinalResponseEventData(usage: final finalUsage):
          usage = finalUsage;
        case AgentErrorEventData(:final error):
          _stopStatus();
          stderr.writeln('${_Ansi.error}error${_Ansi.reset} $error');
          return false;
      }
    }

    _stopStatus();
    if (_answerStarted) {
      stdout.write(_markdown.close());
      stdout.writeln();
    }
    _writeUsage(usage);
    return true;
  }

  void _startStatus(String status) {
    _status = status;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (_answerStarted) {
        return;
      }
      stderr.write(
        '\r${_Ansi.status}${_frames[_frame++ % _frames.length]} '
        '$_status${_Ansi.reset}',
      );
      _lineIsDirty = true;
    });
  }

  void _updateStatus(String status) {
    _status = status;
  }

  void _beginAnswer() {
    if (_answerStarted) {
      return;
    }
    _answerStarted = true;
    _clearStatusLine();
    stdout.writeln('${_Ansi.assistant}assistant${_Ansi.reset}');
    stdout.write(_Ansi.response);
  }

  void _writeThinking(String text, {RigReasoningKind? kind}) {
    if (text.isEmpty) {
      return;
    }
    _clearStatusLine();
    final label = switch (kind) {
      RigReasoningKind.summary => 'thinking summary',
      RigReasoningKind.text => 'thinking',
      RigReasoningKind.redacted => 'thinking redacted',
      RigReasoningKind.encrypted => 'thinking encrypted',
      RigReasoningKind.delta || null => 'thinking',
    };
    stderr.writeln('${_Ansi.thinking}$label${_Ansi.reset} $text');
    _updateStatus('thinking');
  }

  void _writeToolCall(String name, String argumentsJson) {
    _clearStatusLine();
    stderr.writeln(
      '${_Ansi.tool}tool${_Ansi.reset} $name '
      '${_Ansi.dim}$argumentsJson${_Ansi.reset}',
    );
    _updateStatus('running tool $name');
  }

  void _writeToolResult(String internalCallId, String resultJson) {
    _clearStatusLine();
    stderr.writeln(
      '${_Ansi.toolResult}tool result${_Ansi.reset} $internalCallId '
      '${_Ansi.dim}$resultJson${_Ansi.reset}',
    );
    _updateStatus('continuing');
  }

  void _writeInfo(String label, String text) {
    if (text.isEmpty) {
      return;
    }
    _clearStatusLine();
    stderr.writeln('${_Ansi.info}$label${_Ansi.reset} $text');
  }

  void _writeUsage(Object? usage) {
    if (usage is! Map) {
      return;
    }
    final reasoningTokens = usage['reasoning_tokens'];
    if (reasoningTokens == null) {
      return;
    }
    stderr.writeln(
      '${_Ansi.info}thinking tokens${_Ansi.reset} $reasoningTokens',
    );
  }

  void _stopStatus() {
    _timer?.cancel();
    _timer = null;
    _clearStatusLine();
  }

  void _clearStatusLine() {
    if (!_lineIsDirty) {
      return;
    }
    stderr.write('\r\x1B[2K');
    _lineIsDirty = false;
  }
}

final class _AnsiMarkdownRenderer {
  var _bold = false;
  var _italic = false;
  var _code = false;

  void reset() {
    _bold = false;
    _italic = false;
    _code = false;
  }

  String render(String input) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < input.length) {
      if (_matches(input, index, '***')) {
        _bold = !_bold;
        _italic = !_italic;
        _style(buffer);
        index += 3;
      } else if (_matches(input, index, '**')) {
        _bold = !_bold;
        _style(buffer);
        index += 2;
      } else if (_matches(input, index, '__')) {
        _bold = !_bold;
        _style(buffer);
        index += 2;
      } else if (input.codeUnitAt(index) == 0x60) {
        _code = !_code;
        _style(buffer);
        index += 1;
      } else if (input.codeUnitAt(index) == 0x2A ||
          input.codeUnitAt(index) == 0x5F) {
        _italic = !_italic;
        _style(buffer);
        index += 1;
      } else {
        buffer.write(input[index]);
        index += 1;
      }
    }
    return buffer.toString();
  }

  String close() {
    reset();
    return _Ansi.reset;
  }

  bool _matches(String value, int index, String pattern) {
    return index + pattern.length <= value.length &&
        value.substring(index, index + pattern.length) == pattern;
  }

  void _style(StringBuffer buffer) {
    buffer.write(_Ansi.reset);
    buffer.write(_Ansi.response);
    if (_bold) {
      buffer.write(_Ansi.bold);
    }
    if (_italic) {
      buffer.write(_Ansi.italic);
    }
    if (_code) {
      buffer.write(_Ansi.inlineCode);
    }
  }
}

abstract final class _Ansi {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const italic = '\x1B[3m';
  static const dim = '\x1B[2m';
  static const user = '\x1B[38;5;45m';
  static const assistant = '\x1B[38;5;82m';
  static const response = '\x1B[38;5;250m';
  static const thinking = '\x1B[38;5;99m';
  static const tool = '\x1B[38;5;214m';
  static const toolResult = '\x1B[38;5;178m';
  static const status = '\x1B[38;5;244m';
  static const info = '\x1B[38;5;111m';
  static const error = '\x1B[38;5;203m';
  static const inlineCode = '\x1B[38;5;108m';
}
