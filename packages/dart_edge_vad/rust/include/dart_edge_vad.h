#ifndef DART_EDGE_VAD_H_
#define DART_EDGE_VAD_H_

#include <stddef.h>
#include <stdint.h>

int32_t dart_edge_vad_native_abi_version(void);

int32_t dart_edge_vad_initialize_dart_api_dl(void* data);

typedef struct DartEdgeVadStream DartEdgeVadStream;
typedef struct DartEdgeVadPool DartEdgeVadPool;

char* dart_edge_vad_detect_silero(
    const char* request_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

char* dart_edge_vad_stream_process(
    DartEdgeVadStream* stream,
    const uint8_t* input_ptr,
    intptr_t input_len,
    int32_t flush);

DartEdgeVadStream* dart_edge_vad_stream_create(const char* request_json);

void dart_edge_vad_stream_free(DartEdgeVadStream* stream);

DartEdgeVadPool* dart_edge_vad_pool_create(
    uintptr_t worker_count,
    uintptr_t max_queue_size,
    int64_t completion_port);

int64_t dart_edge_vad_pool_submit_silero(
    DartEdgeVadPool* pool,
    const char* request_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

char* dart_edge_vad_pool_take_result(DartEdgeVadPool* pool, int64_t job_id);

char* dart_edge_vad_pool_metrics(DartEdgeVadPool* pool);

void dart_edge_vad_pool_free(DartEdgeVadPool* pool);

char* dart_edge_vad_take_last_error(void);

void dart_edge_vad_free_string(char* value);

#endif  // DART_EDGE_VAD_H_
