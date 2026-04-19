#ifndef DART_EDGE_HTTP_SERVER_RUNTIME_H_
#define DART_EDGE_HTTP_SERVER_RUNTIME_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "../../../dart_edge_core/rust/include/dart_edge_core_ffi.h"

typedef void (*dart_edge_http_server_runtime_transport_event_callback_t)(
    int32_t event_kind,
    int64_t event_id);

typedef struct NativeTransportRequest {
  NativeBytes route_id;
  intptr_t path_param_count;
  const NativePair* path_params;
  intptr_t query_count;
  const NativePair* query;
  intptr_t header_count;
  const NativePair* headers;
  NativeBytes body;
  uint8_t request_kind;
  uint8_t body_kind;
} NativeTransportRequest;

typedef struct NativeWebSocketConnection {
  int64_t session_id;
  int64_t request_id;
  NativeBytes route_id;
  intptr_t path_param_count;
  const NativePair* path_params;
  intptr_t query_count;
  const NativePair* query;
  intptr_t header_count;
  const NativePair* headers;
} NativeWebSocketConnection;

typedef struct NativeWebSocketMessage {
  int64_t session_id;
  NativeBytes body;
} NativeWebSocketMessage;

typedef struct NativeMultipartField {
  NativeBytes name;
  NativeBytes value;
} NativeMultipartField;

typedef struct NativeMultipartFile {
  NativeBytes field_name;
  NativeBytes filename;
  NativeBytes content_type;
  NativeBytes body;
} NativeMultipartFile;

typedef struct NativeMultipartForm {
  intptr_t field_count;
  const NativeMultipartField* fields;
  intptr_t file_count;
  const NativeMultipartFile* files;
} NativeMultipartForm;

int32_t dart_edge_http_server_runtime_native_abi_version(void);

int64_t dart_edge_http_server_runtime_start_server(
    const char* host,
    int64_t port,
    int64_t worker_count,
    const char* routes_json,
    dart_edge_http_server_runtime_transport_event_callback_t callback);

void dart_edge_http_server_runtime_stop_server(void);

NativeTransportRequest* dart_edge_http_server_runtime_take_request(int64_t request_id);

void dart_edge_http_server_runtime_free_request(NativeTransportRequest* value);

bool dart_edge_http_server_runtime_accept_web_socket(
    int64_t request_id,
    intptr_t header_count,
    const NativePair* headers);

bool dart_edge_http_server_runtime_start_sse_response(
    int64_t request_id,
    int32_t status,
    intptr_t header_count,
    const NativePair* headers);

bool dart_edge_http_server_runtime_send_sse_chunk(
    int64_t request_id,
    const char* chunk);

bool dart_edge_http_server_runtime_finish_sse_response(int64_t request_id);

NativeMultipartForm* dart_edge_http_server_runtime_parse_multipart(
    NativeTransportRequest* request,
    const char* content_type);

void dart_edge_http_server_runtime_free_multipart_form(NativeMultipartForm* value);

NativeWebSocketConnection* dart_edge_http_server_runtime_take_web_socket_connection(
    int64_t session_id);

void dart_edge_http_server_runtime_free_web_socket_connection(
    NativeWebSocketConnection* value);

NativeWebSocketMessage* dart_edge_http_server_runtime_take_web_socket_message(
    int64_t session_id);

void dart_edge_http_server_runtime_free_web_socket_message(
    NativeWebSocketMessage* value);

bool dart_edge_http_server_runtime_web_socket_send_text(
    int64_t session_id,
    const char* text);

bool dart_edge_http_server_runtime_web_socket_close(
    int64_t session_id,
    int32_t code,
    const char* reason);

char* dart_edge_http_server_runtime_take_last_error(void);

void dart_edge_http_server_runtime_free_string(char* value);

bool dart_edge_http_server_runtime_send_response(
    int64_t request_id,
    int32_t status,
    const char* content_type,
    const char* body,
    intptr_t header_count,
    const NativePair* headers);

#endif  // DART_EDGE_HTTP_SERVER_RUNTIME_H_
