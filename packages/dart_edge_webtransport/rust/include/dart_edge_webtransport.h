#ifndef DART_EDGE_WEBTRANSPORT_H
#define DART_EDGE_WEBTRANSPORT_H

#include <stdbool.h>
#include <stdint.h>

typedef void (*dart_edge_webtransport_event_callback_t)(int32_t event_kind,
                                                        int64_t event_id);

typedef struct NativeWebTransportConnectConfig {
  char* url;
  char* headers_json;
  bool allow_self_signed;
  dart_edge_webtransport_event_callback_t callback;
} NativeWebTransportConnectConfig;

typedef struct NativeWebTransportConnectResult {
  int64_t handle;
  char* error;
} NativeWebTransportConnectResult;

typedef struct NativeWebTransportBytesResult {
  uint8_t* bytes;
  int64_t length;
  char* error;
} NativeWebTransportBytesResult;

typedef struct NativeWebTransportStreamInfo {
  int64_t session_id;
  int64_t stream_id;
  int64_t protocol_id;
  uint8_t kind;
} NativeWebTransportStreamInfo;

typedef struct NativeWebTransportStreamChunk {
  int64_t stream_id;
  uint8_t* bytes;
  int64_t length;
} NativeWebTransportStreamChunk;

typedef struct NativeWebTransportStreamTerminal {
  int64_t stream_id;
  int64_t error_code;
  char* error;
} NativeWebTransportStreamTerminal;

typedef struct NativeWebTransportOperation {
  int64_t operation_id;
  int64_t session_id;
  int64_t stream_id;
  int64_t protocol_id;
  uint8_t kind;
  bool succeeded;
  char* error;
} NativeWebTransportOperation;

int64_t dart_edge_webtransport_native_abi_version(void);

NativeWebTransportConnectResult* dart_edge_webtransport_connect(
    const NativeWebTransportConnectConfig* config);

void dart_edge_webtransport_dispose(int64_t handle);

char* dart_edge_webtransport_send_datagram(int64_t handle,
                                           const uint8_t* bytes,
                                           int64_t length);

NativeWebTransportBytesResult* dart_edge_webtransport_take_datagram(
    int64_t handle);

int64_t dart_edge_webtransport_open_unidirectional_stream(
    int64_t session_id,
    int64_t send_order,
    bool has_send_order);

int64_t dart_edge_webtransport_open_bidirectional_stream(
    int64_t session_id,
    int64_t send_order,
    bool has_send_order);

int64_t dart_edge_webtransport_stream_write(int64_t stream_id,
                                            const uint8_t* bytes,
                                            int64_t length);

int64_t dart_edge_webtransport_stream_finish(int64_t stream_id);

int64_t dart_edge_webtransport_stream_reset(int64_t stream_id,
                                            uint32_t error_code);

int64_t dart_edge_webtransport_stream_stop(int64_t stream_id,
                                           uint32_t error_code);

NativeWebTransportStreamInfo* dart_edge_webtransport_take_stream_info(
    int64_t stream_id);

void dart_edge_webtransport_free_stream_info(
    NativeWebTransportStreamInfo* value);

NativeWebTransportStreamChunk* dart_edge_webtransport_take_stream_chunk(
    int64_t stream_id);

void dart_edge_webtransport_free_stream_chunk(
    NativeWebTransportStreamChunk* value);

NativeWebTransportStreamTerminal* dart_edge_webtransport_take_stream_terminal(
    int64_t stream_id);

void dart_edge_webtransport_free_stream_terminal(
    NativeWebTransportStreamTerminal* value);

NativeWebTransportOperation* dart_edge_webtransport_take_operation(
    int64_t operation_id);

void dart_edge_webtransport_free_operation(NativeWebTransportOperation* value);

char* dart_edge_webtransport_close(int64_t handle,
                                   int64_t code,
                                   const char* reason);

void dart_edge_webtransport_free_connect_result(
    NativeWebTransportConnectResult* value);

void dart_edge_webtransport_free_bytes_result(
    NativeWebTransportBytesResult* value);

void dart_edge_webtransport_free_string(char* value);

#endif
