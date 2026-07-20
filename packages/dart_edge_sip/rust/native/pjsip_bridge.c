#include "pjsip_bridge.h"

#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

#include <pjsua-lib/pjsua.h>

#define DART_EDGE_SIP_BRIDGE_MAX_EVENTS 256
#define DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ 16000
#define DART_EDGE_SIP_MEDIA_CHANNELS 1
#define DART_EDGE_SIP_MEDIA_FRAME_DURATION_MS 20
#define DART_EDGE_SIP_MEDIA_BITS_PER_SAMPLE 16
#define DART_EDGE_SIP_MEDIA_CAPTURE_BUFFER_BYTES 160000
#define DART_EDGE_SIP_MEDIA_PLAYBACK_BUFFER_BYTES 960000

typedef struct {
  int32_t protocol;
  char* host;
  uint32_t port;
  char* public_address;
  char* tls_profile;
  pjsua_transport_id transport_id;
} dart_edge_sip_bridge_transport_entry;

typedef struct {
  char* id;
  char* server_uri;
  char* username;
  char* password;
  char* realm;
  int32_t direction;
  pjsua_acc_id acc_id;
} dart_edge_sip_bridge_trunk_entry;

typedef struct {
  char* id;
  char* extension;
  char* username;
  char* password;
  char* realm;
  char* display_name;
  bool allow_registrations;
  bool require_authentication;
  bool registered;
  char contact_uri[256];
  time_t expires_at;
} dart_edge_sip_bridge_endpoint_entry;

typedef struct {
  bool occupied;
  int32_t direction;
  bool on_hold;
  bool bridged;
  bool transfer_pending;
  bool has_player;
  bool has_recorder;
  bool has_voicemail_recorder;
  bool media_session_active;
  pjsua_player_id player_id;
  pjsua_recorder_id recorder_id;
  pjsua_recorder_id voicemail_recorder_id;
  char from_uri[256];
  char to_uri[256];
  char recording_id[128];
  char recording_path[1024];
  char mailbox[128];
  char voicemail_path[1024];
  char voicemail_message_id[128];
  char media_app_id[128];
  uint64_t media_frame_sequence;
  pjsua_call_id bridge_peer_call_id;
} dart_edge_sip_bridge_call_slot;

typedef struct {
  bool initialized;
  pthread_mutex_t mutex;
  uint8_t* bytes;
  size_t capacity;
  size_t start;
  size_t length;
} dart_edge_sip_audio_ring;

typedef struct {
  pjmedia_port base;
  dart_edge_sip_audio_ring ring;
  bool* active;
  bool capture;
} dart_edge_sip_stream_port;

typedef struct {
  bool ports_registered;
  bool ports_connected;
  pjsua_conf_port_id call_port_id;
  pjsua_conf_port_id inbound_port_id;
  pjsua_conf_port_id outbound_port_id;
  dart_edge_sip_stream_port* inbound_port;
  dart_edge_sip_stream_port* outbound_port;
} dart_edge_sip_bridge_media_slot;

struct dart_edge_sip_bridge_runtime {
  dart_edge_sip_bridge_config config;
  dart_edge_sip_bridge_transport_entry transports[16];
  size_t transport_count;
  dart_edge_sip_bridge_trunk_entry trunks[PJSUA_MAX_ACC];
  size_t trunk_count;
  dart_edge_sip_bridge_endpoint_entry* endpoints;
  size_t endpoint_count;
  size_t endpoint_capacity;
  pjsua_acc_id default_account_id;
  pj_pool_t* media_pool;
  bool registrar_module_registered;
  bool started;
  bool shutting_down;
  pthread_mutex_t event_mutex;
  dart_edge_sip_bridge_event events[DART_EDGE_SIP_BRIDGE_MAX_EVENTS];
  size_t event_head;
  size_t event_count;
  dart_edge_sip_bridge_call_slot calls[PJSUA_MAX_CALLS];
  dart_edge_sip_bridge_media_slot media[PJSUA_MAX_CALLS];
};

static dart_edge_sip_bridge_runtime* g_active_runtime = NULL;
static _Thread_local pj_thread_desc g_external_thread_desc;
static _Thread_local pj_thread_t* g_external_thread = NULL;

static void clear_media_streams(dart_edge_sip_bridge_media_slot* media_slot);
static void destroy_media_slots(dart_edge_sip_bridge_runtime* runtime);
static bool call_has_active_audio_media(const pjsua_call_info* info);
static bool ensure_media_ports_connected(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    dart_edge_sip_bridge_call_slot* slot,
    char* error,
    size_t error_len);
static bool configure_default_account_media(
    dart_edge_sip_bridge_runtime* runtime,
    char* error,
    size_t error_len);
static pj_bool_t registrar_on_rx_request(pjsip_rx_data* rdata);
static void maybe_bridge_related_calls(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id);
static dart_edge_sip_bridge_trunk_entry* find_trunk_by_account_id(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_acc_id account_id);

static pjsip_module dart_edge_sip_registrar_module = {
    .name = {"dart_edge_sip_registrar", 23},
    .id = -1,
    .priority = PJSIP_MOD_PRIORITY_APPLICATION,
    .on_rx_request = &registrar_on_rx_request,
};

static void clear_event(dart_edge_sip_bridge_event* event) {
  memset(event, 0, sizeof(*event));
}

static void copy_text(char* destination, size_t destination_len, const char* source) {
  if (destination == NULL || destination_len == 0) {
    return;
  }
  destination[0] = '\0';
  if (source == NULL) {
    return;
  }
  snprintf(destination, destination_len, "%s", source);
}

static void copy_pj_str(char* destination, size_t destination_len, pj_str_t value) {
  if (destination == NULL || destination_len == 0) {
    return;
  }
  destination[0] = '\0';
  if (value.ptr == NULL || value.slen <= 0) {
    return;
  }

  size_t count = (size_t)value.slen;
  if (count >= destination_len) {
    count = destination_len - 1;
  }
  memcpy(destination, value.ptr, count);
  destination[count] = '\0';
}

static char* duplicate_string(const char* value) {
  if (value == NULL || value[0] == '\0') {
    return NULL;
  }
  size_t length = strlen(value) + 1;
  char* copy = (char*)malloc(length);
  if (copy == NULL) {
    return NULL;
  }
  memcpy(copy, value, length);
  return copy;
}

static pj_str_t pj_const_string(const char* value) {
  return pj_str((char*)(value == NULL ? "" : value));
}

static void store_error(char* error, size_t error_len, const char* message) {
  if (error == NULL || error_len == 0) {
    return;
  }
  copy_text(error, error_len, message == NULL ? "dart_edge_sip native error" : message);
}

static void store_status_error(
    char* error,
    size_t error_len,
    const char* context,
    pj_status_t status) {
  char detail[PJ_ERR_MSG_SIZE];
  pj_strerror(status, detail, sizeof(detail));
  if (error == NULL || error_len == 0) {
    return;
  }
  if (context == NULL || context[0] == '\0') {
    snprintf(error, error_len, "%s (%d)", detail, status);
    return;
  }
  snprintf(error, error_len, "%s: %s (%d)", context, detail, status);
}

static bool ensure_current_thread_registered(char* error, size_t error_len) {
  if (pj_thread_is_registered()) {
    return true;
  }

  memset(g_external_thread_desc, 0, sizeof(g_external_thread_desc));
  pj_status_t status =
      pj_thread_register("dart_edge_sip_ffi", g_external_thread_desc, &g_external_thread);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to register Dart FFI thread with PJLIB", status);
    return false;
  }
  return true;
}

static const char* uri_to_path(const char* value) {
  if (value == NULL) {
    return NULL;
  }
  return strncmp(value, "file://", 7) == 0 ? value + 7 : value;
}

static bool ensure_directory(const char* path, char* error, size_t error_len) {
  if (path == NULL || path[0] == '\0') {
    store_error(error, error_len, "Missing directory path.");
    return false;
  }
  if (mkdir(path, 0775) == 0 || errno == EEXIST) {
    return true;
  }
  char message[512];
  snprintf(message, sizeof(message), "Failed to create directory '%s': %s", path, strerror(errno));
  store_error(error, error_len, message);
  return false;
}

static int32_t transport_kind_to_pjsip(int32_t protocol) {
  switch (protocol) {
    case DART_EDGE_SIP_BRIDGE_TRANSPORT_UDP:
      return PJSIP_TRANSPORT_UDP;
    case DART_EDGE_SIP_BRIDGE_TRANSPORT_TCP:
      return PJSIP_TRANSPORT_TCP;
    case DART_EDGE_SIP_BRIDGE_TRANSPORT_TLS:
      return PJSIP_TRANSPORT_TLS;
    default:
      return -1;
  }
}

static bool session_id_to_call_id(const char* session_id, pjsua_call_id* out_call_id) {
  if (session_id == NULL || out_call_id == NULL) {
    return false;
  }
  int call_id = -1;
  if (sscanf(session_id, "call-%d", &call_id) != 1) {
    return false;
  }
  if (call_id < 0 || call_id >= PJSUA_MAX_CALLS) {
    return false;
  }
  *out_call_id = call_id;
  return true;
}

static void call_id_to_session_id(pjsua_call_id call_id, char* buffer, size_t buffer_len) {
  if (buffer == NULL || buffer_len == 0) {
    return;
  }
  snprintf(buffer, buffer_len, "call-%d", call_id);
}

static dart_edge_sip_bridge_call_slot* slot_for_call(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id) {
  if (runtime == NULL || call_id < 0 || call_id >= PJSUA_MAX_CALLS) {
    return NULL;
  }
  return &runtime->calls[call_id];
}

static void reset_slot(dart_edge_sip_bridge_call_slot* slot) {
  if (slot == NULL) {
    return;
  }
  memset(slot, 0, sizeof(*slot));
  slot->player_id = PJSUA_INVALID_ID;
  slot->recorder_id = PJSUA_INVALID_ID;
  slot->voicemail_recorder_id = PJSUA_INVALID_ID;
  slot->bridge_peer_call_id = PJSUA_INVALID_ID;
}

static void reset_media_slot(dart_edge_sip_bridge_media_slot* slot) {
  if (slot == NULL) {
    return;
  }
  memset(slot, 0, sizeof(*slot));
  slot->call_port_id = PJSUA_INVALID_ID;
  slot->inbound_port_id = PJSUA_INVALID_ID;
  slot->outbound_port_id = PJSUA_INVALID_ID;
}

static dart_edge_sip_bridge_media_slot* media_slot_for_call(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id) {
  if (runtime == NULL || call_id < 0 || call_id >= PJSUA_MAX_CALLS) {
    return NULL;
  }
  return &runtime->media[call_id];
}

static void push_event(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_event* event) {
  if (runtime == NULL || event == NULL) {
    return;
  }

  pthread_mutex_lock(&runtime->event_mutex);
  if (runtime->event_count == DART_EDGE_SIP_BRIDGE_MAX_EVENTS) {
    runtime->event_head = (runtime->event_head + 1) % DART_EDGE_SIP_BRIDGE_MAX_EVENTS;
    runtime->event_count -= 1;
  }

  size_t index =
      (runtime->event_head + runtime->event_count) % DART_EDGE_SIP_BRIDGE_MAX_EVENTS;
  runtime->events[index] = *event;
  runtime->event_count += 1;
  pthread_mutex_unlock(&runtime->event_mutex);
}

static bool pop_event(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_event* event_out) {
  if (runtime == NULL || event_out == NULL) {
    return false;
  }

  pthread_mutex_lock(&runtime->event_mutex);
  if (runtime->event_count == 0) {
    pthread_mutex_unlock(&runtime->event_mutex);
    return false;
  }

  *event_out = runtime->events[runtime->event_head];
  runtime->event_head = (runtime->event_head + 1) % DART_EDGE_SIP_BRIDGE_MAX_EVENTS;
  runtime->event_count -= 1;
  pthread_mutex_unlock(&runtime->event_mutex);
  return true;
}

static int32_t map_call_state(
    const dart_edge_sip_bridge_call_slot* slot,
    const pjsua_call_info* info) {
  if (info->state == PJSIP_INV_STATE_DISCONNECTED) {
    return DART_EDGE_SIP_BRIDGE_CALL_TERMINATED;
  }
  if (slot != NULL && slot->transfer_pending) {
    return DART_EDGE_SIP_BRIDGE_CALL_TRANSFERRING;
  }
  if (slot != NULL && slot->on_hold) {
    return DART_EDGE_SIP_BRIDGE_CALL_ON_HOLD;
  }
  if (slot != NULL && slot->bridged) {
    return DART_EDGE_SIP_BRIDGE_CALL_BRIDGED;
  }

  switch (info->state) {
    case PJSIP_INV_STATE_CALLING:
    case PJSIP_INV_STATE_INCOMING:
      return DART_EDGE_SIP_BRIDGE_CALL_INVITING;
    case PJSIP_INV_STATE_EARLY:
      return DART_EDGE_SIP_BRIDGE_CALL_RINGING;
    case PJSIP_INV_STATE_CONNECTING:
      // 2xx has been sent/received, but the INVITE transaction is not
      // confirmed until ACK. Softphones such as Linphone usually start their
      // duration counter only after CONFIRMED, so do not expose CONNECTING as
      // established.
      return DART_EDGE_SIP_BRIDGE_CALL_RINGING;
    case PJSIP_INV_STATE_CONFIRMED:
      return DART_EDGE_SIP_BRIDGE_CALL_ESTABLISHED;
    case PJSIP_INV_STATE_DISCONNECTED:
      return DART_EDGE_SIP_BRIDGE_CALL_TERMINATED;
    default:
      return DART_EDGE_SIP_BRIDGE_CALL_INVITING;
  }
}

