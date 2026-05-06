/// Shared Dart FFI value types for Dart Edge native packages.
library dart_edge_native_bridge;

export 'src/ffi/generated_bindings.dart'
    show NativeBytes, NativeOwnedBytes, NativePair;
export 'src/ffi/native_value_helpers.dart'
    show
        NativeAllocations,
        NativeStringPair,
        NativeStringPairs,
        copyNativeOwnedBytes,
        copyNativePairs,
        decodeNativeUtf8,
        maybeCopyNativeBytes,
        optionalNativeString,
        requiredNativeString;
