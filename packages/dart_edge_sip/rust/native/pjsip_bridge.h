#ifndef DART_EDGE_SIP_PJSIP_BRIDGE_H_
#define DART_EDGE_SIP_PJSIP_BRIDGE_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct dart_edge_sip_bridge_runtime dart_edge_sip_bridge_runtime;

enum {
  DART_EDGE_SIP_BRIDGE_TRANSPORT_UDP = 0,
  DART_EDGE_SIP_BRIDGE_TRANSPORT_TCP = 1,
  DART_EDGE_SIP_BRIDGE_TRANSPORT_TLS = 2,
};

enum {
  DART_EDGE_SIP_BRIDGE_EVENT_NONE = 0,
  DART_EDGE_SIP_BRIDGE_EVENT_CALL = 1,
  DART_EDGE_SIP_BRIDGE_EVENT_REGISTRATION = 2,
  DART_EDGE_SIP_BRIDGE_EVENT_TRUNK = 3,
  DART_EDGE_SIP_BRIDGE_EVENT_RECORDING = 4,
  DART_EDGE_SIP_BRIDGE_EVENT_VOICEMAIL = 5,
};

enum {
  DART_EDGE_SIP_BRIDGE_DIRECTION_INBOUND = 0,
  DART_EDGE_SIP_BRIDGE_DIRECTION_OUTBOUND = 1,
};

enum {
  DART_EDGE_SIP_BRIDGE_CALL_INVITING = 0,
  DART_EDGE_SIP_BRIDGE_CALL_RINGING = 1,
  DART_EDGE_SIP_BRIDGE_CALL_ESTABLISHED = 2,
  DART_EDGE_SIP_BRIDGE_CALL_BRIDGED = 3,
  DART_EDGE_SIP_BRIDGE_CALL_ON_HOLD = 4,
  DART_EDGE_SIP_BRIDGE_CALL_TRANSFERRING = 5,
  DART_EDGE_SIP_BRIDGE_CALL_REJECTED = 6,
  DART_EDGE_SIP_BRIDGE_CALL_TERMINATED = 7,
};

enum {
  DART_EDGE_SIP_BRIDGE_REGISTRATION_REGISTERED = 0,
  DART_EDGE_SIP_BRIDGE_REGISTRATION_UNREGISTERED = 1,
  DART_EDGE_SIP_BRIDGE_REGISTRATION_AUTHENTICATION_FAILED = 2,
};

enum {
  DART_EDGE_SIP_BRIDGE_TRUNK_CONNECTED = 0,
  DART_EDGE_SIP_BRIDGE_TRUNK_DISCONNECTED = 1,
  DART_EDGE_SIP_BRIDGE_TRUNK_FAILED = 2,
};

enum {
  DART_EDGE_SIP_BRIDGE_RECORDING_STARTED = 0,
  DART_EDGE_SIP_BRIDGE_RECORDING_STOPPED = 1,
  DART_EDGE_SIP_BRIDGE_RECORDING_COMPLETED = 2,
};

enum {
  DART_EDGE_SIP_BRIDGE_VOICEMAIL_QUEUED = 0,
  DART_EDGE_SIP_BRIDGE_VOICEMAIL_STORED = 1,
  DART_EDGE_SIP_BRIDGE_VOICEMAIL_FAILED = 2,
};

typedef struct {
  uint32_t max_calls;
  uint32_t worker_threads;
  uint32_t max_media_ports;
  uint32_t rtp_start_port;
  uint32_t rtp_end_port;
  bool enable_ice;
  bool enable_turn;
  bool enable_tls;
  bool enable_srtp;
  bool enable_rport;
  bool enable_registrar;
  const char* user_agent;
  const char* external_address;
  const char* recording_directory;
  const char* voicemail_directory;
  const char* default_greeting_uri;
} dart_edge_sip_bridge_config;

typedef struct {
  int32_t protocol;
  const char* host;
  uint32_t port;
  const char* public_address;
  const char* tls_profile;
} dart_edge_sip_bridge_transport_config;