static void fill_call_event(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    dart_edge_sip_bridge_event* event) {
  clear_event(event);
  event->kind = DART_EDGE_SIP_BRIDGE_EVENT_CALL;

  pjsua_call_info info;
  if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) {
    call_id_to_session_id(call_id, event->call_id, sizeof(event->call_id));
    event->call_direction = DART_EDGE_SIP_BRIDGE_DIRECTION_OUTBOUND;
    event->call_state = DART_EDGE_SIP_BRIDGE_CALL_INVITING;
    return;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL && !slot->occupied) {
    reset_slot(slot);
    slot->occupied = true;
    slot->direction =
        info.role == PJSIP_ROLE_UAS ? DART_EDGE_SIP_BRIDGE_DIRECTION_INBOUND
                                    : DART_EDGE_SIP_BRIDGE_DIRECTION_OUTBOUND;
  }

  call_id_to_session_id(call_id, event->call_id, sizeof(event->call_id));
  event->call_direction =
      slot == NULL ? DART_EDGE_SIP_BRIDGE_DIRECTION_OUTBOUND : slot->direction;
  event->call_state = map_call_state(slot, &info);
  bool is_inbound =
      slot != NULL ? slot->direction == DART_EDGE_SIP_BRIDGE_DIRECTION_INBOUND
                   : info.role == PJSIP_ROLE_UAS;

  if (slot != NULL && slot->from_uri[0] != '\0') {
    copy_text(event->from_uri, sizeof(event->from_uri), slot->from_uri);
  } else {
    copy_pj_str(
        event->from_uri,
        sizeof(event->from_uri),
        is_inbound ? info.remote_info : info.local_info);
  }

  if (slot != NULL && slot->to_uri[0] != '\0') {
    copy_text(event->to_uri, sizeof(event->to_uri), slot->to_uri);
  } else {
    copy_pj_str(
        event->to_uri,
        sizeof(event->to_uri),
        is_inbound ? info.local_info : info.remote_info);
  }

  if (slot != NULL && slot->media_app_id[0] != '\0') {
    copy_text(event->media_app_id, sizeof(event->media_app_id), slot->media_app_id);
  }

  dart_edge_sip_bridge_trunk_entry* trunk =
      find_trunk_by_account_id(runtime, info.acc_id);
  if (trunk != NULL) {
    copy_text(event->trunk_id, sizeof(event->trunk_id), trunk->id);
  }
}

static void emit_call_state(dart_edge_sip_bridge_runtime* runtime, pjsua_call_id call_id) {
  dart_edge_sip_bridge_event event;
  fill_call_event(runtime, call_id, &event);
  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL && slot->bridge_peer_call_id != PJSUA_INVALID_ID) {
    call_id_to_session_id(
        slot->bridge_peer_call_id,
        event.related_call_id,
        sizeof(event.related_call_id));
  }
  push_event(runtime, &event);
}

static bool call_is_confirmed(pjsua_call_id call_id) {
  pjsua_call_info info;
  if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) {
    return false;
  }
  return info.state == PJSIP_INV_STATE_CONFIRMED;
}

static void maybe_bridge_related_calls(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id) {
  if (runtime == NULL) {
    return;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL || slot->bridge_peer_call_id == PJSUA_INVALID_ID) {
    return;
  }

  pjsua_call_id peer_call_id = slot->bridge_peer_call_id;
  dart_edge_sip_bridge_call_slot* peer_slot = slot_for_call(runtime, peer_call_id);
  if (peer_slot == NULL) {
    return;
  }
  if (slot->bridged && peer_slot->bridged) {
    return;
  }

  pjsua_call_info call_info;
  pjsua_call_info peer_info;
  if (pjsua_call_get_info(call_id, &call_info) != PJ_SUCCESS ||
      pjsua_call_get_info(peer_call_id, &peer_info) != PJ_SUCCESS ||
      call_info.state == PJSIP_INV_STATE_DISCONNECTED ||
      peer_info.state == PJSIP_INV_STATE_DISCONNECTED) {
    return;
  }

  if (slot->direction == DART_EDGE_SIP_BRIDGE_DIRECTION_INBOUND &&
      call_info.state != PJSIP_INV_STATE_CONFIRMED) {
    pjsua_call_answer(call_id, 200, NULL, NULL);
    return;
  }
  if (peer_slot->direction == DART_EDGE_SIP_BRIDGE_DIRECTION_INBOUND &&
      peer_info.state != PJSIP_INV_STATE_CONFIRMED) {
    pjsua_call_answer(peer_call_id, 200, NULL, NULL);
    return;
  }
  if (!call_is_confirmed(call_id) || !call_is_confirmed(peer_call_id)) {
    return;
  }

  pjsua_conf_port_id call_port = pjsua_call_get_conf_port(call_id);
  pjsua_conf_port_id peer_port = pjsua_call_get_conf_port(peer_call_id);
  if (call_port == PJSUA_INVALID_ID || peer_port == PJSUA_INVALID_ID) {
    return;
  }

  if (pjsua_conf_connect(call_port, peer_port) != PJ_SUCCESS ||
      pjsua_conf_connect(peer_port, call_port) != PJ_SUCCESS) {
    return;
  }

  slot->bridged = true;
  peer_slot->bridged = true;

  dart_edge_sip_bridge_event event;
  fill_call_event(runtime, call_id, &event);
  event.call_state = DART_EDGE_SIP_BRIDGE_CALL_BRIDGED;
  call_id_to_session_id(peer_call_id, event.related_call_id, sizeof(event.related_call_id));
  push_event(runtime, &event);

  dart_edge_sip_bridge_event peer_event;
  fill_call_event(runtime, peer_call_id, &peer_event);
  peer_event.call_state = DART_EDGE_SIP_BRIDGE_CALL_BRIDGED;
  call_id_to_session_id(call_id, peer_event.related_call_id, sizeof(peer_event.related_call_id));
  push_event(runtime, &peer_event);
}

static void emit_trunk_state(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_trunk_entry* trunk,
    int32_t trunk_state,
    int32_t status_code,
    const char* details) {
  if (runtime == NULL || trunk == NULL) {
    return;
  }

  dart_edge_sip_bridge_event event;
  clear_event(&event);
  event.kind = DART_EDGE_SIP_BRIDGE_EVENT_TRUNK;
  event.trunk_state = trunk_state;
  event.status_code = status_code;
  copy_text(event.trunk_id, sizeof(event.trunk_id), trunk->id);
  copy_text(event.details, sizeof(event.details), details);
  push_event(runtime, &event);
}

static void emit_registration_state(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_endpoint_entry* endpoint,
    int32_t registration_state) {
  if (runtime == NULL || endpoint == NULL) {
    return;
  }

  dart_edge_sip_bridge_event event;
  clear_event(&event);
  event.kind = DART_EDGE_SIP_BRIDGE_EVENT_REGISTRATION;
  event.registration_state = registration_state;
  event.expires_at_epoch_seconds = endpoint->expires_at > 0 ? (uint64_t)endpoint->expires_at : 0;
  copy_text(event.endpoint_id, sizeof(event.endpoint_id), endpoint->id);
  copy_text(event.contact_uri, sizeof(event.contact_uri), endpoint->contact_uri);
  push_event(runtime, &event);
}

static void emit_recording_event(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    int32_t recording_state,
    const char* recording_id,
    const char* storage_uri) {
  if (runtime == NULL) {
    return;
  }

  dart_edge_sip_bridge_event event;
  clear_event(&event);
  event.kind = DART_EDGE_SIP_BRIDGE_EVENT_RECORDING;
  event.recording_state = recording_state;
  call_id_to_session_id(call_id, event.call_id, sizeof(event.call_id));
  copy_text(event.recording_id, sizeof(event.recording_id), recording_id);
  copy_text(event.storage_uri, sizeof(event.storage_uri), storage_uri);
  push_event(runtime, &event);
}

static void emit_voicemail_event(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    int32_t voicemail_state,
    const char* mailbox,
    const char* message_id,
    const char* storage_uri) {
  if (runtime == NULL) {
    return;
  }

  dart_edge_sip_bridge_event event;
  clear_event(&event);
  event.kind = DART_EDGE_SIP_BRIDGE_EVENT_VOICEMAIL;
  event.voicemail_state = voicemail_state;
  call_id_to_session_id(call_id, event.call_id, sizeof(event.call_id));
  copy_text(event.mailbox, sizeof(event.mailbox), mailbox);
  copy_text(event.message_id, sizeof(event.message_id), message_id);
  copy_text(event.storage_uri, sizeof(event.storage_uri), storage_uri);
  push_event(runtime, &event);
}

static void cleanup_slot_media(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    dart_edge_sip_bridge_call_slot* slot) {
  if (runtime == NULL || slot == NULL) {
    return;
  }

  if (slot->has_player && slot->player_id != PJSUA_INVALID_ID) {
    pjsua_player_destroy(slot->player_id);
    slot->has_player = false;
    slot->player_id = PJSUA_INVALID_ID;
  }

  if (slot->has_recorder && slot->recorder_id != PJSUA_INVALID_ID) {
    pjsua_recorder_destroy(slot->recorder_id);
    emit_recording_event(
        runtime,
        call_id,
        DART_EDGE_SIP_BRIDGE_RECORDING_COMPLETED,
        slot->recording_id,
        slot->recording_path);
    slot->has_recorder = false;
    slot->recorder_id = PJSUA_INVALID_ID;
  }

  if (slot->has_voicemail_recorder && slot->voicemail_recorder_id != PJSUA_INVALID_ID) {
    pjsua_recorder_destroy(slot->voicemail_recorder_id);
    emit_voicemail_event(
        runtime,
        call_id,
        DART_EDGE_SIP_BRIDGE_VOICEMAIL_STORED,
        slot->mailbox,
        slot->voicemail_message_id,
        slot->voicemail_path);
    slot->has_voicemail_recorder = false;
    slot->voicemail_recorder_id = PJSUA_INVALID_ID;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot != NULL) {
    clear_media_streams(media_slot);
  }

  slot->media_frame_sequence = 0;
  slot->media_session_active = false;
  slot->media_app_id[0] = '\0';
}

static void on_call_state(pjsua_call_id call_id, pjsip_event* event) {
  (void)event;
  dart_edge_sip_bridge_runtime* runtime = g_active_runtime;
  if (runtime == NULL) {
    return;
  }

  emit_call_state(runtime, call_id);

  pjsua_call_info info;
  if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) {
    return;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL && slot->occupied && slot->media_session_active &&
      info.state == PJSIP_INV_STATE_CONFIRMED) {
    char ignored_error[256];
    ensure_media_ports_connected(runtime, call_id, slot, ignored_error, sizeof(ignored_error));
  }
  maybe_bridge_related_calls(runtime, call_id);

  if (info.state == PJSIP_INV_STATE_DISCONNECTED) {
    if (slot != NULL && slot->occupied) {
      cleanup_slot_media(runtime, call_id, slot);
      reset_slot(slot);
    }
  }
}

static void on_call_media_state(pjsua_call_id call_id) {
  dart_edge_sip_bridge_runtime* runtime = g_active_runtime;
  if (runtime == NULL) {
    return;
  }

  pjsua_call_info info;
  if (pjsua_call_get_info(call_id, &info) != PJ_SUCCESS) {
    return;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL && slot->occupied && slot->media_session_active) {
    dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
    if (call_has_active_audio_media(&info)) {
      char ignored_error[256];
      ensure_media_ports_connected(runtime, call_id, slot, ignored_error, sizeof(ignored_error));
    } else if (media_slot != NULL) {
      clear_media_streams(media_slot);
    }
  }

  maybe_bridge_related_calls(runtime, call_id);
  emit_call_state(runtime, call_id);
}

static void on_incoming_call(
    pjsua_acc_id acc_id,
    pjsua_call_id call_id,
    pjsip_rx_data* rdata) {
  (void)acc_id;
  (void)rdata;
  dart_edge_sip_bridge_runtime* runtime = g_active_runtime;
  if (runtime == NULL) {
    return;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL) {
    reset_slot(slot);
    slot->occupied = true;
    slot->direction = DART_EDGE_SIP_BRIDGE_DIRECTION_INBOUND;
    pjsua_call_info info;
    if (pjsua_call_get_info(call_id, &info) == PJ_SUCCESS) {
      copy_pj_str(slot->from_uri, sizeof(slot->from_uri), info.remote_info);
      copy_pj_str(slot->to_uri, sizeof(slot->to_uri), info.local_info);
    }
  }

  emit_call_state(runtime, call_id);
}

