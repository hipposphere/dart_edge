#ifndef DART_EDGE_SIP_H_
#define DART_EDGE_SIP_H_

#include <stdbool.h>
#include <stdint.h>

#include "../../../../crates/dart_edge_core/include/dart_edge_core_ffi.h"

typedef struct dart_edge_sip_audio_frame {
  NativeOwnedBytes bytes;
  int32_t encoding;
  uint32_t sample_rate_hz;
  uint32_t channels;
  uint32_t frame_duration_ms;
  uint64_t sequence;
} dart_edge_sip_audio_frame;

int32_t dart_edge_sip_native_abi_version(void);

int64_t dart_edge_sip_create(const char* config_json);

bool dart_edge_sip_start(int64_t handle);

bool dart_edge_sip_stop(int64_t handle);

void dart_edge_sip_dispose(int64_t handle);

char* dart_edge_sip_issue_command(int64_t handle, const char* command_json);

char* dart_edge_sip_poll_event(int64_t handle);

char* dart_edge_sip_take_last_error(void);

void dart_edge_sip_free_string(char* value);

bool dart_edge_sip_poll_media_frame(
    int64_t handle,
    const char* session_id,
    dart_edge_sip_audio_frame* frame_out);

bool dart_edge_sip_play_media_copy(
    int64_t handle,
    const char* session_id,
    const uint8_t* bytes,
    intptr_t len,
    uint32_t sample_rate_hz,
    uint32_t channels,
    uint32_t frame_duration_ms);

bool dart_edge_sip_play_media_owned(
    int64_t handle,
    const char* session_id,
    NativeOwnedBytes bytes,
    uint32_t sample_rate_hz,
    uint32_t channels,
    uint32_t frame_duration_ms);

bool dart_edge_sip_clear_media_playback(int64_t handle, const char* session_id);

void dart_edge_sip_free_owned_bytes(NativeOwnedBytes value);

#endif  // DART_EDGE_SIP_H_
