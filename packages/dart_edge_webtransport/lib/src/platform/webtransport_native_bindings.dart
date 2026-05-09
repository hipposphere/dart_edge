// ignore_for_file: camel_case_types, non_constant_identifier_names

@ffi.DefaultAsset('package:dart_edge_webtransport/dart_edge_webtransport.dart')
library;

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

final class NativeWebTransportConnectConfig extends ffi.Struct {
  external ffi.Pointer<Utf8> url;

  external ffi.Pointer<Utf8> headers_json;

  @ffi.Bool()
  external bool allow_self_signed;
}

final class NativeWebTransportConnectResult extends ffi.Struct {
  @ffi.Int64()
  external int handle;

  external ffi.Pointer<ffi.Char> error;
}

final class NativeWebTransportBytesResult extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> bytes;

  @ffi.Int64()
  external int length;

  external ffi.Pointer<ffi.Char> error;
}

@ffi.Native<
  ffi.Pointer<NativeWebTransportConnectResult> Function(
    ffi.Pointer<NativeWebTransportConnectConfig>,
  )
>()
external ffi.Pointer<NativeWebTransportConnectResult>
dart_edge_webtransport_connect(
  ffi.Pointer<NativeWebTransportConnectConfig> config,
);

@ffi.Native<ffi.Void Function(ffi.Int64)>(isLeaf: true)
external void dart_edge_webtransport_dispose(int handle);

@ffi.Native<
  ffi.Pointer<ffi.Char> Function(ffi.Int64, ffi.Pointer<ffi.Uint8>, ffi.Int64)
>()
external ffi.Pointer<ffi.Char> dart_edge_webtransport_send_datagram(
  int handle,
  ffi.Pointer<ffi.Uint8> bytes,
  int length,
);

@ffi.Native<
  ffi.Pointer<ffi.Char> Function(ffi.Int64, ffi.Pointer<ffi.Uint8>, ffi.Int64)
>()
external ffi.Pointer<ffi.Char> dart_edge_webtransport_send_stream(
  int handle,
  ffi.Pointer<ffi.Uint8> bytes,
  int length,
);

@ffi.Native<ffi.Pointer<NativeWebTransportBytesResult> Function(ffi.Int64)>()
external ffi.Pointer<NativeWebTransportBytesResult>
dart_edge_webtransport_receive_datagram(int handle);

@ffi.Native<ffi.Pointer<NativeWebTransportBytesResult> Function(ffi.Int64)>()
external ffi.Pointer<NativeWebTransportBytesResult>
dart_edge_webtransport_receive_stream(int handle);

@ffi.Native<
  ffi.Pointer<ffi.Char> Function(ffi.Int64, ffi.Int64, ffi.Pointer<Utf8>)
>()
external ffi.Pointer<ffi.Char> dart_edge_webtransport_close(
  int handle,
  int code,
  ffi.Pointer<Utf8> reason,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<NativeWebTransportConnectResult>)>(
  isLeaf: true,
)
external void dart_edge_webtransport_free_connect_result(
  ffi.Pointer<NativeWebTransportConnectResult> value,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<NativeWebTransportBytesResult>)>(
  isLeaf: true,
)
external void dart_edge_webtransport_free_bytes_result(
  ffi.Pointer<NativeWebTransportBytesResult> value,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Char>)>(isLeaf: true)
external void dart_edge_webtransport_free_string(ffi.Pointer<ffi.Char> value);