typedef struct {
  const char* id;
  const char* server_uri;
  const char* username;
  const char* password;
  const char* realm;
  int32_t direction;
} dart_edge_sip_bridge_trunk_config;

typedef struct {
  const char* id;
  const char* extension;
  const char* username;
  const char* password;
  const char* realm;
  const char* display_name;
  bool allow_registrations;
  bool require_authentication;
} dart_edge_sip_bridge_endpoint_config;

typedef struct {
  char endpoint_id[64];
  char contact_uri[256];
  uint64_t expires_at_epoch_seconds;
} dart_edge_sip_bridge_registered_endpoint;

typedef struct {
  int32_t kind;
  int32_t call_direction;
  int32_t call_state;
  int32_t registration_state;
  int32_t trunk_state;
  int32_t recording_state;
  int32_t voicemail_state;
  int32_t status_code;
  uint64_t expires_at_epoch_seconds;
  char call_id[64];
  char related_call_id[64];
  char endpoint_id[64];
  char trunk_id[64];
  char recording_id[128];
  char mailbox[128];
  char message_id[128];
  char from_uri[256];
  char to_uri[256];
  char contact_uri[256];
  char media_app_id[128];
  char storage_uri[1024];
  char details[256];
} dart_edge_sip_bridge_event;

dart_edge_sip_bridge_runtime* dart_edge_sip_bridge_runtime_create(
    const dart_edge_sip_bridge_config* config,
    char* error,
    size_t error_len);

void dart_edge_sip_bridge_runtime_destroy(dart_edge_sip_bridge_runtime* runtime);

bool dart_edge_sip_bridge_add_transport(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_transport_config* transport,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_add_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_trunk_config* trunk,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_add_endpoint(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_endpoint_config* endpoint,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_start(
    dart_edge_sip_bridge_runtime* runtime,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_stop(
    dart_edge_sip_bridge_runtime* runtime,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_originate_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id,
    const char* from_uri,
    const char* to_uri,
    char* session_id,
    size_t session_id_len,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_originate_endpoint_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* endpoint_id,
    const char* from_uri,
    const char* to_uri,
    char* session_id,
    size_t session_id_len,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_route_call_to_endpoint(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* endpoint_id,
    char* routed_session_id,
    size_t routed_session_id_len,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_route_call_to_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* trunk_id,
    const char* target_uri,
    char* routed_session_id,
    size_t routed_session_id_len,
    char* error,
    size_t error_len);

size_t dart_edge_sip_bridge_list_registered_endpoints(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_registered_endpoint* endpoints,
    size_t endpoint_capacity);

bool dart_edge_sip_bridge_answer_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint32_t status,
    const char* reason,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_reject_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint32_t status,
    const char* reason,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_hangup_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint32_t status,
    const char* reason,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_bridge_calls(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* other_session_id,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_hold_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_resume_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_transfer_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* target_uri,
    const char* attended_session_id,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_play_prompt(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* prompt_id,
    const char* media_uri,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_start_recording(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* recording_id,
    const char* destination_uri,
    char* storage_uri,
    size_t storage_uri_len,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_send_to_voicemail(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* mailbox,
    char* storage_uri,
    size_t storage_uri_len,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_poll_event(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_event* event_out);

bool dart_edge_sip_bridge_attach_media_app(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* media_app_id,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_detach_media_app(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_read_media_frame(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint8_t* buffer,
    size_t buffer_len,
    size_t* bytes_written,
    uint32_t* sample_rate_hz,
    uint32_t* channels,
    uint32_t* frame_duration_ms,
    uint64_t* sequence,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_play_raw_audio(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const uint8_t* bytes,
    size_t bytes_len,
    uint32_t sample_rate_hz,
    uint32_t channels,
    uint32_t frame_duration_ms,
    char* error,
    size_t error_len);

bool dart_edge_sip_bridge_clear_raw_audio(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len);

#endif  // DART_EDGE_SIP_PJSIP_BRIDGE_H_
