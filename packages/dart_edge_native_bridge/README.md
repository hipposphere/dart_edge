# dart_edge_native_bridge

Shared Dart FFI structs and pointer helpers for Dart Edge native packages.

Import this package when a native-backed package needs the common `NativeBytes`,
`NativeOwnedBytes`, and `NativePair` ABI types or the decoding helpers that sit
on top of them.

This package intentionally does not own build hooks or native asset
compilation. Use `dart_edge_native_assets` for package-local native build
helpers.
