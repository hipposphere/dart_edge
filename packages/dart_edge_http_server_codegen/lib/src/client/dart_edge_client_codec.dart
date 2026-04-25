typedef DartEdgeClientEncoder<T> = Object? Function(T value);
typedef DartEdgeClientDecoder<T> = T Function(Object? value);

/// Codec used by generated clients to encode request values and decode
/// responses for one schema-backed Dart type.
final class DartEdgeClientCodec<T> {
  const DartEdgeClientCodec({required this.encode, required this.decode});

  final DartEdgeClientEncoder<T> encode;
  final DartEdgeClientDecoder<T> decode;
}

/// Registry of schema-id keyed codecs used by generated clients.
final class DartEdgeClientCodecRegistry {
  const DartEdgeClientCodecRegistry([
    Map<String, _ErasedDartEdgeClientCodec> codecs =
        const <String, _ErasedDartEdgeClientCodec>{},
  ]) : _codecs = codecs;

  final Map<String, _ErasedDartEdgeClientCodec> _codecs;

  static const empty = DartEdgeClientCodecRegistry();

  DartEdgeClientCodecRegistry withCodec<T>(
    String schemaId,
    DartEdgeClientCodec<T> codec,
  ) {
    return DartEdgeClientCodecRegistry({
      ..._codecs,
      schemaId: _ErasedDartEdgeClientCodec(
        encode: (value) => codec.encode(value as T),
        decode: codec.decode,
      ),
    });
  }

  Object? encodeValue(String schemaId, Object? value) {
    if (value == null) {
      return null;
    }

    final codec = _codecs[schemaId];
    if (codec == null) {
      return value;
    }

    return codec.encode(value);
  }

  T decodeValue<T>(String schemaId, Object? value) {
    final codec = _codecs[schemaId];
    if (codec == null) {
      throw StateError('No client codec registered for schema "$schemaId".');
    }

    return codec.decode(value) as T;
  }
}

final class _ErasedDartEdgeClientCodec {
  const _ErasedDartEdgeClientCodec({
    required this.encode,
    required this.decode,
  });

  final Object? Function(Object? value) encode;
  final Object? Function(Object? value) decode;
}
