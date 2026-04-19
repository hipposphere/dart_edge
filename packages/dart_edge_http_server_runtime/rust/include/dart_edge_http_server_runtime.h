#ifndef DART_EDGE_HTTP_SERVER_RUNTIME_H_
#define DART_EDGE_HTTP_SERVER_RUNTIME_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef void (*dart_edge_http_server_runtime_request_ready_callback_t)(int64_t request_id);

typedef struct NativeBytes {
  const uint8_t* ptr;
  intptr_t len;
} NativeBytes;

typedef struct NativePair {
  NativeBytes key;
  NativeBytes value;
} NativePair;

typedef struct NativeTransportRequest {
  NativeBytes route_id;
  intptr_t path_param_count;
  const NativePair* path_params;
  intptr_t query_count;
  const NativePair* query;
  intptr_t header_count;
  const NativePair* headers;
  NativeBytes body;
  uint8_t body_kind;
} NativeTransportRequest;

int32_t dart_edge_http_server_runtime_native_abi_version(void);

int64_t dart_edge_http_server_runtime_start_server(
    const char* host,
    int64_t port,
    int64_t worker_count,
    const char* routes_json,
    dart_edge_http_server_runtime_request_ready_callback_t callback);

void dart_edge_http_server_runtime_stop_server(void);

NativeTransportRequest* dart_edge_http_server_runtime_take_request(int64_t request_id);

void dart_edge_http_server_runtime_free_request(NativeTransportRequest* value);

bool dart_edge_http_server_runtime_send_response(
    int64_t request_id,
    int32_t status,
    const char* content_type,
    const char* body,
    intptr_t header_count,
    const NativePair* headers);

#endif  // DART_EDGE_HTTP_SERVER_RUNTIME_H_
