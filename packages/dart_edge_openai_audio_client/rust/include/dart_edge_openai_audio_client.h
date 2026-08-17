#ifndef DART_EDGE_OPENAI_AUDIO_CLIENT_H_
#define DART_EDGE_OPENAI_AUDIO_CLIENT_H_

#include <dart_edge_core_ffi.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct NativeOpenAiAudioStringPair {
  const char* key;
  const char* value;
} NativeOpenAiAudioStringPair;

typedef struct NativeOpenAiAudioClientConfig {
  const char* base_url;
  const char* api_key;
  const NativeOpenAiAudioStringPair* headers;
  intptr_t headers_len;
  int64_t connect_timeout_ms;
  int64_t request_timeout_ms;
  int64_t max_response_bytes;
  bool allow_http;
} NativeOpenAiAudioClientConfig;

typedef struct NativeOpenAiAudioTranscriptionRequest {
  const char* filename;
  const char* content_type;
  const NativeOpenAiAudioStringPair* fields;
  intptr_t fields_len;
} NativeOpenAiAudioTranscriptionRequest;

typedef struct NativeOpenAiAudioCreateResult {
  int64_t handle;
  char* error;
} NativeOpenAiAudioCreateResult;

typedef struct NativeOpenAiAudioTranscriptionResult {
  int32_t status_code;
  char* body;
  char* content_type;
  char* request_id;
  char* error;
} NativeOpenAiAudioTranscriptionResult;

int32_t dart_edge_openai_audio_client_native_abi_version(void);

NativeOpenAiAudioCreateResult* dart_edge_openai_audio_client_create(
    const NativeOpenAiAudioClientConfig* config);

void dart_edge_openai_audio_client_dispose(int64_t handle);

int64_t dart_edge_openai_audio_client_create_operation(int64_t handle);

void dart_edge_openai_audio_client_cancel_operation(int64_t operation_id);

void dart_edge_openai_audio_client_discard_operation(int64_t operation_id);

NativeOpenAiAudioTranscriptionResult*
dart_edge_openai_audio_client_transcribe_bytes(
    int64_t handle,
    int64_t operation_id,
    const NativeOpenAiAudioTranscriptionRequest* request,
    const uint8_t* bytes_ptr,
    intptr_t bytes_len);

NativeOpenAiAudioTranscriptionResult*
dart_edge_openai_audio_client_transcribe_native_stream(
    int64_t handle,
    int64_t operation_id,
    const NativeOpenAiAudioTranscriptionRequest* request,
    const NativeByteStream* stream,
    int64_t content_length);

void dart_edge_openai_audio_client_free_create_result(
    NativeOpenAiAudioCreateResult* value);

void dart_edge_openai_audio_client_free_transcription_result(
    NativeOpenAiAudioTranscriptionResult* value);

#endif  // DART_EDGE_OPENAI_AUDIO_CLIENT_H_
