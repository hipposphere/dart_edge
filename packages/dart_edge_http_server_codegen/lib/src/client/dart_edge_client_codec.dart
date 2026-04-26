import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

/// Backwards-compatible client name for the shared schema encoder callback.
typedef DartEdgeClientEncoder<T> = DartEdgeEncoder<T>;

/// Backwards-compatible client name for the shared schema decoder callback.
typedef DartEdgeClientDecoder<T> = DartEdgeDecoder<T>;

/// Client-facing wrapper for a shared schema codec.
final class DartEdgeClientCodec<T> {
  const DartEdgeClientCodec({required this.encode, required this.decode});

  final DartEdgeClientEncoder<T> encode;
  final DartEdgeClientDecoder<T> decode;

  DartEdgeCodec<T> toRuntimeCodec() {
    return DartEdgeCodec<T>(encode: encode, decode: decode);
  }
}

/// Client-facing wrapper around the shared schema-id keyed codec registry.
final class DartEdgeClientCodecRegistry {
  const DartEdgeClientCodecRegistry([
    DartEdgeCodecRegistry registry = DartEdgeCodecRegistry.empty,
  ]) : _registry = registry;

  final DartEdgeCodecRegistry _registry;

  static const empty = DartEdgeClientCodecRegistry();

  DartEdgeClientCodecRegistry withCodec<T>(
    String schemaId,
    DartEdgeClientCodec<T> codec,
  ) {
    return DartEdgeClientCodecRegistry(
      _registry.withCodec<T>(schemaId, codec.toRuntimeCodec()),
    );
  }

  Object? encodeValue(String schemaId, Object? value) {
    return _registry.encodeValue(schemaId, value);
  }

  T decodeValue<T>(String schemaId, Object? value) {
    return _registry.decodeValue<T>(schemaId, value);
  }
}
