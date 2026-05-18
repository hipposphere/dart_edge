#ifndef DART_EDGE_RIG_H_
#define DART_EDGE_RIG_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct NativeRigStringPair {
  const char* key;
  const char* value;
} NativeRigStringPair;

typedef struct NativeRigToolDefinition {
  const char* name;
  const char* description;
  const char* parameters_json;
} NativeRigToolDefinition;

typedef struct NativeRigModelConfig {
  const char* provider;
  const char* model;
  const char* api_key;
  const char* base_url;
  const char* additional_params_json;
} NativeRigModelConfig;

typedef struct NativeRigTranscriptionRequest {
  const uint8_t* data;
  intptr_t data_len;
  const char* filename;
  const char* language;
  const char* prompt;
  bool has_temperature;
  double temperature;
  const char* additional_params_json;
} NativeRigTranscriptionRequest;

typedef struct NativeRigImageGenerationRequest {
  const char* prompt;
  uint32_t width;
  uint32_t height;
  const char* additional_params_json;
} NativeRigImageGenerationRequest;

typedef struct NativeRigAgentConfig {
  const char* provider;
  const char* api;
  const char* model;
  const char* api_key;
  const char* base_url;
  const char* preamble;
  const char* name;
  bool has_temperature;
  double temperature;
  bool has_max_tokens;
  uint64_t max_tokens;
  intptr_t max_turns;
  const char* output_schema_json;
  const char* additional_params_json;
  const NativeRigToolDefinition* tools;
  intptr_t tools_len;
  const NativeRigStringPair* headers;
  intptr_t headers_len;
} NativeRigAgentConfig;

typedef struct NativeRigStreamOptions {
  intptr_t max_turns;
} NativeRigStreamOptions;

typedef struct NativeRigHandleResult {
  int64_t handle;
  char* name;
  char* error;
} NativeRigHandleResult;

typedef struct NativeRigPromptResult {
  char* output;
  char* error;
} NativeRigPromptResult;

typedef struct NativeRigBytesResult {
  uint8_t* data;
  intptr_t data_len;
  char* error;
} NativeRigBytesResult;

typedef struct NativeRigStreamEvent {
  int32_t kind;
  int64_t call_sequence;
  const char* text;
  const char* id;
  const char* internal_call_id;
  const char* name;
  const char* arguments_json;
  const char* usage_json;
} NativeRigStreamEvent;

typedef void (*NativeRigStreamCallback)(
    int64_t user_data,
    const NativeRigStreamEvent* event);

int32_t dart_edge_rig_native_abi_version(void);

NativeRigHandleResult* dart_edge_rig_create_agent(
    const NativeRigAgentConfig* config);

NativeRigPromptResult* dart_edge_rig_agent_prompt_message(
    int64_t agent_handle,
    const char* message_json);

NativeRigPromptResult* dart_edge_rig_agent_stream_prompt_message(
    int64_t agent_handle,
    const char* message_json,
    const NativeRigStreamOptions* options,
    NativeRigStreamCallback callback,
    int64_t user_data);

NativeRigPromptResult* dart_edge_rig_transcribe(
    const NativeRigModelConfig* config,
    const NativeRigTranscriptionRequest* request);

NativeRigBytesResult* dart_edge_rig_generate_image(
    const NativeRigModelConfig* config,
    const NativeRigImageGenerationRequest* request);

void dart_edge_rig_complete_tool_call(
    int64_t call_sequence,
    const char* result,
    const char* error);

void dart_edge_rig_cancel_stream(int64_t stream_id);

void dart_edge_rig_dispose_handle(int64_t handle);

void dart_edge_rig_free_handle_result(NativeRigHandleResult* value);

void dart_edge_rig_free_prompt_result(NativeRigPromptResult* value);

void dart_edge_rig_free_bytes_result(NativeRigBytesResult* value);

void dart_edge_rig_free_stream_event(NativeRigStreamEvent* value);

#endif  // DART_EDGE_RIG_H_
