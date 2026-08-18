/// Shared Dart FFI value types for Dart Edge native packages.
library;

export 'src/ffi/generated_bindings.dart'
    show
        NativeByteStream,
        NativeByteStreamRead,
        NativeBytes,
        NativeOwnedBytes,
        NativePair;
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
export 'src/native_binary_payload_lease.dart' show NativeBinaryPayloadLease;
export 'src/native_byte_stream_handle.dart'
    show
        NativeByteStreamDescriptor,
        NativeByteStreamDescriptorData,
        NativeByteStreamHandle,
        NativeByteStreamLease;
export 'src/native_completion_port.dart' show NativeCompletionPort;
