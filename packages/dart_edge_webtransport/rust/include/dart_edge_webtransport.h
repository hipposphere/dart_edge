#ifndef DART_EDGE_WEBTRANSPORT_H
#define DART_EDGE_WEBTRANSPORT_H

#include <stdbool.h>
#include <stdint.h>

typedef struct NativeWebTransportConnectConfig {
  char* url;
  char* headers_json;
  bool allow_self_signed;
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

int64_t dart_edge_webtransport_native_abi_version(void);

NativeWebTransportConnectResult* dart_edge_webtransport_connect(
    NativeWebTransportConnectConfig* config);

void dart_edge_webtransport_dispose(int64_t handle);

char* dart_edge_webtransport_send_datagram(int64_t handle, uint8_t* bytes, int64_t length);

NativeWebTransportBytesResult* dart_edge_webtransport_receive_datagram(int64_t handle);

char* dart_edge_webtransport_close(int64_t handle, int64_t code, char* reason);

void dart_edge_webtransport_free_connect_result(NativeWebTransportConnectResult* value);

void dart_edge_webtransport_free_bytes_result(NativeWebTransportBytesResult* value);

void dart_edge_webtransport_free_string(char* value);

#endif
