#ifndef DART_EDGE_AUDIO_H_
#define DART_EDGE_AUDIO_H_

#include <dart_edge_core_ffi.h>
#include <stddef.h>
#include <stdint.h>

typedef struct NativeAudioBytesResult {
  NativeOwnedBytes bytes;
  char* result_json;
} NativeAudioBytesResult;

typedef struct DartEdgeAudioPool DartEdgeAudioPool;

int32_t dart_edge_audio_native_abi_version(void);

int32_t dart_edge_audio_initialize_dart_api_dl(void* data);

char* dart_edge_audio_probe_file(const char* path);

char* dart_edge_audio_probe_bytes(
    const char* options_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

char* dart_edge_audio_convert_file(const char* request_json);

NativeAudioBytesResult* dart_edge_audio_convert_bytes(
    const char* request_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

DartEdgeAudioPool* dart_edge_audio_pool_create(
    uintptr_t worker_count,
    uintptr_t max_queue_size,
    int64_t completion_port);

int64_t dart_edge_audio_pool_submit_probe_file(
    DartEdgeAudioPool* pool,
    const char* request_json);

int64_t dart_edge_audio_pool_submit_probe_bytes(
    DartEdgeAudioPool* pool,
    const char* options_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

int64_t dart_edge_audio_pool_submit_convert_file(
    DartEdgeAudioPool* pool,
    const char* request_json);

int64_t dart_edge_audio_pool_submit_convert_bytes(
    DartEdgeAudioPool* pool,
    const char* request_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

char* dart_edge_audio_pool_take_file_result(
    DartEdgeAudioPool* pool,
    int64_t job_id);

char* dart_edge_audio_pool_take_probe_result(
    DartEdgeAudioPool* pool,
    int64_t job_id);

NativeAudioBytesResult* dart_edge_audio_pool_take_convert_result(
    DartEdgeAudioPool* pool,
    int64_t job_id);

char* dart_edge_audio_pool_metrics(DartEdgeAudioPool* pool);

void dart_edge_audio_pool_free(DartEdgeAudioPool* pool);

void dart_edge_audio_free_bytes_result(NativeAudioBytesResult* value);

char* dart_edge_audio_take_last_error(void);

void dart_edge_audio_free_string(char* value);

#endif  // DART_EDGE_AUDIO_H_
