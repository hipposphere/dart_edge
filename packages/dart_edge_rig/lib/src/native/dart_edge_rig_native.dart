import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;
import 'package:ffi/ffi.dart';

import '../rig_agent_config.dart';
import '../rig_prompt_message.dart';
import '../rig_provider_api_config.dart';
import '../rig_stream_event.dart';
import '../rig_token_usage.dart';
import '../rig_tool.dart';
import 'generated_bindings.dart' as gen;

const _streamEventText = 1;
const _streamEventReasoning = 2;
const _streamEventToolCall = 3;
const _streamEventToolCallDelta = 4;
const _streamEventToolResult = 5;
const _streamEventFinal = 6;
const _streamEventToolExecuteRequest = 7;

final _streamIdRandom = Random.secure();
var _nextStreamCounter = 0;

/// Native handle and metadata for an opened Rig agent.
final class NativeRigAgent {
  /// Creates native Rig agent metadata.
  const NativeRigAgent({required this.handle, required this.name});

  /// Native handle used for subsequent calls.
  final int handle;

  /// Native agent name.
  final String name;
}

/// Low-level FFI wrapper for the dart_edge_rig native asset.
abstract final class DartEdgeRigNative {
  /// Native ABI version exposed by this package.
  static int get abiVersion => gen.dart_edge_rig_native_abi_version();

