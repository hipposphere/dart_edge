/// Shared Dart FFI value types for Dart Edge native packages.
///
/// Import this library when you need the common `NativeBytes`,
/// `NativeOwnedBytes`, and `NativePair` structs or the small decoding helpers
/// that sit on top of them.
library dart_edge_core_ffi;

export 'src/ffi/generated_bindings.dart'
    show NativeBytes, NativeOwnedBytes, NativePair;
export 'src/ffi/native_value_helpers.dart'
    show
        NativeStringPair,
        copyNativeOwnedBytes,
        copyNativePairs,
        decodeNativeUtf8,
        maybeCopyNativeBytes;