static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info* info) {
  (void)info;
  dart_edge_sip_bridge_runtime* runtime = g_active_runtime;
  if (runtime == NULL) {
    return;
  }

  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    dart_edge_sip_bridge_trunk_entry* trunk = &runtime->trunks[index];
    if (trunk->acc_id != acc_id) {
      continue;
    }

    pjsua_acc_info acc_info;
    if (pjsua_acc_get_info(acc_id, &acc_info) != PJ_SUCCESS) {
      emit_trunk_state(
          runtime,
          trunk,
          DART_EDGE_SIP_BRIDGE_TRUNK_FAILED,
          0,
          "Failed to query trunk registration state.");
      return;
    }

    char details[256];
    details[0] = '\0';
    copy_pj_str(details, sizeof(details), acc_info.status_text);

    if (acc_info.status == PJSIP_SC_OK) {
      emit_trunk_state(
          runtime,
          trunk,
          DART_EDGE_SIP_BRIDGE_TRUNK_CONNECTED,
          acc_info.status,
          details);
    } else if (acc_info.status >= 400) {
      emit_trunk_state(
          runtime,
          trunk,
          DART_EDGE_SIP_BRIDGE_TRUNK_FAILED,
          acc_info.status,
          details);
    } else {
      emit_trunk_state(
          runtime,
          trunk,
          DART_EDGE_SIP_BRIDGE_TRUNK_DISCONNECTED,
          acc_info.status,
          details);
    }
    return;
  }
}

static dart_edge_sip_bridge_trunk_entry* find_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id) {
  if (runtime == NULL || trunk_id == NULL) {
    return NULL;
  }

  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    if (runtime->trunks[index].id != NULL &&
        strcmp(runtime->trunks[index].id, trunk_id) == 0) {
      return &runtime->trunks[index];
    }
  }
  return NULL;
}

static dart_edge_sip_bridge_trunk_entry* find_trunk_by_account_id(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_acc_id account_id) {
  if (runtime == NULL || account_id == PJSUA_INVALID_ID) {
    return NULL;
  }

  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    if (runtime->trunks[index].acc_id == account_id) {
      return &runtime->trunks[index];
    }
  }
  return NULL;
}

static size_t find_trunk_index(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id) {
  if (runtime == NULL || trunk_id == NULL) {
    return SIZE_MAX;
  }

  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    if (runtime->trunks[index].id != NULL &&
        strcmp(runtime->trunks[index].id, trunk_id) == 0) {
      return index;
    }
  }
  return SIZE_MAX;
}

static void free_trunk_entry(dart_edge_sip_bridge_trunk_entry* trunk) {
  if (trunk == NULL) {
    return;
  }

  free(trunk->id);
  free(trunk->server_uri);
  free(trunk->username);
  free(trunk->password);
  free(trunk->realm);
  memset(trunk, 0, sizeof(*trunk));
  trunk->acc_id = PJSUA_INVALID_ID;
}

static bool copy_trunk_config(
    dart_edge_sip_bridge_trunk_entry* entry,
    const dart_edge_sip_bridge_trunk_config* trunk,
    char* error,
    size_t error_len) {
  if (entry == NULL || trunk == NULL) {
    store_error(error, error_len, "Missing SIP trunk config.");
    return false;
  }

  memset(entry, 0, sizeof(*entry));
  entry->id = duplicate_string(trunk->id);
  entry->server_uri = duplicate_string(trunk->server_uri);
  entry->username = duplicate_string(trunk->username);
  entry->password = duplicate_string(trunk->password);
  entry->realm = duplicate_string(trunk->realm);
  entry->direction = trunk->direction;
  entry->acc_id = PJSUA_INVALID_ID;

  if (entry->id == NULL || entry->server_uri == NULL) {
    free_trunk_entry(entry);
    store_error(error, error_len, "Failed to allocate SIP trunk config.");
    return false;
  }
  return true;
}

static bool remove_trunk_account(
    dart_edge_sip_bridge_trunk_entry* trunk,
    char* error,
    size_t error_len) {
  if (trunk == NULL || trunk->acc_id == PJSUA_INVALID_ID) {
    return true;
  }

  pj_status_t status = pjsua_acc_del(trunk->acc_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to remove SIP trunk account", status);
    return false;
  }
  trunk->acc_id = PJSUA_INVALID_ID;
  return true;
}

static bool pj_str_equals_cstr(pj_str_t value, const char* expected) {
  if (expected == NULL) {
    return false;
  }
  size_t expected_len = strlen(expected);
  return value.slen == (pj_ssize_t)expected_len &&
         strncmp(value.ptr, expected, expected_len) == 0;
}

static dart_edge_sip_bridge_endpoint_entry* find_endpoint_by_id(
    dart_edge_sip_bridge_runtime* runtime,
    const char* endpoint_id) {
  if (runtime == NULL || endpoint_id == NULL) {
    return NULL;
  }

  for (size_t index = 0; index < runtime->endpoint_count; index += 1) {
    dart_edge_sip_bridge_endpoint_entry* endpoint = &runtime->endpoints[index];
    if (endpoint->id != NULL && strcmp(endpoint->id, endpoint_id) == 0) {
      return endpoint;
    }
  }
  return NULL;
}

static dart_edge_sip_bridge_endpoint_entry* find_endpoint_by_user_and_realm(
    dart_edge_sip_bridge_runtime* runtime,
    pj_str_t user,
    pj_str_t realm) {
  if (runtime == NULL || user.slen <= 0) {
    return NULL;
  }

  for (size_t index = 0; index < runtime->endpoint_count; index += 1) {
    dart_edge_sip_bridge_endpoint_entry* endpoint = &runtime->endpoints[index];
    bool user_matches =
        pj_str_equals_cstr(user, endpoint->username) ||
        pj_str_equals_cstr(user, endpoint->extension);
    if (!user_matches) {
      continue;
    }
    if (realm.slen > 0 && endpoint->realm != NULL && endpoint->realm[0] != '\0' &&
        !pj_str_equals_cstr(realm, endpoint->realm)) {
      continue;
    }
    return endpoint;
  }
  return NULL;
}

static bool copy_sip_uri_user_and_host(
    const void* uri,
    char* user,
    size_t user_len,
    char* host,
    size_t host_len) {
  if (user != NULL && user_len > 0) {
    user[0] = '\0';
  }
  if (host != NULL && host_len > 0) {
    host[0] = '\0';
  }
  if (uri == NULL) {
    return false;
  }

  void* resolved = pjsip_uri_get_uri(uri);
  if (resolved == NULL ||
      (!PJSIP_URI_SCHEME_IS_SIP(resolved) && !PJSIP_URI_SCHEME_IS_SIPS(resolved))) {
    return false;
  }

  pjsip_sip_uri* sip_uri = (pjsip_sip_uri*)resolved;
  copy_pj_str(user, user_len, sip_uri->user);
  copy_pj_str(host, host_len, sip_uri->host);
  return true;
}

static dart_edge_sip_bridge_endpoint_entry* find_endpoint_for_register(
    dart_edge_sip_bridge_runtime* runtime,
    pjsip_rx_data* rdata) {
  if (runtime == NULL || rdata == NULL || rdata->msg_info.msg == NULL) {
    return NULL;
  }

  pjsip_to_hdr* to = PJSIP_MSG_TO_HDR(rdata->msg_info.msg);
  if (to == NULL) {
    return NULL;
  }

  char user[128];
  char host[128];
  if (!copy_sip_uri_user_and_host(to->uri, user, sizeof(user), host, sizeof(host))) {
    return NULL;
  }

  pj_str_t user_str = pj_str(user);
  pj_str_t host_str = pj_str(host);
  return find_endpoint_by_user_and_realm(runtime, user_str, host_str);
}

static pj_status_t registrar_lookup_credential(
    pj_pool_t* pool,
    const pj_str_t* realm,
    const pj_str_t* acc_name,
    pjsip_cred_info* cred_info) {
  dart_edge_sip_bridge_runtime* runtime = g_active_runtime;
  if (pool == NULL || realm == NULL || acc_name == NULL || cred_info == NULL ||
      runtime == NULL) {
    return PJSIP_EAUTHACCNOTFOUND;
  }

  dart_edge_sip_bridge_endpoint_entry* endpoint =
      find_endpoint_by_user_and_realm(runtime, *acc_name, *realm);
  if (endpoint == NULL || !endpoint->allow_registrations || endpoint->password == NULL) {
    return PJSIP_EAUTHACCNOTFOUND;
  }

  memset(cred_info, 0, sizeof(*cred_info));
  pj_strdup2(pool, &cred_info->realm, endpoint->realm == NULL ? "" : endpoint->realm);
  pj_strdup2(pool, &cred_info->scheme, "digest");
  pj_strdup2(pool, &cred_info->username, endpoint->username);
  cred_info->data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
  pj_strdup2(pool, &cred_info->data, endpoint->password);
  return PJ_SUCCESS;
}

static void send_register_response(
    pjsip_rx_data* rdata,
    int status_code,
    pjsip_auth_srv* auth_srv,
    const pjsip_contact_hdr* contact,
    uint32_t expires) {
  pjsip_endpoint* endpoint = pjsua_get_pjsip_endpt();
  if (endpoint == NULL || rdata == NULL) {
    return;
  }

  pjsip_tx_data* tdata = NULL;
  pj_status_t status = pjsip_endpt_create_response(
      endpoint,
      rdata,
      status_code,
      NULL,
      &tdata);
  if (status != PJ_SUCCESS || tdata == NULL) {
    return;
  }

  if ((status_code == PJSIP_SC_UNAUTHORIZED ||
       status_code == PJSIP_SC_PROXY_AUTHENTICATION_REQUIRED) &&
      auth_srv != NULL) {
    pjsip_auth_srv_challenge(auth_srv, NULL, NULL, NULL, PJ_FALSE, tdata);
  }

  if (status_code >= 200 && status_code < 300 && contact != NULL) {
    pjsip_contact_hdr* contact_copy =
        (pjsip_contact_hdr*)pjsip_hdr_clone(tdata->pool, contact);
    if (contact_copy != NULL) {
      contact_copy->expires = expires;
      pjsip_msg_add_hdr(tdata->msg, (pjsip_hdr*)contact_copy);
    }
  }

  pjsip_endpt_send_response2(endpoint, rdata, tdata, NULL, NULL);
}

static uint32_t register_expiration_seconds(pjsip_rx_data* rdata, pjsip_contact_hdr* contact) {
  if (contact != NULL && contact->expires != PJSIP_EXPIRES_NOT_SPECIFIED) {
    return contact->expires;
  }

  pjsip_expires_hdr* expires =
      (pjsip_expires_hdr*)pjsip_msg_find_hdr(rdata->msg_info.msg, PJSIP_H_EXPIRES, NULL);
  if (expires != NULL) {
    return expires->ivalue;
  }
  return 3600;
}

static bool copy_contact_uri(
    const pjsip_contact_hdr* contact,
    char* destination,
    size_t destination_len) {
  if (destination == NULL || destination_len == 0) {
    return false;
  }
  destination[0] = '\0';
  if (contact == NULL || contact->star || contact->uri == NULL) {
    return false;
  }

  int written =
      pjsip_uri_print(PJSIP_URI_IN_CONTACT_HDR, contact->uri, destination, destination_len);
  if (written < 0) {
    destination[0] = '\0';
    return false;
  }
  destination[destination_len - 1] = '\0';
  return true;
}

static bool authenticate_register(
    dart_edge_sip_bridge_endpoint_entry* endpoint,
    pjsip_rx_data* rdata) {
  if (endpoint == NULL || rdata == NULL || !endpoint->require_authentication) {
    return true;
  }

  pjsip_auth_srv auth_srv;
  pj_str_t realm = pj_str(endpoint->realm == NULL ? "" : endpoint->realm);
  if (pjsip_auth_srv_init(
          rdata->tp_info.pool,
          &auth_srv,
          &realm,
          &registrar_lookup_credential,
          0) != PJ_SUCCESS) {
    send_register_response(rdata, PJSIP_SC_INTERNAL_SERVER_ERROR, NULL, NULL, 0);
    return false;
  }

  int status_code = PJSIP_SC_UNAUTHORIZED;
  pj_status_t status = pjsip_auth_srv_verify(&auth_srv, rdata, &status_code);
  if (status == PJ_SUCCESS) {
    return true;
  }

  send_register_response(
      rdata,
      status_code == 0 ? PJSIP_SC_UNAUTHORIZED : status_code,
      &auth_srv,
      NULL,
      0);
  return false;
}

