#ifndef DART_EDGE_AUTH_H_
#define DART_EDGE_AUTH_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct NativeBytes {
  const uint8_t* ptr;
  intptr_t len;
} NativeBytes;

typedef struct NativePair {
  NativeBytes key;
  NativeBytes value;
} NativePair;

typedef struct NativeAuthResponse {
  uint16_t status;
  NativeBytes content_type;
  intptr_t header_count;
  const NativePair* headers;
  NativeBytes body;
} NativeAuthResponse;

typedef char* (*dart_edge_auth_shared_execute_pool_fn)(int64_t handle, const char* statement_json);
typedef char* (*dart_edge_auth_shared_take_last_error_fn)(void);
typedef void (*dart_edge_auth_shared_free_string_fn)(char* value);

int32_t dart_edge_auth_native_abi_version(void);

int64_t dart_edge_auth_create(const char* config_json);
int64_t dart_edge_auth_create_with_shared_database(
    const char* config_json,
    int32_t dialect,
    int64_t database_handle,
    dart_edge_auth_shared_execute_pool_fn execute_pool,
    dart_edge_auth_shared_take_last_error_fn take_last_error,
    dart_edge_auth_shared_free_string_fn free_string);

void dart_edge_auth_dispose(int64_t handle);

char* dart_edge_auth_list_routes(int64_t handle);

NativeAuthResponse* dart_edge_auth_handle_request(
    int64_t handle,
    int32_t method,
    const char* path,
    intptr_t query_count,
    const NativePair* query,
    intptr_t header_count,
    const NativePair* headers,
    const uint8_t* body_ptr,
    intptr_t body_len);

void dart_edge_auth_free_response(NativeAuthResponse* value);

char* dart_edge_auth_take_last_error(void);

void dart_edge_auth_free_string(char* value);

#endif  // DART_EDGE_AUTH_H_
