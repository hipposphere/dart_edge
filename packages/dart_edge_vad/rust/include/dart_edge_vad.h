#ifndef DART_EDGE_VAD_H_
#define DART_EDGE_VAD_H_

#include <stddef.h>
#include <stdint.h>

int32_t dart_edge_vad_native_abi_version(void);

char* dart_edge_vad_detect_silero(
    const char* request_json,
    const uint8_t* input_ptr,
    intptr_t input_len);

char* dart_edge_vad_take_last_error(void);

void dart_edge_vad_free_string(char* value);

#endif  // DART_EDGE_VAD_H_