static pj_bool_t registrar_on_rx_request(pjsip_rx_data* rdata) {
  dart_edge_sip_bridge_runtime* runtime = g_active_runtime;
  if (runtime == NULL || rdata == NULL || rdata->msg_info.msg == NULL) {
    return PJ_FALSE;
  }

  pjsip_msg* msg = rdata->msg_info.msg;
  if (msg->type != PJSIP_REQUEST_MSG ||
      msg->line.req.method.id != PJSIP_REGISTER_METHOD) {
    return PJ_FALSE;
  }

  dart_edge_sip_bridge_endpoint_entry* endpoint =
      find_endpoint_for_register(runtime, rdata);
  if (endpoint == NULL || !endpoint->allow_registrations) {
    send_register_response(rdata, PJSIP_SC_NOT_FOUND, NULL, NULL, 0);
    return PJ_TRUE;
  }

  if (!authenticate_register(endpoint, rdata)) {
    return PJ_TRUE;
  }

  pjsip_contact_hdr* contact =
      (pjsip_contact_hdr*)pjsip_msg_find_hdr(msg, PJSIP_H_CONTACT, NULL);
  uint32_t expires = register_expiration_seconds(rdata, contact);

  if (contact == NULL || contact->star || expires == 0) {
    endpoint->registered = false;
    endpoint->expires_at = 0;
    endpoint->contact_uri[0] = '\0';
    send_register_response(rdata, PJSIP_SC_OK, NULL, contact, 0);
    emit_registration_state(
        runtime,
        endpoint,
        DART_EDGE_SIP_BRIDGE_REGISTRATION_UNREGISTERED);
    return PJ_TRUE;
  }

  char contact_uri[sizeof(endpoint->contact_uri)];
  if (!copy_contact_uri(contact, contact_uri, sizeof(contact_uri))) {
    send_register_response(rdata, PJSIP_SC_BAD_REQUEST, NULL, NULL, 0);
    return PJ_TRUE;
  }

  endpoint->registered = true;
  endpoint->expires_at = time(NULL) + expires;
  copy_text(endpoint->contact_uri, sizeof(endpoint->contact_uri), contact_uri);
  send_register_response(rdata, PJSIP_SC_OK, NULL, contact, expires);
  emit_registration_state(
      runtime,
      endpoint,
      DART_EDGE_SIP_BRIDGE_REGISTRATION_REGISTERED);
  return PJ_TRUE;
}

static bool validate_from_uri(
    const dart_edge_sip_bridge_trunk_entry* trunk,
    const char* from_uri,
    char* error,
    size_t error_len) {
  if (trunk == NULL || from_uri == NULL || from_uri[0] == '\0') {
    return true;
  }
  if (trunk->username == NULL || trunk->realm == NULL) {
    return true;
  }

  char expected[256];
  snprintf(expected, sizeof(expected), "sip:%s@%s", trunk->username, trunk->realm);
  if (strcmp(from_uri, expected) == 0) {
    return true;
  }

  char message[512];
  snprintf(
      message,
      sizeof(message),
      "fromUri '%s' does not match trunk '%s' identity '%s'.",
      from_uri,
      trunk->id == NULL ? "" : trunk->id,
      expected);
  store_error(error, error_len, message);
  return false;
}

static void prepare_transport_config(
    const dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_transport_entry* transport,
    pjsua_transport_config* transport_config) {
  pjsua_transport_config_default(transport_config);
  transport_config->port = transport->port;
  if (transport->host != NULL && transport->host[0] != '\0' &&
      strcmp(transport->host, "0.0.0.0") != 0) {
    transport_config->bound_addr = pj_str(transport->host);
  }
  if (transport->public_address != NULL && transport->public_address[0] != '\0') {
    transport_config->public_addr = pj_str(transport->public_address);
  } else if (runtime->config.external_address != NULL &&
             runtime->config.external_address[0] != '\0') {
    transport_config->public_addr = pj_const_string(runtime->config.external_address);
  }
}

static bool add_trunk_account(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_trunk_entry* trunk,
    char* error,
    size_t error_len) {
  if (runtime == NULL || trunk == NULL) {
    store_error(error, error_len, "Missing trunk runtime.");
    return false;
  }
  char host[128];
  host[0] = '\0';
  if (trunk->realm != NULL && trunk->realm[0] != '\0') {
    copy_text(host, sizeof(host), trunk->realm);
  } else if (trunk->server_uri != NULL) {
    const char* start = strstr(trunk->server_uri, "sip:");
    start = start == NULL ? trunk->server_uri : start + 4;
    const char* at = strchr(start, '@');
    start = at == NULL ? start : at + 1;
    copy_text(host, sizeof(host), start);
    char* semicolon = strchr(host, ';');
    if (semicolon != NULL) {
      *semicolon = '\0';
    }
  }
  if (host[0] == '\0') {
    store_error(error, error_len, "Trunk requires a realm or server URI host.");
    return false;
  }

  char id_uri[256];
  if (trunk->username != NULL && trunk->username[0] != '\0') {
    snprintf(id_uri, sizeof(id_uri), "sip:%s@%s", trunk->username, host);
  } else {
    snprintf(
        id_uri,
        sizeof(id_uri),
        "sip:%s@%s",
        trunk->id == NULL ? "trunk" : trunk->id,
        host);
  }

  pjsua_acc_config acc_config;
  pjsua_acc_config_default(&acc_config);
  acc_config.id = pj_str(id_uri);
  if (trunk->server_uri != NULL && trunk->server_uri[0] != '\0') {
    acc_config.proxy_cnt = 1;
    acc_config.proxy[0] = pj_str(trunk->server_uri);
  }
  if (trunk->username != NULL && trunk->username[0] != '\0' &&
      trunk->password != NULL && trunk->password[0] != '\0' &&
      trunk->server_uri != NULL && trunk->server_uri[0] != '\0') {
    acc_config.reg_uri = pj_str(trunk->server_uri);
    acc_config.cred_count = 1;
    acc_config.cred_info[0].realm =
        pj_str(trunk->realm != NULL && trunk->realm[0] != '\0' ? trunk->realm : "*");
    acc_config.cred_info[0].scheme = pj_str("digest");
    acc_config.cred_info[0].username = pj_str(trunk->username);
    acc_config.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    acc_config.cred_info[0].data = pj_str(trunk->password);
  }
  acc_config.transport_id = runtime->default_account_id == PJSUA_INVALID_ID
                                ? PJSUA_INVALID_ID
                                : runtime->transports[0].transport_id;
  acc_config.allow_contact_rewrite = runtime->config.enable_rport ? PJ_TRUE : PJ_FALSE;
  acc_config.use_rfc5626 = runtime->config.enable_rport ? PJ_TRUE : PJ_FALSE;
  acc_config.rtp_cfg.port = runtime->config.rtp_start_port;
  acc_config.rtp_cfg.port_range =
      runtime->config.rtp_end_port > runtime->config.rtp_start_port
          ? runtime->config.rtp_end_port - runtime->config.rtp_start_port
          : 0;
  if (runtime->config.external_address != NULL &&
      runtime->config.external_address[0] != '\0') {
    acc_config.rtp_cfg.public_addr = pj_const_string(runtime->config.external_address);
  }

  pj_status_t status = pjsua_acc_add(&acc_config, PJ_FALSE, &trunk->acc_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to add SIP trunk account", status);
    return false;
  }

  return true;
}

static bool configure_default_account_media(
    dart_edge_sip_bridge_runtime* runtime,
    char* error,
    size_t error_len) {
  if (runtime == NULL || runtime->default_account_id == PJSUA_INVALID_ID) {
    return true;
  }

  pj_pool_t* pool = pjsua_pool_create("dart_edge_sip_acc_cfg", 2048, 2048);
  if (pool == NULL) {
    store_error(error, error_len, "Failed to allocate SIP account config pool.");
    return false;
  }

  pjsua_acc_config acc_config;
  pj_status_t status =
      pjsua_acc_get_config(runtime->default_account_id, pool, &acc_config);
  if (status == PJ_SUCCESS) {
    acc_config.rtp_cfg.port = runtime->config.rtp_start_port;
    acc_config.rtp_cfg.port_range =
        runtime->config.rtp_end_port > runtime->config.rtp_start_port
            ? runtime->config.rtp_end_port - runtime->config.rtp_start_port
            : 0;
    if (runtime->config.external_address != NULL &&
        runtime->config.external_address[0] != '\0') {
      acc_config.rtp_cfg.public_addr = pj_const_string(runtime->config.external_address);
    }
    status = pjsua_acc_modify(runtime->default_account_id, &acc_config);
  }

  pj_pool_release(pool);

  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to configure SIP media account", status);
    return false;
  }
  return true;
}

static bool create_recording_path(
    const char* directory,
    const char* file_stem,
    char* path_out,
    size_t path_out_len,
    char* error,
    size_t error_len) {
  if (!ensure_directory(directory, error, error_len)) {
    return false;
  }
  snprintf(path_out, path_out_len, "%s/%s.wav", directory, file_stem);
  return true;
}

static size_t media_bytes_per_frame(uint32_t sample_rate_hz, uint32_t channels) {
  return (size_t)((sample_rate_hz * DART_EDGE_SIP_MEDIA_FRAME_DURATION_MS) / 1000) *
      channels * (DART_EDGE_SIP_MEDIA_BITS_PER_SAMPLE / 8);
}

static size_t media_samples_per_frame(uint32_t sample_rate_hz, uint32_t channels) {
  return (size_t)((sample_rate_hz * DART_EDGE_SIP_MEDIA_FRAME_DURATION_MS) / 1000) * channels;
}

static bool audio_ring_init(dart_edge_sip_audio_ring* ring, size_t capacity) {
  if (ring == NULL || capacity == 0) {
    return false;
  }
  memset(ring, 0, sizeof(*ring));
  ring->bytes = (uint8_t*)malloc(capacity);
  if (ring->bytes == NULL) {
    return false;
  }
  if (pthread_mutex_init(&ring->mutex, NULL) != 0) {
    free(ring->bytes);
    ring->bytes = NULL;
    return false;
  }
  ring->capacity = capacity;
  ring->initialized = true;
  return true;
}

static void audio_ring_destroy(dart_edge_sip_audio_ring* ring) {
  if (ring == NULL || !ring->initialized) {
    return;
  }
  pthread_mutex_destroy(&ring->mutex);
  free(ring->bytes);
  memset(ring, 0, sizeof(*ring));
}

static void audio_ring_clear(dart_edge_sip_audio_ring* ring) {
  if (ring == NULL || !ring->initialized) {
    return;
  }
  pthread_mutex_lock(&ring->mutex);
  ring->start = 0;
  ring->length = 0;
  pthread_mutex_unlock(&ring->mutex);
}

static void copy_from_ring(
    const dart_edge_sip_audio_ring* ring,
    size_t offset,
    uint8_t* destination,
    size_t count) {
  if (count == 0) {
    return;
  }
  size_t first = ring->capacity - offset;
  if (first > count) {
    first = count;
  }
  memcpy(destination, ring->bytes + offset, first);
  if (first < count) {
    memcpy(destination + first, ring->bytes, count - first);
  }
}

static void copy_into_ring(
    dart_edge_sip_audio_ring* ring,
    size_t offset,
    const uint8_t* source,
    size_t count) {
  if (count == 0) {
    return;
  }
  size_t first = ring->capacity - offset;
  if (first > count) {
    first = count;
  }
  memcpy(ring->bytes + offset, source, first);
  if (first < count) {
    memcpy(ring->bytes, source + first, count - first);
  }
}

static size_t audio_ring_write(
    dart_edge_sip_audio_ring* ring,
    const uint8_t* bytes,
    size_t bytes_len) {
  if (ring == NULL || !ring->initialized || bytes == NULL || bytes_len == 0) {
    return 0;
  }
  pthread_mutex_lock(&ring->mutex);

  if (bytes_len >= ring->capacity) {
    bytes += bytes_len - ring->capacity;
    bytes_len = ring->capacity;
    ring->start = 0;
    ring->length = 0;
  }

  size_t available = ring->capacity - ring->length;
  if (available < bytes_len) {
    size_t to_drop = bytes_len - available;
    ring->start = (ring->start + to_drop) % ring->capacity;
    ring->length -= to_drop;
  }

  size_t write_offset = (ring->start + ring->length) % ring->capacity;
  copy_into_ring(ring, write_offset, bytes, bytes_len);
  ring->length += bytes_len;

  pthread_mutex_unlock(&ring->mutex);
  return bytes_len;
}

static bool audio_ring_read_exact(
    dart_edge_sip_audio_ring* ring,
    uint8_t* destination,
    size_t bytes_len) {
  if (ring == NULL || !ring->initialized || destination == NULL || bytes_len == 0) {
    return false;
  }

  pthread_mutex_lock(&ring->mutex);
  if (ring->length < bytes_len) {
    pthread_mutex_unlock(&ring->mutex);
    return false;
  }

  copy_from_ring(ring, ring->start, destination, bytes_len);
  ring->start = (ring->start + bytes_len) % ring->capacity;
  ring->length -= bytes_len;
  pthread_mutex_unlock(&ring->mutex);
  return true;
}

static size_t audio_ring_read_padded(
    dart_edge_sip_audio_ring* ring,
    uint8_t* destination,
    size_t bytes_len) {
  if (ring == NULL || !ring->initialized || destination == NULL || bytes_len == 0) {
    return 0;
  }

  pthread_mutex_lock(&ring->mutex);
  size_t count = ring->length < bytes_len ? ring->length : bytes_len;
  if (count > 0) {
    copy_from_ring(ring, ring->start, destination, count);
    ring->start = (ring->start + count) % ring->capacity;
    ring->length -= count;
  }
  pthread_mutex_unlock(&ring->mutex);

  if (count < bytes_len) {
    memset(destination + count, 0, bytes_len - count);
  }
  return count;
}

