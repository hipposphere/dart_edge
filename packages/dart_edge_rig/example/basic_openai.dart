import 'dart:io';

import 'package:dart_edge_rig/dart_edge_rig.dart';

Future<void> main() async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set OPENAI_API_KEY to run this example.');
    exitCode = 64;
    return;
  }

  final agent = await RigAgent.openAiResponses(
    model: 'gpt-4o-mini',
    apiKey: apiKey,
    preamble: 'Answer in one short paragraph.',
  );

  try {
    final result = await agent.prompt(
      const RigPrompt(<RigPromptMessage>[
        RigPromptMessage.user(<RigUserContent>[
          RigUserContent.text('Explain Rig for a Dart developer.'),
        ]),
      ]),
    );
    print(result.output);
  } finally {
    agent.dispose();
  }
}
