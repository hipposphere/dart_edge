# dart_edge_native_bridge

Shared Dart FFI structs and pointer helpers for Dart Edge native packages.

Import this package when a native-backed package needs the common `NativeBytes`,
`NativeOwnedBytes`, and `NativePair` ABI types or the decoding helpers that sit
on top of them.

`NativeByteStreamHandle` represents a versioned, single-owner native pull
stream. It can expose copied Dart chunks through `openRead()` or transfer its
descriptor to another native asset through `takeDescriptor()`, but it cannot be
consumed in both modes.

This package intentionally does not own build hooks or native asset
compilation. Use `dart_edge_native_assets` for package-local native build
helpers.