static pj_status_t media_capture_port_put_frame(
    pjmedia_port* this_port,
    pjmedia_frame* frame) {
  if (this_port == NULL || frame == NULL || frame->buf == NULL || frame->size == 0) {
    return PJ_SUCCESS;
  }

  dart_edge_sip_stream_port* port = (dart_edge_sip_stream_port*)this_port;
  if (!port->capture || port->active == NULL || !*port->active ||
      frame->type != PJMEDIA_FRAME_TYPE_AUDIO) {
    return PJ_SUCCESS;
  }

  audio_ring_write(&port->ring, (const uint8_t*)frame->buf, (size_t)frame->size);
  return PJ_SUCCESS;
}

static pj_status_t media_playback_port_get_frame(
    pjmedia_port* this_port,
    pjmedia_frame* frame) {
  if (this_port == NULL || frame == NULL || frame->buf == NULL) {
    return PJ_EINVAL;
  }

  dart_edge_sip_stream_port* port = (dart_edge_sip_stream_port*)this_port;
  if (port->capture) {
    return PJ_EINVAL;
  }

  size_t frame_bytes = PJMEDIA_PIA_AVG_FSZ(&this_port->info);
  if ((size_t)frame->size < frame_bytes) {
    return PJ_ETOOSMALL;
  }

  frame->type = PJMEDIA_FRAME_TYPE_AUDIO;
  frame->size = frame_bytes;
  if (port->active == NULL || !*port->active) {
    memset(frame->buf, 0, frame_bytes);
    return PJ_SUCCESS;
  }

  audio_ring_read_padded(&port->ring, (uint8_t*)frame->buf, frame_bytes);
  return PJ_SUCCESS;
}

static dart_edge_sip_stream_port* create_stream_port(
    const char* name,
    unsigned signature,
    bool capture,
    bool* active,
    size_t ring_capacity,
    char* error,
    size_t error_len) {
  dart_edge_sip_stream_port* port =
      (dart_edge_sip_stream_port*)calloc(1, sizeof(*port));
  if (port == NULL) {
    store_error(error, error_len, "Failed to allocate SIP media stream port.");
    return NULL;
  }
  if (!audio_ring_init(&port->ring, ring_capacity)) {
    free(port);
    store_error(error, error_len, "Failed to allocate SIP media ring buffer.");
    return NULL;
  }

  pj_str_t port_name = pj_str((char*)(name == NULL ? "dartEdgeMedia" : name));
  pj_status_t status = pjmedia_port_info_init(
      &port->base.info,
      &port_name,
      signature,
      DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ,
      DART_EDGE_SIP_MEDIA_CHANNELS,
      DART_EDGE_SIP_MEDIA_BITS_PER_SAMPLE,
      (unsigned)media_samples_per_frame(
          DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ,
          DART_EDGE_SIP_MEDIA_CHANNELS));
  if (status != PJ_SUCCESS) {
    audio_ring_destroy(&port->ring);
    free(port);
    store_status_error(error, error_len, "Failed to initialize SIP media stream port", status);
    return NULL;
  }

  port->active = active;
  port->capture = capture;
  if (capture) {
    port->base.put_frame = &media_capture_port_put_frame;
  } else {
    port->base.get_frame = &media_playback_port_get_frame;
  }
  return port;
}

static void destroy_stream_port(dart_edge_sip_stream_port* port) {
  if (port == NULL) {
    return;
  }
  audio_ring_destroy(&port->ring);
  free(port);
}

static void clear_media_streams(dart_edge_sip_bridge_media_slot* media_slot) {
  if (media_slot == NULL) {
    return;
  }
  if (media_slot->ports_connected && media_slot->call_port_id != PJSUA_INVALID_ID) {
    if (media_slot->inbound_port_id != PJSUA_INVALID_ID) {
      pjsua_conf_disconnect(media_slot->call_port_id, media_slot->inbound_port_id);
    }
    if (media_slot->outbound_port_id != PJSUA_INVALID_ID) {
      pjsua_conf_disconnect(media_slot->outbound_port_id, media_slot->call_port_id);
    }
  }
  if (media_slot->inbound_port != NULL) {
    audio_ring_clear(&media_slot->inbound_port->ring);
  }
  if (media_slot->outbound_port != NULL) {
    audio_ring_clear(&media_slot->outbound_port->ring);
  }
  media_slot->ports_connected = false;
  media_slot->call_port_id = PJSUA_INVALID_ID;
}

static void destroy_media_slots(dart_edge_sip_bridge_runtime* runtime) {
  if (runtime == NULL) {
    return;
  }
  for (int index = 0; index < PJSUA_MAX_CALLS; index += 1) {
    destroy_stream_port(runtime->media[index].inbound_port);
    destroy_stream_port(runtime->media[index].outbound_port);
    reset_media_slot(&runtime->media[index]);
  }
}

static bool ensure_media_ports_registered(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    dart_edge_sip_bridge_call_slot* slot,
    char* error,
    size_t error_len) {
  if (runtime == NULL || slot == NULL) {
    store_error(error, error_len, "Missing SIP media runtime.");
    return false;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot == NULL) {
    store_error(error, error_len, "Unknown SIP media slot.");
    return false;
  }
  if (media_slot->ports_registered) {
    return true;
  }
  if (runtime->media_pool == NULL) {
    store_error(error, error_len, "SIP media pool is not initialized.");
    return false;
  }

  media_slot->inbound_port = create_stream_port(
      "dartEdgeSipCapture",
      PJMEDIA_SIGNATURE('D', 'E', 'C', 'P'),
      true,
      &slot->media_session_active,
      DART_EDGE_SIP_MEDIA_CAPTURE_BUFFER_BYTES,
      error,
      error_len);
  if (media_slot->inbound_port == NULL) {
    return false;
  }

  media_slot->outbound_port = create_stream_port(
      "dartEdgeSipPlayback",
      PJMEDIA_SIGNATURE('D', 'E', 'P', 'B'),
      false,
      &slot->media_session_active,
      DART_EDGE_SIP_MEDIA_PLAYBACK_BUFFER_BYTES,
      error,
      error_len);
  if (media_slot->outbound_port == NULL) {
    destroy_stream_port(media_slot->inbound_port);
    media_slot->inbound_port = NULL;
    return false;
  }

  pj_status_t status =
      pjsua_conf_add_port(runtime->media_pool, &media_slot->inbound_port->base, &media_slot->inbound_port_id);
  if (status != PJ_SUCCESS) {
    destroy_stream_port(media_slot->inbound_port);
    destroy_stream_port(media_slot->outbound_port);
    media_slot->inbound_port = NULL;
    media_slot->outbound_port = NULL;
    store_status_error(error, error_len, "Failed to register SIP media capture port", status);
    return false;
  }

  status = pjsua_conf_add_port(
      runtime->media_pool,
      &media_slot->outbound_port->base,
      &media_slot->outbound_port_id);
  if (status != PJ_SUCCESS) {
    destroy_stream_port(media_slot->inbound_port);
    destroy_stream_port(media_slot->outbound_port);
    media_slot->inbound_port = NULL;
    media_slot->outbound_port = NULL;
    media_slot->inbound_port_id = PJSUA_INVALID_ID;
    store_status_error(error, error_len, "Failed to register SIP media playback port", status);
    return false;
  }

  media_slot->ports_registered = true;
  return true;
}

static bool ensure_media_ports_connected(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_call_id call_id,
    dart_edge_sip_bridge_call_slot* slot,
    char* error,
    size_t error_len) {
  if (runtime == NULL || slot == NULL) {
    store_error(error, error_len, "Missing SIP media runtime.");
    return false;
  }
  if (!ensure_media_ports_registered(runtime, call_id, slot, error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot == NULL) {
    store_error(error, error_len, "Unknown SIP media slot.");
    return false;
  }

  pjsua_conf_port_id call_port = pjsua_call_get_conf_port(call_id);
  if (call_port == PJSUA_INVALID_ID) {
    return true;
  }
  if (media_slot->ports_connected && media_slot->call_port_id == call_port) {
    return true;
  }
  if (media_slot->ports_connected && media_slot->call_port_id != PJSUA_INVALID_ID) {
    pjsua_conf_disconnect(media_slot->call_port_id, media_slot->inbound_port_id);
    pjsua_conf_disconnect(media_slot->outbound_port_id, media_slot->call_port_id);
    media_slot->ports_connected = false;
  }

  pj_status_t status = pjsua_conf_connect(call_port, media_slot->inbound_port_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to connect SIP call to media capture port", status);
    return false;
  }

  status = pjsua_conf_connect(media_slot->outbound_port_id, call_port);
  if (status != PJ_SUCCESS) {
    pjsua_conf_disconnect(call_port, media_slot->inbound_port_id);
    store_status_error(error, error_len, "Failed to connect SIP media playback port to call", status);
    return false;
  }

  media_slot->ports_connected = true;
  media_slot->call_port_id = call_port;
  return true;
}

static bool call_has_active_audio_media(const pjsua_call_info* info) {
  if (info == NULL) {
    return false;
  }
  for (unsigned index = 0; index < info->media_cnt; index += 1) {
    if (info->media[index].type == PJMEDIA_TYPE_AUDIO &&
        info->media[index].status == PJSUA_CALL_MEDIA_ACTIVE) {
      return true;
    }
  }
  return false;
}

dart_edge_sip_bridge_runtime* dart_edge_sip_bridge_runtime_create(
    const dart_edge_sip_bridge_config* config,
    char* error,
    size_t error_len) {
  if (config == NULL) {
    store_error(error, error_len, "Missing PJSIP bridge config.");
    return NULL;
  }

  dart_edge_sip_bridge_runtime* runtime =
      (dart_edge_sip_bridge_runtime*)calloc(1, sizeof(*runtime));
  if (runtime == NULL) {
    store_error(error, error_len, "Failed to allocate PJSIP runtime.");
    return NULL;
  }

  runtime->config = *config;
  runtime->config.user_agent = duplicate_string(config->user_agent);
  runtime->config.external_address = duplicate_string(config->external_address);
  runtime->config.recording_directory = duplicate_string(config->recording_directory);
  runtime->config.voicemail_directory = duplicate_string(config->voicemail_directory);
  runtime->config.default_greeting_uri = duplicate_string(config->default_greeting_uri);
  runtime->default_account_id = PJSUA_INVALID_ID;
  runtime->media_pool = NULL;

  pthread_mutex_init(&runtime->event_mutex, NULL);
  for (int index = 0; index < PJSUA_MAX_CALLS; index += 1) {
    reset_slot(&runtime->calls[index]);
    reset_media_slot(&runtime->media[index]);
  }

  if (config->max_calls == 0 || config->max_calls > PJSUA_MAX_CALLS) {
    char message[256];
    snprintf(
        message,
        sizeof(message),
        "PJSIP build supports at most %d concurrent calls; requested %u.",
        PJSUA_MAX_CALLS,
        config->max_calls);
    store_error(error, error_len, message);
    dart_edge_sip_bridge_runtime_destroy(runtime);
    return NULL;
  }

  if (config->max_media_ports == 0) {
    store_error(error, error_len, "max_media_ports must be greater than zero.");
    dart_edge_sip_bridge_runtime_destroy(runtime);
    return NULL;
  }

  return runtime;
}

void dart_edge_sip_bridge_runtime_destroy(dart_edge_sip_bridge_runtime* runtime) {
  if (runtime == NULL) {
    return;
  }

  if (runtime->started) {
    char unused[1];
    dart_edge_sip_bridge_stop(runtime, unused, sizeof(unused));
  }

  free((void*)runtime->config.user_agent);
  free((void*)runtime->config.external_address);
  free((void*)runtime->config.recording_directory);
  free((void*)runtime->config.voicemail_directory);
  free((void*)runtime->config.default_greeting_uri);

  for (size_t index = 0; index < runtime->transport_count; index += 1) {
    free(runtime->transports[index].host);
    free(runtime->transports[index].public_address);
    free(runtime->transports[index].tls_profile);
  }
  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    free_trunk_entry(&runtime->trunks[index]);
  }
  for (size_t index = 0; index < runtime->endpoint_count; index += 1) {
    free(runtime->endpoints[index].id);
    free(runtime->endpoints[index].extension);
    free(runtime->endpoints[index].username);
    free(runtime->endpoints[index].password);
    free(runtime->endpoints[index].realm);
    free(runtime->endpoints[index].display_name);
  }
  free(runtime->endpoints);
  destroy_media_slots(runtime);
  if (runtime->media_pool != NULL) {
    pj_pool_release(runtime->media_pool);
    runtime->media_pool = NULL;
  }
  pthread_mutex_destroy(&runtime->event_mutex);
  free(runtime);
}

bool dart_edge_sip_bridge_add_transport(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_transport_config* transport,
    char* error,
    size_t error_len) {
  if (runtime == NULL || transport == NULL) {
    store_error(error, error_len, "Missing SIP transport config.");
    return false;
  }
  if (runtime->started) {
    store_error(error, error_len, "Cannot add transport after runtime start.");
    return false;
  }
  if (runtime->transport_count == 16) {
    store_error(error, error_len, "Exceeded maximum number of SIP transports.");
    return false;
  }
  if (transport_kind_to_pjsip(transport->protocol) == -1) {
    store_error(error, error_len, "Unsupported SIP transport protocol.");
    return false;
  }

  dart_edge_sip_bridge_transport_entry* entry =
      &runtime->transports[runtime->transport_count];
  entry->protocol = transport->protocol;
  entry->port = transport->port;
  entry->host = duplicate_string(transport->host);
  entry->public_address = duplicate_string(transport->public_address);
  entry->tls_profile = duplicate_string(transport->tls_profile);
  entry->transport_id = PJSUA_INVALID_ID;
  runtime->transport_count += 1;
  return true;
}

