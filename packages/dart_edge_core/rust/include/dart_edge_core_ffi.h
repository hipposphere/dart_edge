#ifndef DART_EDGE_CORE_FFI_H_
#define DART_EDGE_CORE_FFI_H_

#include <stddef.h>
#include <stdint.h>

typedef struct NativeBytes {
  const uint8_t* ptr;
  intptr_t len;
} NativeBytes;

typedef struct NativeOwnedBytes {
  uint8_t* ptr;
  intptr_t len;
} NativeOwnedBytes;

typedef struct NativePair {
  NativeBytes key;
  NativeBytes value;
} NativePair;

#endif  // DART_EDGE_CORE_FFI_H_
