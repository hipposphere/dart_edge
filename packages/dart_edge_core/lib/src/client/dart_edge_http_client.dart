import 'dart:convert';

import '../http.dart';
import 'dart_edge_client_transport.dart';

/// Base class that typed HTTP clients extend.
abstract base class DartEdgeHttpClientBase {
  const DartEdgeHttpClientBase({
    required this.baseUri,
    required this.transport,
    this.webSocketTransport,
    this.defaultHeaders = const <String, String>{},
  });

  final Uri baseUri;
  final DartEdgeClientTransport transport;
  final DartEdgeClientWebSocketTransport? webSocketTransport;
  final Map<String, String> defaultHeaders;

  Future<TResponse> invoke<TResponse, TParams, TQuery, THeaders, TBody>(
    DartEdgeClientInvocation<TResponse, TParams, TQuery, THeaders, TBody>
    invocation,
  ) async {
    final request = DartEdgeClientRequest(
      method: invocation.method,
      uri: _buildUri(
        invocation.pathTemplate,
        params: invocation.params,
        query: invocation.query,
      ),
      headers: _buildHeaders(
        headers: invocation.headers,
        body: invocation.body,
      ),
      body: _encodeRequestBody(body: invocation.body),
    );

    final response = await transport.send(request);
    if (response.status != invocation.success.status) {
      throw DartEdgeClientResponseException(
        method: invocation.method,
        uri: request.uri,
        expectedStatus: invocation.success.status,
        actualStatus: response.status,
        body: response.body,
      );
    }

    return _decodeResponse<TResponse>(response, success: invocation.success);
  }

  Future<DartEdgeClientWebSocket> connectWebSocket<TParams, TQuery, THeaders>(
    DartEdgeClientWebSocketInvocation<TParams, TQuery, THeaders> invocation,
  ) {
    final transport = webSocketTransport;
    if (transport == null) {
      throw StateError(
        'No DartEdgeClientWebSocketTransport configured for this client.',
      );
    }

    final httpUri = _buildUri(
      invocation.pathTemplate,
      params: invocation.params,
      query: invocation.query,
    );
    return transport.connect(
      DartEdgeClientWebSocketRequest(
        uri: _webSocketUri(httpUri),
        headers: _buildHeaders<THeaders, Never>(
          headers: invocation.headers,
          body: null,
        ),
        protocols: invocation.protocols,
      ),
    );
  }

  Uri _buildUri<TParams, TQuery>(
    String pathTemplate, {
    required DartEdgeClientRequestValue<TParams>? params,
    required DartEdgeClientRequestValue<TQuery>? query,
  }) {
    final resolvedPath = _joinPaths(
      baseUri.path,
      _resolvePathTemplate(pathTemplate, params: params),
    );
    final queryParametersAll = _normalizeQueryValues(_encodeObject(query));

    return baseUri.replace(
      path: resolvedPath,
      query: queryParametersAll.isEmpty
          ? null
          : _encodeQueryString(queryParametersAll),
    );
  }

  Map<String, String> _buildHeaders<THeaders, TBody>({
    required DartEdgeClientRequestValue<THeaders>? headers,
    required DartEdgeClientRequestBody<TBody>? body,
  }) {
    final builtHeaders = <String, String>{
      ...defaultHeaders,
      ..._normalizeHeaderValues(_encodeObject(headers)),
    };

    if (body case final body? when body.value != null) {
      builtHeaders.putIfAbsent('content-type', () => body.contentType);
    }

    return builtHeaders;
  }

  String? _encodeRequestBody<TBody>({
    required DartEdgeClientRequestBody<TBody>? body,
  }) {
    if (body == null || body.value == null) {
      return null;
    }

    final encodedBody = body.encode();
    final contentType = body.contentType.toLowerCase();

    if (_isJsonContentType(contentType)) {
      return jsonEncode(encodedBody);
    }

    if (_isTextContentType(contentType)) {
      return encodedBody?.toString() ?? '';
    }

    return encodedBody?.toString();
  }

  T _decodeResponse<T>(
    DartEdgeClientResponse response, {
    required DartEdgeClientResponseSpec<T> success,
  }) {
    if (_isJsonContentType(success.contentType)) {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (success.decoder case final decoder?) {
        return decoder(decoded);
      }
      return decoded as T;
    }

    if (_isTextContentType(success.contentType)) {
      return response.body as T;
    }

    if (success.decoder case final decoder?) {
      return decoder(response.body);
    }

    return response.body as T;
  }

  String _resolvePathTemplate<TParams>(
    String template, {
    required DartEdgeClientRequestValue<TParams>? params,
  }) {
    final encodedParams = _normalizeScalarValues(_encodeObject(params));

    return template.replaceAllMapped(_pathParameterPattern, (match) {
      final name = match.group(1)!;
      final value = encodedParams[name];
      if (value == null) {
        throw StateError(
          'Missing path parameter "$name" for template "$template".',
        );
      }
      return Uri.encodeComponent(value);
    });
  }

  Map<String, Object?> _encodeObject<T>(DartEdgeClientRequestValue<T>? value) {
    if (value == null || value.value == null) {
      return const <String, Object?>{};
    }

    final encoded = value.encode();
    if (encoded == null) {
      return const <String, Object?>{};
    }
    if (encoded is Map<String, Object?>) {
      return encoded;
    }
    if (encoded is Map) {
      return {for (final entry in encoded.entries) '${entry.key}': entry.value};
    }

    throw StateError(
      'Expected an encoded object map for schema "${value.schemaId}", '
      'but got ${encoded.runtimeType}.',
    );
  }

  Map<String, String> _normalizeHeaderValues(Map<String, Object?> values) {
    return {
      for (final entry in values.entries)
        if (entry.value case final value?) entry.key: _stringifyScalar(value),
    };
  }

  Map<String, String> _normalizeScalarValues(Map<String, Object?> values) {
    return {
      for (final entry in values.entries)
        if (entry.value case final value?) entry.key: _stringifyScalar(value),
    };
  }

  Map<String, List<String>> _normalizeQueryValues(Map<String, Object?> values) {
    final query = <String, List<String>>{};
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }

      query[entry.key] = switch (value) {
        String _ => [value],
        Iterable<Object?> _ => [
          for (final item in value)
            if (item != null) _stringifyScalar(item),
        ],
        _ => [_stringifyScalar(value)],
      };
    }
    return query;
  }

  String _stringifyScalar(Object value) => switch (value) {
    String _ => value,
    bool _ => value ? 'true' : 'false',
    _ => value.toString(),
  };

  String _encodeQueryString(Map<String, List<String>> values) {
    return values.entries
        .expand(
          (entry) => entry.value.map(
            (value) =>
                '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
          ),
        )
        .join('&');
  }

  String _joinPaths(String left, String right) {
    final base = left.endsWith('/') ? left.substring(0, left.length - 1) : left;
    final suffix = right.startsWith('/') ? right : '/$right';
    if (base.isEmpty || base == '/') {
      return suffix;
    }
    return '$base$suffix';
  }

  Uri _webSocketUri(Uri uri) {
    return uri.replace(
      scheme: switch (uri.scheme) {
        'https' => 'wss',
        'http' => 'ws',
        final scheme when scheme == 'ws' || scheme == 'wss' => scheme,
        final scheme => throw ArgumentError.value(
          scheme,
          'baseUri.scheme',
          'Expected http, https, ws, or wss.',
        ),
      },
    );
  }

  bool _isJsonContentType(String value) {
    return value.toLowerCase().startsWith('application/json');
  }

  bool _isTextContentType(String value) {
    return value.toLowerCase().startsWith('text/plain');
  }
}