bool dart_edge_sip_bridge_add_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_trunk_config* trunk,
    char* error,
    size_t error_len) {
  if (runtime == NULL || trunk == NULL) {
    store_error(error, error_len, "Missing SIP trunk config.");
    return false;
  }
  if (find_trunk(runtime, trunk->id) != NULL) {
    store_error(error, error_len, "Duplicate SIP trunk ID.");
    return false;
  }
  if (runtime->trunk_count >= PJSUA_MAX_ACC - 1) {
    store_error(error, error_len, "Exceeded maximum number of SIP trunk accounts.");
    return false;
  }

  dart_edge_sip_bridge_trunk_entry* entry = &runtime->trunks[runtime->trunk_count];
  if (!copy_trunk_config(entry, trunk, error, error_len)) {
    return false;
  }
  runtime->trunk_count += 1;

  if (runtime->started && !add_trunk_account(runtime, entry, error, error_len)) {
    runtime->trunk_count -= 1;
    free_trunk_entry(entry);
    return false;
  }
  return true;
}

bool dart_edge_sip_bridge_update_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id,
    const dart_edge_sip_bridge_trunk_config* trunk,
    char* error,
    size_t error_len) {
  if (runtime == NULL || trunk_id == NULL || trunk == NULL) {
    store_error(error, error_len, "Missing SIP trunk config.");
    return false;
  }

  size_t index = find_trunk_index(runtime, trunk_id);
  if (index == SIZE_MAX) {
    store_error(error, error_len, "Unknown SIP trunk.");
    return false;
  }
  if (trunk->id != NULL && strcmp(trunk->id, trunk_id) != 0) {
    dart_edge_sip_bridge_trunk_entry* existing = find_trunk(runtime, trunk->id);
    if (existing != NULL && existing != &runtime->trunks[index]) {
      store_error(error, error_len, "Duplicate SIP trunk ID.");
      return false;
    }
  }

  dart_edge_sip_bridge_trunk_entry replacement;
  if (!copy_trunk_config(&replacement, trunk, error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_trunk_entry* entry = &runtime->trunks[index];
  if (runtime->started && !remove_trunk_account(entry, error, error_len)) {
    free_trunk_entry(&replacement);
    return false;
  }
  free_trunk_entry(entry);
  *entry = replacement;

  if (runtime->started && !add_trunk_account(runtime, entry, error, error_len)) {
    return false;
  }
  return true;
}

bool dart_edge_sip_bridge_remove_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id,
    char* error,
    size_t error_len) {
  if (runtime == NULL || trunk_id == NULL) {
    store_error(error, error_len, "Missing SIP trunk ID.");
    return false;
  }

  size_t index = find_trunk_index(runtime, trunk_id);
  if (index == SIZE_MAX) {
    store_error(error, error_len, "Unknown SIP trunk.");
    return false;
  }

  dart_edge_sip_bridge_trunk_entry* entry = &runtime->trunks[index];
  if (runtime->started && !remove_trunk_account(entry, error, error_len)) {
    return false;
  }
  free_trunk_entry(entry);
  for (size_t current = index + 1; current < runtime->trunk_count; current += 1) {
    runtime->trunks[current - 1] = runtime->trunks[current];
  }
  runtime->trunk_count -= 1;
  memset(&runtime->trunks[runtime->trunk_count], 0, sizeof(runtime->trunks[0]));
  runtime->trunks[runtime->trunk_count].acc_id = PJSUA_INVALID_ID;
  return true;
}

bool dart_edge_sip_bridge_set_trunk_registration(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id,
    bool enabled,
    char* error,
    size_t error_len) {
  if (runtime == NULL || trunk_id == NULL) {
    store_error(error, error_len, "Missing SIP trunk ID.");
    return false;
  }
  if (!runtime->started) {
    store_error(error, error_len, "Cannot change trunk registration before runtime start.");
    return false;
  }

  dart_edge_sip_bridge_trunk_entry* trunk = find_trunk(runtime, trunk_id);
  if (trunk == NULL) {
    store_error(error, error_len, "Unknown SIP trunk.");
    return false;
  }
  if (trunk->acc_id == PJSUA_INVALID_ID) {
    store_error(error, error_len, "SIP trunk has no registered account.");
    return false;
  }

  pj_status_t status = pjsua_acc_set_registration(
      trunk->acc_id,
      enabled ? PJ_TRUE : PJ_FALSE);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to change SIP trunk registration", status);
    return false;
  }
  return true;
}

bool dart_edge_sip_bridge_add_endpoint(
    dart_edge_sip_bridge_runtime* runtime,
    const dart_edge_sip_bridge_endpoint_config* endpoint,
    char* error,
    size_t error_len) {
  if (runtime == NULL || endpoint == NULL) {
    store_error(error, error_len, "Missing SIP endpoint config.");
    return false;
  }
  if (runtime->started) {
    store_error(error, error_len, "Cannot add endpoint after runtime start.");
    return false;
  }
  if (endpoint->id == NULL || endpoint->id[0] == '\0' ||
      endpoint->username == NULL || endpoint->username[0] == '\0') {
    store_error(error, error_len, "SIP endpoint requires non-empty id and username.");
    return false;
  }

  if (runtime->endpoint_count == runtime->endpoint_capacity) {
    size_t next_capacity = runtime->endpoint_capacity == 0
                               ? 8
                               : runtime->endpoint_capacity * 2;
    dart_edge_sip_bridge_endpoint_entry* endpoints =
        (dart_edge_sip_bridge_endpoint_entry*)realloc(
            runtime->endpoints,
            next_capacity * sizeof(*runtime->endpoints));
    if (endpoints == NULL) {
      store_error(error, error_len, "Failed to allocate SIP endpoint registry.");
      return false;
    }
    runtime->endpoints = endpoints;
    runtime->endpoint_capacity = next_capacity;
  }

  dart_edge_sip_bridge_endpoint_entry* entry =
      &runtime->endpoints[runtime->endpoint_count];
  memset(entry, 0, sizeof(*entry));
  entry->id = duplicate_string(endpoint->id);
  entry->extension = duplicate_string(endpoint->extension);
  entry->username = duplicate_string(endpoint->username);
  entry->password = duplicate_string(endpoint->password);
  entry->realm = duplicate_string(endpoint->realm);
  entry->display_name = duplicate_string(endpoint->display_name);
  entry->allow_registrations = endpoint->allow_registrations;
  entry->require_authentication = endpoint->require_authentication;
  runtime->endpoint_count += 1;
  return true;
}

bool dart_edge_sip_bridge_start(
    dart_edge_sip_bridge_runtime* runtime,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }
  if (runtime->started) {
    return true;
  }
  if (runtime->transport_count == 0) {
    store_error(error, error_len, "At least one SIP transport is required.");
    return false;
  }
  if (g_active_runtime != NULL && g_active_runtime != runtime) {
    store_error(error, error_len, "PJSIP runtime is already active in this process.");
    return false;
  }

  pj_status_t status = pjsua_create();
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to create PJSIP runtime", status);
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    pjsua_destroy();
    return false;
  }

  pjsua_config ua_config;
  pjsua_logging_config log_config;
  pjsua_media_config media_config;
  pjsua_config_default(&ua_config);
  pjsua_logging_config_default(&log_config);
  pjsua_media_config_default(&media_config);

  ua_config.max_calls = runtime->config.max_calls;
  ua_config.thread_cnt = runtime->config.worker_threads;
  ua_config.cb.on_call_state = &on_call_state;
  ua_config.cb.on_call_media_state = &on_call_media_state;
  ua_config.cb.on_incoming_call = &on_incoming_call;
  ua_config.cb.on_reg_state2 = &on_reg_state2;
  if (runtime->config.user_agent != NULL && runtime->config.user_agent[0] != '\0') {
    ua_config.user_agent = pj_str((char*)runtime->config.user_agent);
  }

  log_config.level = 2;
  log_config.console_level = 0;
  log_config.msg_logging = PJ_FALSE;

  media_config.max_media_ports = runtime->config.max_media_ports;
  media_config.enable_ice = runtime->config.enable_ice ? PJ_TRUE : PJ_FALSE;
  media_config.enable_turn = runtime->config.enable_turn ? PJ_TRUE : PJ_FALSE;
  media_config.clock_rate = DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ;
  media_config.channel_count = DART_EDGE_SIP_MEDIA_CHANNELS;
  media_config.audio_frame_ptime = DART_EDGE_SIP_MEDIA_FRAME_DURATION_MS;
  media_config.thread_cnt = 1;
  media_config.has_ioqueue = PJ_TRUE;
  media_config.snd_auto_close_time = 0;

  status = pjsua_init(&ua_config, &log_config, &media_config);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to initialize PJSIP runtime", status);
    pjsua_destroy();
    return false;
  }

  if (runtime->config.enable_registrar && runtime->endpoint_count > 0) {
    dart_edge_sip_registrar_module.id = -1;
    status = pjsip_endpt_register_module(
        pjsua_get_pjsip_endpt(),
        &dart_edge_sip_registrar_module);
    if (status != PJ_SUCCESS) {
      store_status_error(error, error_len, "Failed to register SIP registrar module", status);
      pjsua_destroy();
      return false;
    }
    runtime->registrar_module_registered = true;
  }

  for (size_t index = 0; index < runtime->transport_count; index += 1) {
    pjsua_transport_config transport_config;
    prepare_transport_config(runtime, &runtime->transports[index], &transport_config);
    status = pjsua_transport_create(
        transport_kind_to_pjsip(runtime->transports[index].protocol),
        &transport_config,
        &runtime->transports[index].transport_id);
    if (status != PJ_SUCCESS) {
      store_status_error(error, error_len, "Failed to create SIP transport", status);
      pjsua_destroy();
      return false;
    }
  }

  status = pjsua_acc_add_local(runtime->transports[0].transport_id, PJ_TRUE, &runtime->default_account_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to create local SIP account", status);
    pjsua_destroy();
    return false;
  }
  if (!configure_default_account_media(runtime, error, error_len)) {
    pjsua_destroy();
    return false;
  }

  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    if (!add_trunk_account(runtime, &runtime->trunks[index], error, error_len)) {
      pjsua_destroy();
      return false;
    }
  }

  status = pjsua_start();
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to start PJSIP runtime", status);
    pjsua_destroy();
    return false;
  }

  status = pjsua_set_null_snd_dev();
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to switch PJSIP to null sound device", status);
    pjsua_destroy();
    return false;
  }

  runtime->media_pool = pjsua_pool_create("dart_edge_sip_media", 4096, 4096);
  if (runtime->media_pool == NULL) {
    store_error(error, error_len, "Failed to allocate the SIP media pool.");
    pjsua_destroy();
    return false;
  }

  runtime->started = true;
  runtime->shutting_down = false;
  g_active_runtime = runtime;
  return true;
}

bool dart_edge_sip_bridge_stop(
    dart_edge_sip_bridge_runtime* runtime,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }
  if (!runtime->started) {
    return true;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  runtime->shutting_down = true;
  if (runtime->registrar_module_registered) {
    pjsip_endpt_unregister_module(
        pjsua_get_pjsip_endpt(),
        &dart_edge_sip_registrar_module);
    runtime->registrar_module_registered = false;
    dart_edge_sip_registrar_module.id = -1;
  }
  pj_status_t status = pjsua_destroy();
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to stop PJSIP runtime", status);
    return false;
  }

  destroy_media_slots(runtime);
  if (runtime->media_pool != NULL) {
    pj_pool_release(runtime->media_pool);
    runtime->media_pool = NULL;
  }
  g_active_runtime = NULL;
  runtime->started = false;
  runtime->default_account_id = PJSUA_INVALID_ID;
  runtime->event_head = 0;
  runtime->event_count = 0;
  for (int index = 0; index < PJSUA_MAX_CALLS; index += 1) {
    reset_slot(&runtime->calls[index]);
    reset_media_slot(&runtime->media[index]);
  }
  for (size_t index = 0; index < runtime->trunk_count; index += 1) {
    runtime->trunks[index].acc_id = PJSUA_INVALID_ID;
  }
  for (size_t index = 0; index < runtime->transport_count; index += 1) {
    runtime->transports[index].transport_id = PJSUA_INVALID_ID;
  }

  return true;
}

