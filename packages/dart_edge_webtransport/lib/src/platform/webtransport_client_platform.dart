import '../webtransport_client.dart';

/// Fallback implementation used when neither browser nor native bindings exist.
final class PlatformWebTransportClient implements DartEdgeWebTransportClient {
  const PlatformWebTransportClient({bool allowSelfSignedCertificates = false});

  @override
  Future<DartEdgeWebTransportSession> connect(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) {
    throw const DartEdgeWebTransportException(
      'WebTransport is not supported on this platform.',
    );
  }
}
