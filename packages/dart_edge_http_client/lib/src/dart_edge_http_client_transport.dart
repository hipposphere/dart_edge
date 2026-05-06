import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:http/http.dart' as http;

typedef DartEdgeClientSend =
    Future<DartEdgeClientResponse> Function(DartEdgeClientRequest request);

typedef DartEdgeClientInterceptor =
    Future<DartEdgeClientResponse> Function(
      DartEdgeClientRequest request,
      DartEdgeClientSend next,
    );

/// Sends generated client requests through `package:http`.
final class DartEdgeHttpClientTransport implements DartEdgeClientTransport {
  DartEdgeHttpClientTransport({
    http.Client? client,
    List<DartEdgeClientInterceptor> interceptors = const [],
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _interceptors = List<DartEdgeClientInterceptor>.unmodifiable(
         interceptors,
       );

  final http.Client _client;
  final bool _ownsClient;
  final List<DartEdgeClientInterceptor> _interceptors;

  @override
  Future<DartEdgeClientResponse> send(DartEdgeClientRequest request) {
    DartEdgeClientSend next = _sendWithoutInterceptors;
    for (final interceptor in _interceptors.reversed) {
      final current = next;
      next = (request) => interceptor(request, current);
    }
    return next(request);
  }

  Future<DartEdgeClientResponse> _sendWithoutInterceptors(
    DartEdgeClientRequest request,
  ) async {
    final httpRequest = http.Request(request.method.wireName, request.uri)
      ..headers.addAll(request.headers);

    if (request.body case final body?) {
      httpRequest.body = body;
    }

    final streamed = await _client.send(httpRequest);
    final response = await http.Response.fromStream(streamed);
    return DartEdgeClientResponse(
      status: response.statusCode,
      contentType: response.headers['content-type'] ?? '',
      headers: response.headers,
      body: response.body,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// Adds an `Authorization: Bearer <token>` header to generated client requests.
final class DartEdgeBearerTokenInterceptor {
  const DartEdgeBearerTokenInterceptor(this.token);

  final Future<String?> Function() token;

  Future<DartEdgeClientResponse> call(
    DartEdgeClientRequest request,
    DartEdgeClientSend next,
  ) async {
    final resolvedToken = await token();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      return next(request);
    }
    return next(
      request.copyWith(
        headers: {...request.headers, 'authorization': 'Bearer $resolvedToken'},
      ),
    );
  }
}
