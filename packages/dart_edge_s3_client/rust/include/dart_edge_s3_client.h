#ifndef DART_EDGE_S3_CLIENT_H_
#define DART_EDGE_S3_CLIENT_H_

#include <dart_edge_core_ffi.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct NativeS3StringPair {
  const char* key;
  const char* value;
} NativeS3StringPair;

typedef struct NativeS3ClientConfig {
  const char* region;
  const char* endpoint;
  const char* access_key_id;
  const char* secret_access_key;
  const char* session_token;
  bool force_path_style;
  bool allow_http;
} NativeS3ClientConfig;

typedef struct NativeS3ObjectRef {
  const char* bucket;
  const char* key;
  const char* version_id;
} NativeS3ObjectRef;

typedef struct NativeS3PutObjectRequest {
  const char* bucket;
  const char* key;
  const char* content_type;
  const char* cache_control;
  const char* content_disposition;
  const char* content_encoding;
  const char* content_language;
  const NativeS3StringPair* metadata;
  intptr_t metadata_len;
} NativeS3PutObjectRequest;

typedef struct NativeS3CreateResult {
  int64_t handle;
  char* error;
} NativeS3CreateResult;

typedef struct NativeS3PutObjectResult {
  char* bucket;
  char* key;
  char* e_tag;
  char* version_id;
  char* error;
} NativeS3PutObjectResult;

typedef struct NativeS3DeleteObjectResult {
  char* bucket;
  char* key;
  bool has_delete_marker;
  bool delete_marker;
  char* version_id;
  char* error;
} NativeS3DeleteObjectResult;

typedef struct NativeS3ObjectMetadata {
  char* bucket;
  char* key;
  char* version_id;
  char* e_tag;
  char* content_type;
  int64_t content_length;
  char* cache_control;
  char* content_disposition;
  char* content_encoding;
  char* content_language;
  NativeS3StringPair* metadata;
  intptr_t metadata_len;
  char* error;
} NativeS3ObjectMetadata;

typedef struct NativeS3BytesResult {
  NativeOwnedBytes bytes;
  NativeS3ObjectMetadata metadata;
  char* error;
} NativeS3BytesResult;

typedef struct NativeS3StreamStartResult {
  int64_t download_handle;
  NativeS3ObjectMetadata metadata;
  char* error;
} NativeS3StreamStartResult;

typedef struct NativeS3NativeStreamStartResult {
  NativeByteStream stream;
  NativeS3ObjectMetadata metadata;
  char* error;
} NativeS3NativeStreamStartResult;

typedef struct NativeS3StreamChunkResult {
  NativeOwnedBytes bytes;
  bool done;
  char* error;
} NativeS3StreamChunkResult;

int32_t dart_edge_s3_client_native_abi_version(void);

NativeS3CreateResult* dart_edge_s3_client_create(
    const NativeS3ClientConfig* config);

void dart_edge_s3_client_dispose(int64_t handle);

int64_t dart_edge_s3_client_active_download_count(void);

int64_t dart_edge_s3_client_downloads_started_count(void);

int64_t dart_edge_s3_client_downloads_completed_count(void);

int64_t dart_edge_s3_client_downloads_canceled_count(void);

int64_t dart_edge_s3_client_downloads_failed_count(void);

NativeS3PutObjectResult* dart_edge_s3_client_put_object_bytes(
    int64_t handle,
    const NativeS3PutObjectRequest* request,
    const uint8_t* bytes_ptr,
    intptr_t bytes_len);

NativeS3BytesResult* dart_edge_s3_client_get_object_bytes(
    int64_t handle,
    const NativeS3ObjectRef* request);

NativeS3StreamStartResult* dart_edge_s3_client_start_get_object_stream(
    int64_t handle,
    const NativeS3ObjectRef* request);

NativeS3NativeStreamStartResult* dart_edge_s3_client_start_get_object_native_stream(
    int64_t handle,
    const NativeS3ObjectRef* request);

NativeS3StreamChunkResult* dart_edge_s3_client_next_get_object_stream_chunk(
    int64_t download_handle);

void dart_edge_s3_client_cancel_get_object_stream(int64_t download_handle);

NativeS3ObjectMetadata* dart_edge_s3_client_head_object(
    int64_t handle,
    const NativeS3ObjectRef* request);

NativeS3DeleteObjectResult* dart_edge_s3_client_delete_object(
    int64_t handle,
    const NativeS3ObjectRef* request);

void dart_edge_s3_client_free_create_result(NativeS3CreateResult* value);

void dart_edge_s3_client_free_put_object_result(NativeS3PutObjectResult* value);

void dart_edge_s3_client_free_delete_object_result(
    NativeS3DeleteObjectResult* value);

void dart_edge_s3_client_free_object_metadata(NativeS3ObjectMetadata* value);

void dart_edge_s3_client_free_bytes_result(NativeS3BytesResult* value);

void dart_edge_s3_client_free_stream_start_result(
    NativeS3StreamStartResult* value);

void dart_edge_s3_client_free_native_stream_start_result(
    NativeS3NativeStreamStartResult* value);

void dart_edge_s3_client_free_stream_chunk_result(
    NativeS3StreamChunkResult* value);

#endif  // DART_EDGE_S3_CLIENT_H_