  /// Creates a native Rig agent.
  static NativeRigAgent create(RigAgentConfig config) {
    final allocations = core_ffi.NativeAllocations();
    final configPtr = calloc<gen.NativeRigAgentConfig>();

    try {
      final nativeHeaders = _writeStringPairs(config.headers, allocations);
      final nativeTools = _writeTools(config.tools, allocations);
      configPtr.ref
        ..provider = allocations.requiredString(config.provider)
        ..api = allocations.requiredString(config.api)
        ..model = allocations.requiredString(config.model)
        ..api_key = allocations.optionalString(config.apiKey)
        ..base_url = allocations.optionalString(config.baseUrl)
        ..preamble = allocations.optionalString(config.preamble)
        ..name = allocations.optionalString(config.name)
        ..has_temperature = config.temperature != null
        ..temperature = config.temperature ?? 0
        ..has_max_tokens = config.maxTokens != null
        ..max_tokens = config.maxTokens ?? 0
        ..max_turns = config.maxTurns ?? -1
        ..output_schema_json = allocations.optionalString(
          _outputSchemaJson(config),
        )
        ..additional_params_json = allocations.optionalString(
          additionalParamsJson(config),
        )
        ..tools = nativeTools.pointer
        ..tools_len = nativeTools.length
        ..headers = nativeHeaders.pointer
        ..headers_len = nativeHeaders.length;

      final resultPtr = gen.dart_edge_rig_create_agent(configPtr);
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_rig create returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        if (result.handle <= 0) {
          throw StateError('dart_edge_rig create returned no handle.');
        }
        return NativeRigAgent(
          handle: result.handle,
          name:
              core_ffi.optionalNativeString(result.name) ??
              config.name ??
              '${config.provider}.${config.api}.${config.model}',
        );
      } finally {
        gen.dart_edge_rig_free_handle_result(resultPtr);
      }
    } finally {
      calloc.free(configPtr);
      allocations.free();
    }
  }

  /// Serializes provider-specific typed config for the native Rig bridge.
  static String? additionalParamsJson(RigAgentConfig config) {
    return rigAdditionalParamsJson(
      provider: config.provider,
      api: config.api,
      openAiResponses: config.openAiResponses,
      openAiCompletions: config.openAiCompletions,
      geminiInteractions: config.geminiInteractions,
      geminiGenerateContent: config.geminiGenerateContent,
    );
  }

  /// Sends rich user content to a native Rig agent.
  static String promptContent(int handle, RigPrompt prompt) {
    final allocations = core_ffi.NativeAllocations();

    try {
      final resultPtr = gen.dart_edge_rig_agent_prompt_message(
        handle,
        allocations.requiredString(jsonEncode(prompt.toJson())),
      );
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_rig prompt content returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        return core_ffi.requiredNativeString(result.output, 'output');
      } finally {
        gen.dart_edge_rig_free_prompt_result(resultPtr);
      }
    } finally {
      allocations.free();
    }
  }

  /// Streams rich user content to a native Rig agent.
  static Stream<RigStreamEvent> streamPromptContent(
    int handle,
    RigPrompt prompt, {
    int? maxTurns,
    List<RigTool> tools = const <RigTool>[],
  }) {
    return _streamPromptMessage(
      handle,
      jsonEncode(prompt.toJson()),
      maxTurns: maxTurns,
      tools: tools,
    );
  }

  static Stream<RigStreamEvent> _streamPromptMessage(
    int handle,
    String promptMessageJson, {
    int? maxTurns,
    List<RigTool> tools = const <RigTool>[],
  }) {
    late final StreamController<RigStreamEvent> controller;
    NativeCallable<Void Function(Int64, Pointer<gen.NativeRigStreamEvent>)>?
    callback;
    var canceled = false;
    final streamId = _newStreamId();

    controller = StreamController<RigStreamEvent>(
      onListen: () {
        callback = NativeCallable.listener((
          int nativeStreamId,
          Pointer<gen.NativeRigStreamEvent> event,
        ) {
          if (event == nullptr) {
            return;
          }
          try {
            if (nativeStreamId != streamId) {
              return;
            }
            if (canceled || controller.isClosed) {
              return;
            }
            final streamEvent = _readStreamEvent(event.ref);
            if (streamEvent case final _NativeToolExecuteRequest request) {
              _executeTool(request, tools);
            } else {
              controller.add(streamEvent);
            }
          } catch (error, stackTrace) {
            controller.addError(error, stackTrace);
          } finally {
            gen.dart_edge_rig_free_stream_event(event);
          }
        });

        final callbackAddress = callback!.nativeFunction.address;
        final invocation = _StreamPromptInvocation(
          handle: handle,
          prompt: promptMessageJson,
          maxTurns: maxTurns ?? -1,
          callbackAddress: callbackAddress,
          streamId: streamId,
        );
        Isolate.run(invocation.run)
            .catchError((Object error, StackTrace stackTrace) {
              if (!canceled && !controller.isClosed) {
                controller.addError(error, stackTrace);
              }
              return '';
            })
            .whenComplete(() {
              callback?.close();
              callback = null;
              if (!controller.isClosed) {
                controller.close();
              }
            });
      },
      onCancel: () {
        canceled = true;
        cancelStream(streamId);
      },
    );

    return controller.stream;
  }

  static String _streamPromptMessageBlocking(
    int handle,
    String promptMessageJson,
    int maxTurns,
    int callbackAddress,
    int streamId,
  ) {
    final allocations = core_ffi.NativeAllocations();
    final optionsPtr = calloc<gen.NativeRigStreamOptions>();

    try {
      optionsPtr.ref.max_turns = maxTurns;
      final resultPtr = gen.dart_edge_rig_agent_stream_prompt_message(
        handle,
        allocations.requiredString(promptMessageJson),
        optionsPtr,
        Pointer.fromAddress(callbackAddress),
        streamId,
      );
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_rig stream prompt content returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        return core_ffi.requiredNativeString(result.output, 'output');
      } finally {
        gen.dart_edge_rig_free_prompt_result(resultPtr);
      }
    } finally {
      calloc.free(optionsPtr);
      allocations.free();
    }
  }

  /// Releases a native Rig handle.
  static void dispose(int handle) {
    gen.dart_edge_rig_dispose_handle(handle);
  }

  /// Cancels an active native stream run.
  static void cancelStream(int streamId) {
    gen.dart_edge_rig_cancel_stream(streamId);
  }

  static core_ffi.NativeStringPairs<gen.NativeRigToolDefinition> _writeTools(
    List<RigTool> tools,
    core_ffi.NativeAllocations allocations,
  ) {
    if (tools.isEmpty) {
      return core_ffi.NativeStringPairs(pointer: nullptr, length: 0);
    }

    final pointer = calloc<gen.NativeRigToolDefinition>(tools.length);
    for (var index = 0; index < tools.length; index += 1) {
      final tool = tools[index];
      (pointer + index).ref
        ..name = allocations.requiredString(tool.name)
        ..description = allocations.requiredString(tool.description)
        ..parameters_json = allocations.requiredString(
          jsonEncode(tool.parameters.toJson()),
        );
    }

    return allocations.trackStringPairs(pointer, tools.length);
  }

  static core_ffi.NativeStringPairs<gen.NativeRigStringPair> _writeStringPairs(
    Map<String, String> values,
    core_ffi.NativeAllocations allocations,
  ) {
    if (values.isEmpty) {
      return core_ffi.NativeStringPairs(pointer: nullptr, length: 0);
    }

    final pointer = calloc<gen.NativeRigStringPair>(values.length);
    var index = 0;
    for (final MapEntry(:key, :value) in values.entries) {
      (pointer + index).ref
        ..key = allocations.requiredString(key)
        ..value = allocations.requiredString(value);
      index += 1;
    }

    return allocations.trackStringPairs(pointer, values.length);
  }

  static String? _outputSchemaJson(RigAgentConfig config) {
    return config.outputSchemaJson ??
        switch (config.outputSchema) {
          final schema? => jsonEncode(schema.toJson()),
          null => null,
        };
  }

  static void _throwIfError(Pointer<Char> error) {
    if (error != nullptr) {
      throw StateError(error.cast<Utf8>().toDartString());
    }
  }

  static RigStreamEvent _readStreamEvent(gen.NativeRigStreamEvent event) {
    final text = core_ffi.optionalNativeString(event.text);
    final id = core_ffi.optionalNativeString(event.id);
    final internalCallId = core_ffi.optionalNativeString(
      event.internal_call_id,
    );
    final name = core_ffi.optionalNativeString(event.name);
    final argumentsJson = core_ffi.optionalNativeString(event.arguments_json);
    final usageJson = core_ffi.optionalNativeString(event.usage_json);

    return switch (event.kind) {
      _streamEventText => RigTextDelta(text ?? ''),
      _streamEventReasoning => RigReasoningDelta(
        text: text ?? '',
        id: id,
        kind: _readReasoningKind(name),
      ),
      _streamEventToolCall => RigToolCallEvent(
        id: id ?? '',
        internalCallId: internalCallId ?? '',
        name: name ?? '',
        argumentsJson: argumentsJson ?? 'null',
      ),
      _streamEventToolCallDelta => RigToolCallDelta(
        id: id ?? '',
        internalCallId: internalCallId ?? '',
        name: name,
        argumentsDelta: text,
      ),
      _streamEventToolResult => RigToolResultEvent(
        internalCallId: internalCallId ?? '',
        resultJson: text ?? 'null',
      ),
      _streamEventFinal => RigFinalResponseEvent(
        text ?? '',
        usage: usageJson == null
            ? null
            : RigTokenUsage.fromJsonString(usageJson),
      ),
      _streamEventToolExecuteRequest => _NativeToolExecuteRequest(
        callSequence: event.call_sequence,
        name: name ?? '',
        argumentsJson: argumentsJson ?? 'null',
      ),
      _ => throw StateError(
        'Unknown dart_edge_rig stream event ${event.kind}.',
      ),
    };
  }

  static RigReasoningKind _readReasoningKind(String? value) {
    return switch (value) {
      'text' => RigReasoningKind.text,
      'summary' => RigReasoningKind.summary,
      'redacted' => RigReasoningKind.redacted,
      'encrypted' => RigReasoningKind.encrypted,
      _ => RigReasoningKind.delta,
    };
  }

  static void _executeTool(
    _NativeToolExecuteRequest request,
    List<RigTool> tools,
  ) {
    final tool = tools.where((tool) => tool.name == request.name).firstOrNull;
    if (tool == null) {
      _completeToolCall(
        request.callSequence,
        error: 'Unknown Dart Rig tool `${request.name}`.',
      );
      return;
    }

    Future<void>(() async {
      try {
        final result = await tool.call(jsonDecode(request.argumentsJson));
        final resultText = jsonEncode(_normalizeToolResult(result));
        _completeToolCall(request.callSequence, result: resultText);
      } catch (error) {
        _completeToolCall(request.callSequence, error: error.toString());
      }
    });
  }

  static Object? _normalizeToolResult(Object? result) {
    return switch (result) {
      null => <String, Object?>{'value': null},
      final Map<Object?, Object?> value => <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      },
      final String value => <String, Object?>{'content': value},
      final Iterable<Object?> value => <String, Object?>{
        'items': value.toList(),
      },
      _ => <String, Object?>{'value': result},
    };
  }

  static void _completeToolCall(
    int callSequence, {
    String? result,
    String? error,
  }) {
    final allocations = core_ffi.NativeAllocations();
    try {
      gen.dart_edge_rig_complete_tool_call(
        callSequence,
        allocations.optionalString(result),
        allocations.optionalString(error),
      );
    } finally {
      allocations.free();
    }
  }
}

int _newStreamId() {
  _nextStreamCounter = (_nextStreamCounter + 1) & 0xFFFFF;
  final time = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
  final random = _streamIdRandom.nextInt(0x7FFFFFFF);
  return ((time << 32) ^ (random << 1) ^ _nextStreamCounter) &
      0x7FFFFFFFFFFFFFFF;
}

final class _NativeToolExecuteRequest extends RigStreamEvent {
  const _NativeToolExecuteRequest({
    required this.callSequence,
    required this.name,
    required this.argumentsJson,
  });

  final int callSequence;
  final String name;
  final String argumentsJson;
}

final class _StreamPromptInvocation {
  const _StreamPromptInvocation({
    required this.handle,
    required this.prompt,
    required this.maxTurns,
    required this.callbackAddress,
    required this.streamId,
  });

  final int handle;
  final String prompt;
  final int maxTurns;
  final int callbackAddress;
  final int streamId;

  String run() {
    return DartEdgeRigNative._streamPromptMessageBlocking(
      handle,
      prompt,
      maxTurns,
      callbackAddress,
      streamId,
    );
  }
}
