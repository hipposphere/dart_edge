#ifndef DART_EDGE_AUDIO_H_
#define DART_EDGE_AUDIO_H_

#include <stddef.h>
#include <stdint.h>

typedef struct NativeOwnedBytes {
  uint8_t* ptr;
  intptr_t len;
} NativeOwnedBytes;

typedef struct NativeAudioBytesResult {
  NativeOwnedBytes bytes;
  char* result_json;
} NativeAudioBytesResult;

int32_t dart_edge_audio_native_abi_version(void);

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

void dart_edge_audio_free_bytes_result(NativeAudioBytesResult* value);

char* dart_edge_audio_take_last_error(void);

void dart_edge_audio_free_string(char* value);

#endif  // DART_EDGE_AUDIO_H_