bool dart_edge_sip_bridge_originate_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* trunk_id,
    const char* from_uri,
    const char* to_uri,
    char* session_id,
    size_t session_id_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL || !runtime->started) {
    store_error(error, error_len, "PJSIP runtime is not started.");
    return false;
  }
  if (to_uri == NULL || to_uri[0] == '\0') {
    store_error(error, error_len, "originateCall requires a destination URI.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pjsua_acc_id account_id = runtime->default_account_id;
  dart_edge_sip_bridge_trunk_entry* trunk = NULL;
  if (trunk_id != NULL && trunk_id[0] != '\0') {
    trunk = find_trunk(runtime, trunk_id);
    if (trunk == NULL) {
      store_error(error, error_len, "Unknown SIP trunk.");
      return false;
    }
    if (!validate_from_uri(trunk, from_uri, error, error_len)) {
      return false;
    }
    if (trunk->acc_id != PJSUA_INVALID_ID) {
      account_id = trunk->acc_id;
    }
  }

  pj_str_t destination = pj_str((char*)to_uri);
  pjsua_call_id call_id = PJSUA_INVALID_ID;
  pj_status_t status =
      pjsua_call_make_call(account_id, &destination, NULL, NULL, NULL, &call_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to originate SIP call", status);
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL) {
    reset_slot(slot);
    slot->occupied = true;
    slot->direction = DART_EDGE_SIP_BRIDGE_DIRECTION_OUTBOUND;
    copy_text(slot->from_uri, sizeof(slot->from_uri), from_uri);
    copy_text(slot->to_uri, sizeof(slot->to_uri), to_uri);
  }

  call_id_to_session_id(call_id, session_id, session_id_len);
  emit_call_state(runtime, call_id);
  return true;
}

static bool endpoint_has_active_contact(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_endpoint_entry* endpoint) {
  if (endpoint == NULL || !endpoint->registered || endpoint->contact_uri[0] == '\0') {
    return false;
  }

  time_t now = time(NULL);
  if (endpoint->expires_at > 0 && endpoint->expires_at <= now) {
    endpoint->registered = false;
    endpoint->expires_at = 0;
    endpoint->contact_uri[0] = '\0';
    emit_registration_state(
        runtime,
        endpoint,
        DART_EDGE_SIP_BRIDGE_REGISTRATION_UNREGISTERED);
    return false;
  }
  return true;
}

static bool make_related_call(
    dart_edge_sip_bridge_runtime* runtime,
    pjsua_acc_id account_id,
    const char* target_uri,
    const char* from_uri,
    pjsua_call_id peer_call_id,
    char* session_id,
    size_t session_id_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL || !runtime->started) {
    store_error(error, error_len, "PJSIP runtime is not started.");
    return false;
  }
  if (target_uri == NULL || target_uri[0] == '\0') {
    store_error(error, error_len, "SIP routing requires a target URI.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_str_t destination = pj_str((char*)target_uri);
  pjsua_call_id call_id = PJSUA_INVALID_ID;
  pj_status_t status =
      pjsua_call_make_call(account_id, &destination, NULL, NULL, NULL, &call_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to originate routed SIP call", status);
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL) {
    reset_slot(slot);
    slot->occupied = true;
    slot->direction = DART_EDGE_SIP_BRIDGE_DIRECTION_OUTBOUND;
    slot->bridge_peer_call_id = peer_call_id;
    copy_text(slot->from_uri, sizeof(slot->from_uri), from_uri);
    copy_text(slot->to_uri, sizeof(slot->to_uri), target_uri);
  }
  if (peer_call_id != PJSUA_INVALID_ID) {
    dart_edge_sip_bridge_call_slot* peer_slot = slot_for_call(runtime, peer_call_id);
    if (peer_slot != NULL) {
      peer_slot->bridge_peer_call_id = call_id;
    }
  }

  call_id_to_session_id(call_id, session_id, session_id_len);
  emit_call_state(runtime, call_id);
  maybe_bridge_related_calls(runtime, call_id);
  return true;
}

bool dart_edge_sip_bridge_originate_endpoint_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* endpoint_id,
    const char* from_uri,
    const char* to_uri,
    char* session_id,
    size_t session_id_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL || !runtime->started) {
    store_error(error, error_len, "PJSIP runtime is not started.");
    return false;
  }

  dart_edge_sip_bridge_endpoint_entry* endpoint =
      find_endpoint_by_id(runtime, endpoint_id);
  if (endpoint == NULL) {
    store_error(error, error_len, "Unknown SIP endpoint.");
    return false;
  }
  if (!endpoint_has_active_contact(runtime, endpoint)) {
    store_error(error, error_len, "SIP endpoint has no active registration.");
    return false;
  }

  const char* target_uri = to_uri != NULL && to_uri[0] != '\0'
                               ? to_uri
                               : endpoint->contact_uri;
  return make_related_call(
      runtime,
      runtime->default_account_id,
      target_uri,
      from_uri,
      PJSUA_INVALID_ID,
      session_id,
      session_id_len,
      error,
      error_len);
}

bool dart_edge_sip_bridge_route_call_to_endpoint(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* endpoint_id,
    char* routed_session_id,
    size_t routed_session_id_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL || !runtime->started) {
    store_error(error, error_len, "PJSIP runtime is not started.");
    return false;
  }

  pjsua_call_id source_call_id;
  if (!session_id_to_call_id(session_id, &source_call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }

  dart_edge_sip_bridge_endpoint_entry* endpoint =
      find_endpoint_by_id(runtime, endpoint_id);
  if (endpoint == NULL) {
    store_error(error, error_len, "Unknown SIP endpoint.");
    return false;
  }
  if (!endpoint_has_active_contact(runtime, endpoint)) {
    store_error(error, error_len, "SIP endpoint has no active registration.");
    return false;
  }

  dart_edge_sip_bridge_call_slot* source_slot = slot_for_call(runtime, source_call_id);
  const char* from_uri = source_slot == NULL ? NULL : source_slot->to_uri;
  return make_related_call(
      runtime,
      runtime->default_account_id,
      endpoint->contact_uri,
      from_uri,
      source_call_id,
      routed_session_id,
      routed_session_id_len,
      error,
      error_len);
}

bool dart_edge_sip_bridge_route_call_to_trunk(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* trunk_id,
    const char* target_uri,
    char* routed_session_id,
    size_t routed_session_id_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL || !runtime->started) {
    store_error(error, error_len, "PJSIP runtime is not started.");
    return false;
  }

  pjsua_call_id source_call_id;
  if (!session_id_to_call_id(session_id, &source_call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }

  dart_edge_sip_bridge_trunk_entry* trunk = find_trunk(runtime, trunk_id);
  if (trunk == NULL) {
    store_error(error, error_len, "Unknown SIP trunk.");
    return false;
  }

  dart_edge_sip_bridge_call_slot* source_slot = slot_for_call(runtime, source_call_id);
  const char* resolved_target = target_uri != NULL && target_uri[0] != '\0'
                                    ? target_uri
                                    : source_slot == NULL ? NULL : source_slot->to_uri;
  pjsua_acc_id account_id = trunk->acc_id != PJSUA_INVALID_ID
                                ? trunk->acc_id
                                : runtime->default_account_id;
  return make_related_call(
      runtime,
      account_id,
      resolved_target,
      source_slot == NULL ? NULL : source_slot->from_uri,
      source_call_id,
      routed_session_id,
      routed_session_id_len,
      error,
      error_len);
}

size_t dart_edge_sip_bridge_list_registered_endpoints(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_registered_endpoint* endpoints,
    size_t endpoint_capacity) {
  if (runtime == NULL) {
    return 0;
  }

  size_t registered_count = 0;
  for (size_t index = 0; index < runtime->endpoint_count; index += 1) {
    dart_edge_sip_bridge_endpoint_entry* endpoint = &runtime->endpoints[index];
    if (!endpoint_has_active_contact(runtime, endpoint)) {
      continue;
    }

    if (endpoints != NULL && registered_count < endpoint_capacity) {
      memset(&endpoints[registered_count], 0, sizeof(endpoints[registered_count]));
      copy_text(
          endpoints[registered_count].endpoint_id,
          sizeof(endpoints[registered_count].endpoint_id),
          endpoint->id);
      copy_text(
          endpoints[registered_count].contact_uri,
          sizeof(endpoints[registered_count].contact_uri),
          endpoint->contact_uri);
      endpoints[registered_count].expires_at_epoch_seconds =
          endpoint->expires_at > 0 ? (uint64_t)endpoint->expires_at : 0;
    }
    registered_count += 1;
  }
  return registered_count;
}

bool dart_edge_sip_bridge_answer_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint32_t status_code,
    const char* reason,
    char* error,
    size_t error_len) {
  (void)runtime;
  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_str_t reason_str = pj_str((char*)(reason == NULL ? "" : reason));
  pj_status_t status = pjsua_call_answer(
      call_id,
      status_code,
      reason == NULL ? NULL : &reason_str,
      NULL);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to answer SIP call", status);
    return false;
  }
  return true;
}

bool dart_edge_sip_bridge_reject_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint32_t status_code,
    const char* reason,
    char* error,
    size_t error_len) {
  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_str_t reason_str = pj_str((char*)(reason == NULL ? "" : reason));
  pj_status_t status = pjsua_call_answer(
      call_id,
      status_code,
      reason == NULL ? NULL : &reason_str,
      NULL);
  if (status != PJ_SUCCESS) {
    status = pjsua_call_hangup(
        call_id,
        status_code,
        reason == NULL ? NULL : &reason_str,
        NULL);
  }
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to reject SIP call", status);
    return false;
  }

  if (runtime != NULL) {
    dart_edge_sip_bridge_event event;
    fill_call_event(runtime, call_id, &event);
    event.call_state = DART_EDGE_SIP_BRIDGE_CALL_REJECTED;
    push_event(runtime, &event);
  }
  return true;
}

bool dart_edge_sip_bridge_hangup_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    uint32_t status_code,
    const char* reason,
    char* error,
    size_t error_len) {
  (void)runtime;
  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_str_t reason_str = pj_str((char*)(reason == NULL ? "" : reason));
  pj_status_t status = pjsua_call_hangup(
      call_id,
      status_code,
      reason == NULL ? NULL : &reason_str,
      NULL);
  if (status == PJSIP_ESESSIONTERMINATED) {
    if (runtime != NULL) {
      dart_edge_sip_bridge_event event;
      fill_call_event(runtime, call_id, &event);
      event.call_state = DART_EDGE_SIP_BRIDGE_CALL_TERMINATED;
      push_event(runtime, &event);
    }
    return true;
  }
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to hang up SIP call", status);
    return false;
  }
  return true;
}

bool dart_edge_sip_bridge_bridge_calls(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* other_session_id,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }

  pjsua_call_id first_call_id;
  pjsua_call_id second_call_id;
  if (!session_id_to_call_id(session_id, &first_call_id) ||
      !session_id_to_call_id(other_session_id, &second_call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pjsua_conf_port_id first_port = pjsua_call_get_conf_port(first_call_id);
  pjsua_conf_port_id second_port = pjsua_call_get_conf_port(second_call_id);
  if (first_port == PJSUA_INVALID_ID || second_port == PJSUA_INVALID_ID) {
    store_error(error, error_len, "Both calls must have active media before bridging.");
    return false;
  }

  pj_status_t status = pjsua_conf_connect(first_port, second_port);
  if (status == PJ_SUCCESS) {
    status = pjsua_conf_connect(second_port, first_port);
  }
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to bridge SIP calls", status);
    return false;
  }

  dart_edge_sip_bridge_call_slot* first_slot = slot_for_call(runtime, first_call_id);
  dart_edge_sip_bridge_call_slot* second_slot = slot_for_call(runtime, second_call_id);
  if (first_slot != NULL) {
    first_slot->bridged = true;
  }
  if (second_slot != NULL) {
    second_slot->bridged = true;
  }

  dart_edge_sip_bridge_event first_event;
  fill_call_event(runtime, first_call_id, &first_event);
  first_event.call_state = DART_EDGE_SIP_BRIDGE_CALL_BRIDGED;
  copy_text(first_event.related_call_id, sizeof(first_event.related_call_id), other_session_id);
  push_event(runtime, &first_event);

  dart_edge_sip_bridge_event second_event;
  fill_call_event(runtime, second_call_id, &second_event);
  second_event.call_state = DART_EDGE_SIP_BRIDGE_CALL_BRIDGED;
  copy_text(second_event.related_call_id, sizeof(second_event.related_call_id), session_id);
  push_event(runtime, &second_event);
  return true;
}

bool dart_edge_sip_bridge_hold_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len) {
  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_status_t status = pjsua_call_set_hold(call_id, NULL);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to place SIP call on hold", status);
    return false;
  }

  if (runtime != NULL) {
    dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
    if (slot != NULL) {
      slot->on_hold = true;
      slot->bridged = false;
    }
    dart_edge_sip_bridge_event event;
    fill_call_event(runtime, call_id, &event);
    event.call_state = DART_EDGE_SIP_BRIDGE_CALL_ON_HOLD;
    push_event(runtime, &event);
  }
  return true;
}

bool dart_edge_sip_bridge_resume_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len) {
  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_status_t status = pjsua_call_reinvite(call_id, PJSUA_CALL_UNHOLD, NULL);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to resume SIP call", status);
    return false;
  }

  if (runtime != NULL) {
    dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
    if (slot != NULL) {
      slot->on_hold = false;
    }
    dart_edge_sip_bridge_event event;
    fill_call_event(runtime, call_id, &event);
    event.call_state = DART_EDGE_SIP_BRIDGE_CALL_ESTABLISHED;
    push_event(runtime, &event);
  }
  return true;
}