final _pathParameterPattern = RegExp(r'<([^>]+)>');

/// Fully described generated-client invocation.
final class DartEdgeClientInvocation<
  TResponse,
  TParams,
  TQuery,
  THeaders,
  TBody
> {
  const DartEdgeClientInvocation({
    required this.method,
    required this.pathTemplate,
    required this.success,
    this.params,
    this.query,
    this.headers,
    this.body,
  });

  /// HTTP method to send.
  final HttpMethod method;

  /// Route path template using Dart Edge parameter syntax.
  final String pathTemplate;

  /// Expected success response metadata.
  final DartEdgeClientResponseSpec<TResponse> success;

  /// Optional path-parameter payload.
  final DartEdgeClientRequestValue<TParams>? params;

  /// Optional query payload.
  final DartEdgeClientRequestValue<TQuery>? query;

  /// Optional header payload.
  final DartEdgeClientRequestValue<THeaders>? headers;

  /// Optional request body payload.
  final DartEdgeClientRequestBody<TBody>? body;
}

/// Fully described generated-client WebSocket invocation.
final class DartEdgeClientWebSocketInvocation<TParams, TQuery, THeaders> {
  const DartEdgeClientWebSocketInvocation({
    required this.pathTemplate,
    this.params,
    this.query,
    this.headers,
    this.protocols = const <String>[],
  });

  /// Route path template using Dart Edge parameter syntax.
  final String pathTemplate;

  /// Optional path-parameter payload.
  final DartEdgeClientRequestValue<TParams>? params;

  /// Optional query payload.
  final DartEdgeClientRequestValue<TQuery>? query;

  /// Optional header payload.
  final DartEdgeClientRequestValue<THeaders>? headers;

  /// Optional WebSocket subprotocols.
  final List<String> protocols;
}

/// Schema-backed generated-client request value.
final class DartEdgeClientRequestValue<T> {
  const DartEdgeClientRequestValue({
    this.schemaId,
    required this.value,
    this.encoder,
  });

  /// Schema id used to encode [value], when one exists.
  final String? schemaId;

  /// Request value supplied by the generated client method.
  final T value;

  /// Encodes [value] into a transport value.
  final Object? Function(T value)? encoder;

  Object? encode() {
    final encoder = this.encoder;
    if (encoder == null) {
      return value;
    }
    return encoder(value);
  }
}

/// Schema-backed generated-client request body.
final class DartEdgeClientRequestBody<T> {
  const DartEdgeClientRequestBody({
    required this.contentType,
    this.schemaId,
    required this.value,
    this.encoder,
  });

  /// Request body content type.
  final String contentType;

  /// Schema id used to encode [value], when one exists.
  final String? schemaId;

  /// Request body value supplied by the generated client method.
  final T value;

  /// Encodes [value] into a transport body.
  final Object? Function(T value)? encoder;

  Object? encode() {
    final encoder = this.encoder;
    if (encoder == null) {
      return value;
    }
    return encoder(value);
  }
}

/// Expected generated-client response metadata.
final class DartEdgeClientResponseSpec<T> {
  const DartEdgeClientResponseSpec({
    required this.status,
    required this.contentType,
    this.schemaId,
    this.decoder,
  });

  /// Expected HTTP status code.
  final int status;

  /// Expected response content type.
  final String contentType;

  /// Schema id used to decode the response body, when one exists.
  final String? schemaId;

  /// Decodes the response body into [T].
  final T Function(Object? value)? decoder;
}
