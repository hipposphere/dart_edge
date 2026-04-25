#ifndef DART_EDGE_S3_CLIENT_H_
#define DART_EDGE_S3_CLIENT_H_

#include "../../../../crates/dart_edge_core/include/dart_edge_core_ffi.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct NativeS3BytesResult {
  NativeOwnedBytes bytes;
  char* result_json;
} NativeS3BytesResult;

int32_t dart_edge_s3_client_native_abi_version(void);

int64_t dart_edge_s3_client_create(const char* config_json);

void dart_edge_s3_client_dispose(int64_t handle);

char* dart_edge_s3_client_put_object_bytes(
    int64_t handle,
    const char* request_json,
    const uint8_t* bytes_ptr,
    intptr_t bytes_len);

NativeS3BytesResult* dart_edge_s3_client_get_object_bytes(
    int64_t handle,
    const char* request_json);

char* dart_edge_s3_client_head_object(
    int64_t handle,
    const char* request_json);

char* dart_edge_s3_client_delete_object(
    int64_t handle,
    const char* request_json);

void dart_edge_s3_client_free_bytes_result(NativeS3BytesResult* value);

char* dart_edge_s3_client_take_last_error(void);

void dart_edge_s3_client_free_string(char* value);

#endif  // DART_EDGE_S3_CLIENT_H_