bool dart_edge_sip_bridge_transfer_call(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* target_uri,
    const char* attended_session_id,
    char* error,
    size_t error_len) {
  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  pj_status_t status = PJ_SUCCESS;
  if (attended_session_id != NULL && attended_session_id[0] != '\0') {
    pjsua_call_id attended_call_id;
    if (!session_id_to_call_id(attended_session_id, &attended_call_id)) {
      store_error(error, error_len, "Invalid attended SIP call session ID.");
      return false;
    }
    status = pjsua_call_xfer_replaces(call_id, attended_call_id, 0, NULL);
  } else {
    if (target_uri == NULL || target_uri[0] == '\0') {
      store_error(error, error_len, "transfer requires a target URI.");
      return false;
    }
    pj_str_t target = pj_str((char*)target_uri);
    status = pjsua_call_xfer(call_id, &target, NULL);
  }

  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to transfer SIP call", status);
    return false;
  }

  if (runtime != NULL) {
    dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
    if (slot != NULL) {
      slot->transfer_pending = true;
      slot->bridged = false;
    }
    dart_edge_sip_bridge_event event;
    fill_call_event(runtime, call_id, &event);
    event.call_state = DART_EDGE_SIP_BRIDGE_CALL_TRANSFERRING;
    push_event(runtime, &event);
  }
  return true;
}

bool dart_edge_sip_bridge_play_prompt(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* prompt_id,
    const char* media_uri,
    char* error,
    size_t error_len) {
  (void)prompt_id;
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  const char* resolved_uri = media_uri;
  if ((resolved_uri == NULL || resolved_uri[0] == '\0') &&
      runtime->config.default_greeting_uri != NULL) {
    resolved_uri = runtime->config.default_greeting_uri;
  }
  if (resolved_uri == NULL || resolved_uri[0] == '\0') {
    store_error(error, error_len, "playPrompt requires mediaUri or a configured default greeting.");
    return false;
  }

  const char* file_path = uri_to_path(resolved_uri);
  pj_str_t file_name = pj_str((char*)file_path);
  pjsua_player_id player_id = PJSUA_INVALID_ID;
  pj_status_t status = pjsua_player_create(&file_name, 0, &player_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to create SIP prompt player", status);
    return false;
  }

  pjsua_conf_port_id player_port = pjsua_player_get_conf_port(player_id);
  pjsua_conf_port_id call_port = pjsua_call_get_conf_port(call_id);
  if (call_port == PJSUA_INVALID_ID) {
    pjsua_player_destroy(player_id);
    store_error(error, error_len, "Call media is not active; cannot play prompt.");
    return false;
  }

  status = pjsua_conf_connect(player_port, call_port);
  if (status != PJ_SUCCESS) {
    pjsua_player_destroy(player_id);
    store_status_error(error, error_len, "Failed to connect prompt player to call", status);
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot != NULL) {
    if (slot->has_player && slot->player_id != PJSUA_INVALID_ID) {
      pjsua_player_destroy(slot->player_id);
    }
    slot->has_player = true;
    slot->player_id = player_id;
  }
  return true;
}

bool dart_edge_sip_bridge_start_recording(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* recording_id,
    const char* destination_uri,
    char* storage_uri,
    size_t storage_uri_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL) {
    store_error(error, error_len, "Unknown SIP call session.");
    return false;
  }
  if (slot->has_recorder) {
    store_error(error, error_len, "Recording is already active for this call.");
    return false;
  }

  char path[1024];
  path[0] = '\0';
  if (destination_uri != NULL && destination_uri[0] != '\0') {
    copy_text(path, sizeof(path), uri_to_path(destination_uri));
  } else {
    if (runtime->config.recording_directory == NULL ||
        runtime->config.recording_directory[0] == '\0') {
      store_error(error, error_len, "Recording requires destinationUri or a configured recording directory.");
      return false;
    }
    if (!create_recording_path(
            runtime->config.recording_directory,
            recording_id,
            path,
            sizeof(path),
            error,
            error_len)) {
      return false;
    }
  }

  pj_str_t file_name = pj_str(path);
  pjsua_recorder_id recorder_id = PJSUA_INVALID_ID;
  pj_status_t status = pjsua_recorder_create(&file_name, 0, NULL, 0, 0, &recorder_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to create SIP recorder", status);
    return false;
  }

  pjsua_conf_port_id recorder_port = pjsua_recorder_get_conf_port(recorder_id);
  pjsua_conf_port_id call_port = pjsua_call_get_conf_port(call_id);
  if (call_port == PJSUA_INVALID_ID) {
    pjsua_recorder_destroy(recorder_id);
    store_error(error, error_len, "Call media is not active; cannot start recording.");
    return false;
  }

  status = pjsua_conf_connect(call_port, recorder_port);
  if (status != PJ_SUCCESS) {
    pjsua_recorder_destroy(recorder_id);
    store_status_error(error, error_len, "Failed to connect recorder to call", status);
    return false;
  }

  slot->has_recorder = true;
  slot->recorder_id = recorder_id;
  copy_text(slot->recording_id, sizeof(slot->recording_id), recording_id);
  copy_text(slot->recording_path, sizeof(slot->recording_path), path);
  copy_text(storage_uri, storage_uri_len, path);
  emit_recording_event(
      runtime,
      call_id,
      DART_EDGE_SIP_BRIDGE_RECORDING_STARTED,
      recording_id,
      path);
  return true;
}

bool dart_edge_sip_bridge_send_to_voicemail(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* mailbox,
    char* storage_uri,
    size_t storage_uri_len,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }
  if (runtime->config.voicemail_directory == NULL ||
      runtime->config.voicemail_directory[0] == '\0') {
    store_error(error, error_len, "Voicemail requires a configured voicemail directory.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL) {
    store_error(error, error_len, "Unknown SIP call session.");
    return false;
  }
  if (slot->has_voicemail_recorder) {
    store_error(error, error_len, "Voicemail recording is already active for this call.");
    return false;
  }

  char message_id[128];
  snprintf(message_id, sizeof(message_id), "%s-%lld", mailbox, (long long)time(NULL));
  char path[1024];
  if (!create_recording_path(
          runtime->config.voicemail_directory,
          message_id,
          path,
          sizeof(path),
          error,
          error_len)) {
    return false;
  }

  pj_str_t file_name = pj_str(path);
  pjsua_recorder_id recorder_id = PJSUA_INVALID_ID;
  pj_status_t status = pjsua_recorder_create(&file_name, 0, NULL, 0, 0, &recorder_id);
  if (status != PJ_SUCCESS) {
    store_status_error(error, error_len, "Failed to create voicemail recorder", status);
    return false;
  }

  pjsua_conf_port_id recorder_port = pjsua_recorder_get_conf_port(recorder_id);
  pjsua_conf_port_id call_port = pjsua_call_get_conf_port(call_id);
  if (call_port == PJSUA_INVALID_ID) {
    pjsua_recorder_destroy(recorder_id);
    store_error(error, error_len, "Call media is not active; cannot start voicemail.");
    return false;
  }

  status = pjsua_conf_connect(call_port, recorder_port);
  if (status != PJ_SUCCESS) {
    pjsua_recorder_destroy(recorder_id);
    store_status_error(error, error_len, "Failed to connect voicemail recorder", status);
    return false;
  }

  slot->has_voicemail_recorder = true;
  slot->voicemail_recorder_id = recorder_id;
  copy_text(slot->mailbox, sizeof(slot->mailbox), mailbox);
  copy_text(slot->voicemail_path, sizeof(slot->voicemail_path), path);
  copy_text(slot->voicemail_message_id, sizeof(slot->voicemail_message_id), message_id);
  copy_text(storage_uri, storage_uri_len, path);

  if (runtime->config.default_greeting_uri != NULL &&
      runtime->config.default_greeting_uri[0] != '\0') {
    dart_edge_sip_bridge_play_prompt(
        runtime,
        session_id,
        "defaultGreeting",
        runtime->config.default_greeting_uri,
        error,
        error_len);
  }

  emit_voicemail_event(
      runtime,
      call_id,
      DART_EDGE_SIP_BRIDGE_VOICEMAIL_QUEUED,
      mailbox,
      message_id,
      path);
  return true;
}

bool dart_edge_sip_bridge_attach_media_app(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const char* media_app_id,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }
  if (media_app_id == NULL || media_app_id[0] == '\0') {
    store_error(error, error_len, "attachMediaApp requires a mediaAppId.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL) {
    store_error(error, error_len, "Unknown SIP call session.");
    return false;
  }

  slot->media_session_active = true;
  copy_text(slot->media_app_id, sizeof(slot->media_app_id), media_app_id);
  slot->media_frame_sequence = 0;

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot != NULL) {
    clear_media_streams(media_slot);
  }
  if (!ensure_media_ports_connected(runtime, call_id, slot, error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_event event;
  fill_call_event(runtime, call_id, &event);
  push_event(runtime, &event);
  return true;
}

bool dart_edge_sip_bridge_detach_media_app(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL) {
    store_error(error, error_len, "Unknown SIP call session.");
    return false;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot != NULL) {
    clear_media_streams(media_slot);
  }
  slot->media_frame_sequence = 0;
  slot->media_session_active = false;
  slot->media_app_id[0] = '\0';

  dart_edge_sip_bridge_event event;
  fill_call_event(runtime, call_id, &event);
  push_event(runtime, &event);
  return true;
}

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
    size_t error_len) {
  if (bytes_written != NULL) {
    *bytes_written = 0;
  }
  if (sample_rate_hz != NULL) {
    *sample_rate_hz = DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ;
  }
  if (channels != NULL) {
    *channels = DART_EDGE_SIP_MEDIA_CHANNELS;
  }
  if (frame_duration_ms != NULL) {
    *frame_duration_ms = DART_EDGE_SIP_MEDIA_FRAME_DURATION_MS;
  }
  if (sequence != NULL) {
    *sequence = 0;
  }

  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }
  if (buffer == NULL) {
    store_error(error, error_len, "Missing SIP media frame buffer.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL || !slot->media_session_active) {
    store_error(error, error_len, "No SIP media app is attached to this call.");
    return false;
  }

  size_t frame_bytes =
      media_bytes_per_frame(DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ, DART_EDGE_SIP_MEDIA_CHANNELS);
  if (buffer_len < frame_bytes) {
    store_error(error, error_len, "SIP media frame buffer is too small.");
    return false;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot == NULL || media_slot->inbound_port == NULL) {
    store_error(error, error_len, "SIP media capture port is not initialized.");
    return false;
  }
  if (!audio_ring_read_exact(&media_slot->inbound_port->ring, buffer, frame_bytes)) {
    return true;
  }

  slot->media_frame_sequence += 1;
  if (bytes_written != NULL) {
    *bytes_written = frame_bytes;
  }
  if (sequence != NULL) {
    *sequence = slot->media_frame_sequence;
  }
  return true;
}

bool dart_edge_sip_bridge_play_raw_audio(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    const uint8_t* bytes,
    size_t bytes_len,
    uint32_t sample_rate_hz,
    uint32_t channels,
    uint32_t frame_duration_ms,
    char* error,
    size_t error_len) {
  (void)frame_duration_ms;
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }
  if (bytes == NULL || bytes_len == 0) {
    store_error(error, error_len, "SIP media playback requires non-empty audio bytes.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }
  if (!ensure_current_thread_registered(error, error_len)) {
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL || !slot->media_session_active) {
    store_error(error, error_len, "No SIP media app is attached to this call.");
    return false;
  }

  if (sample_rate_hz != DART_EDGE_SIP_MEDIA_SAMPLE_RATE_HZ ||
      channels != DART_EDGE_SIP_MEDIA_CHANNELS) {
    store_error(
        error,
        error_len,
        "Realtime SIP media playback currently requires 16 kHz mono PCM16 audio.");
    return false;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot == NULL || media_slot->outbound_port == NULL) {
    store_error(error, error_len, "SIP media playback port is not initialized.");
    return false;
  }
  if (!ensure_media_ports_connected(runtime, call_id, slot, error, error_len)) {
    return false;
  }

  audio_ring_write(&media_slot->outbound_port->ring, bytes, bytes_len);
  return true;
}

bool dart_edge_sip_bridge_clear_raw_audio(
    dart_edge_sip_bridge_runtime* runtime,
    const char* session_id,
    char* error,
    size_t error_len) {
  if (runtime == NULL) {
    store_error(error, error_len, "Missing PJSIP runtime.");
    return false;
  }

  pjsua_call_id call_id;
  if (!session_id_to_call_id(session_id, &call_id)) {
    store_error(error, error_len, "Invalid SIP call session ID.");
    return false;
  }

  dart_edge_sip_bridge_call_slot* slot = slot_for_call(runtime, call_id);
  if (slot == NULL || !slot->media_session_active) {
    store_error(error, error_len, "No SIP media app is attached to this call.");
    return false;
  }

  dart_edge_sip_bridge_media_slot* media_slot = media_slot_for_call(runtime, call_id);
  if (media_slot == NULL || media_slot->outbound_port == NULL) {
    store_error(error, error_len, "SIP media playback port is not initialized.");
    return false;
  }

  audio_ring_clear(&media_slot->outbound_port->ring);
  return true;
}

bool dart_edge_sip_bridge_poll_event(
    dart_edge_sip_bridge_runtime* runtime,
    dart_edge_sip_bridge_event* event_out) {
  return pop_event(runtime, event_out);
}
