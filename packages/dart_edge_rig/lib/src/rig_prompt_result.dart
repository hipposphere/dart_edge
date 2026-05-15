import 'dart:convert';

/// Text completion produced by a Rig agent.
final class RigPromptResult {
  /// Creates a text completion result.
  const RigPromptResult({required this.output});

  /// Model output returned by Rig.
  final String output;

  /// Decodes [output] as JSON.
  Object? decodeJson() => jsonDecode(output);
}
