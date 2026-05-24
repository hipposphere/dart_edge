import 'dart:convert';
import 'dart:typed_data';

import '../http.dart';
import 'dart_edge_client_transport.dart';

/// Base class that typed HTTP clients extend.
abstract base class DartEdgeHttpClientBase {
  const DartEdgeHttpClientBase({
    required this.baseUri,
    required this.transport,
    this.webSocketTransport,
    this.webTransportTransport,
    this.defaultHeaders = const <String, String>{},
  });

  final Uri baseUri;
  final DartEdgeClientTransport transport;
  final DartEdgeClientWebSocketTransport? webSocketTransport;
  final DartEdgeClientWebTransportTransport? webTransportTransport;
  final Map<String, String> defaultHeaders;

  Future<DartEdgeClientResponseObject<TResponse>>
  invoke<TResponse, TParams, TQuery, THeaders, TBody>(
    DartEdgeClientInvocation<TResponse, TParams, TQuery, THeaders, TBody>
    invocation,
  ) async {
    final encodedBody = await _encodeRequestBody(body: invocation.body);
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
        encodedBody: encodedBody,
      ),
      body: encodedBody?.body,
      bodyBytes: encodedBody?.bodyBytes,
    );

    final response = await transport.send(request);
    if (response.status == invocation.success.status) {
      return DartEdgeClientResponseObject<TResponse>(
        status: response.status,
        contentType: response.contentType,
        headers: response.headers,
        rawBody: response.body,
        rawBodyBytes: response.bodyBytes,
        data: _decodeResponse<TResponse>(response, success: invocation.success),
      );
    }

    final documentedError = invocation.errors
        .where((error) => error.status == response.status)
        .firstOrNull;
    return DartEdgeClientResponseObject<TResponse>(
      status: response.status,
      contentType: response.contentType,
      headers: response.headers,
      rawBody: response.body,
      rawBodyBytes: response.bodyBytes,
      error: DartEdgeClientError(
        status: response.status,
        code: documentedError?.code,
        kind: documentedError == null
            ? DartEdgeClientErrorKind.unknownStatus
            : DartEdgeClientErrorKind.documented,
        contentType: response.contentType,
        headers: response.headers,
        rawBody: response.body,
        rawBodyBytes: response.bodyBytes,
        body: _decodeErrorBody(response),
      ),
    );
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
          encodedBody: null,
        ),
        protocols: invocation.protocols,
      ),
    );
  }

  Future<DartEdgeClientWebTransportSession>
  connectWebTransport<TParams, TQuery, THeaders>(
    DartEdgeClientWebTransportInvocation<TParams, TQuery, THeaders> invocation,
  ) {
    final transport = webTransportTransport;
    if (transport == null) {
      throw StateError(
        'No DartEdgeClientWebTransportTransport configured for this client.',
      );
    }

    final httpUri = _buildUri(
      invocation.pathTemplate,
      params: invocation.params,
      query: invocation.query,
    );
    return transport.connect(
      DartEdgeClientWebTransportRequest(
        uri: _httpsUri(httpUri),
        headers: _buildHeaders<THeaders, Never>(
          headers: invocation.headers,
          body: null,
          encodedBody: null,
        ),
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
    required _EncodedClientRequestBody? encodedBody,
  }) {
    final builtHeaders = <String, String>{
      ...defaultHeaders,
      ..._normalizeHeaderValues(_encodeObject(headers)),
    };

    if (body case final body? when body.value != null) {
      builtHeaders.putIfAbsent(
        'content-type',
        () => encodedBody?.contentType ?? body.contentType,
      );
    }

    return builtHeaders;
  }

  Future<_EncodedClientRequestBody?> _encodeRequestBody<TBody>({
    required DartEdgeClientRequestBody<TBody>? body,
  }) async {
    if (body == null || body.value == null) {
      return null;
    }

    final encodedBody = body.encode();
    final contentType = body.contentType.toLowerCase();

    if (_isJsonContentType(contentType)) {
      return _EncodedClientRequestBody(
        contentType: body.contentType,
        body: jsonEncode(encodedBody),
      );
    }

    if (_isTextContentType(contentType)) {
      return _EncodedClientRequestBody(
        contentType: body.contentType,
        body: encodedBody?.toString() ?? '',
      );
    }

    if (_isMultipartFormDataContentType(contentType)) {
      final form = encodedBody is MultipartFormData
          ? encodedBody
          : throw StateError(
              'Expected MultipartFormData for multipart request body.',
            );
      final encoded = await _encodeMultipartFormData(form);
      return _EncodedClientRequestBody(
        contentType: 'multipart/form-data; boundary=${encoded.boundary}',
        bodyBytes: encoded.bodyBytes,
      );
    }

    return _EncodedClientRequestBody(
      contentType: body.contentType,
      body: encodedBody?.toString(),
    );
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

    if (_isBinaryContentType(success.contentType)) {
      return response.bodyBytes as T;
    }

    if (success.decoder case final decoder?) {
      return decoder(response.body);
    }

    return response.body as T;
  }

  Object? _decodeErrorBody(DartEdgeClientResponse response) {
    if (response.body.isEmpty) {
      return null;
    }
    if (_isJsonContentType(response.contentType)) {
      return jsonDecode(response.body);
    }
    if (_isTextContentType(response.contentType)) {
      return response.body;
    }
    if (_isBinaryContentType(response.contentType)) {
      return response.bodyBytes;
    }
    return response.body;
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

  Uri _httpsUri(Uri uri) {
    return uri.replace(
      scheme: switch (uri.scheme) {
        'https' => 'https',
        'http' => 'https',
        final scheme => throw ArgumentError.value(
          scheme,
          'baseUri.scheme',
          'Expected http or https.',
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

  bool _isMultipartFormDataContentType(String value) {
    return value.split(';').first.trim().toLowerCase() == 'multipart/form-data';
  }

  bool _isBinaryContentType(String value) {
    final mimeType = value.split(';').first.trim().toLowerCase();
    return mimeType == 'application/octet-stream' ||
        mimeType.startsWith('audio/') ||
        mimeType.startsWith('image/') ||
        mimeType.startsWith('video/');
  }
}

final _pathParameterPattern = RegExp(r'<([^>]+)>');

final class _EncodedClientRequestBody {
  const _EncodedClientRequestBody({
    required this.contentType,
    this.body,
    this.bodyBytes,
  });

  final String contentType;
  final String? body;
  final List<int>? bodyBytes;
}

typedef _EncodedMultipartFormData = ({String boundary, Uint8List bodyBytes});

Future<_EncodedMultipartFormData> _encodeMultipartFormData(
  MultipartFormData form,
) async {
  final boundary =
      'dart-edge-boundary-${DateTime.now().microsecondsSinceEpoch}';
  final bytes = BytesBuilder(copy: false);
  final newline = utf8.encode('\r\n');

  void writeAscii(String value) {
    bytes.add(ascii.encode(value));
  }

  for (final field in form.fields) {
    writeAscii('--$boundary\r\n');
    writeAscii(
      'Content-Disposition: form-data; '
      'name="${_escapeMultipartHeaderValue(field.name)}"\r\n\r\n',
    );
    bytes.add(utf8.encode(field.value));
    bytes.add(newline);
  }

  for (final file in form.files) {
    writeAscii('--$boundary\r\n');
    writeAscii(
      'Content-Disposition: form-data; '
      'name="${_escapeMultipartHeaderValue(file.fieldName)}"',
    );
    if (file.filename case final filename?) {
      writeAscii('; filename="${_escapeMultipartHeaderValue(filename)}"');
    }
    writeAscii('\r\n');
    if (file.contentType case final contentType?) {
      writeAscii('Content-Type: $contentType\r\n');
    }
    writeAscii('\r\n');
    bytes.add(await file.bytes);
    bytes.add(newline);
  }

  writeAscii('--$boundary--\r\n');
  return (boundary: boundary, bodyBytes: bytes.takeBytes());
}

String _escapeMultipartHeaderValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

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
    this.errors = const <DartEdgeClientErrorSpec>[],
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

  /// Documented error response metadata.
  final List<DartEdgeClientErrorSpec> errors;

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

/// Fully described generated-client WebTransport invocation.
final class DartEdgeClientWebTransportInvocation<TParams, TQuery, THeaders> {
  const DartEdgeClientWebTransportInvocation({
    required this.pathTemplate,
    this.params,
    this.query,
    this.headers,
  });

  /// Route path template using Dart Edge parameter syntax.
  final String pathTemplate;

  /// Optional path-parameter payload.
  final DartEdgeClientRequestValue<TParams>? params;

  /// Optional query payload.
  final DartEdgeClientRequestValue<TQuery>? query;

  /// Optional header payload.
  final DartEdgeClientRequestValue<THeaders>? headers;
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

/// Typed response object returned by generated HTTP clients.
final class DartEdgeClientResponseObject<T> {
  const DartEdgeClientResponseObject({
    required this.status,
    required this.contentType,
    this.headers = const <String, String>{},
    required this.rawBody,
    this._rawBodyBytes,
    this.data,
    this.error,
  });

  /// Actual HTTP response status.
  final int status;

  /// Actual HTTP response content type.
  final String contentType;

  /// Actual HTTP response headers.
  final Map<String, String> headers;

  /// Raw transport response body.
  final String rawBody;
  final Uint8List? _rawBodyBytes;

  /// Raw transport response body bytes.
  Uint8List get rawBodyBytes {
    final bytes = _rawBodyBytes;
    if (bytes != null) {
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(utf8.encode(rawBody));
  }

  /// Decoded success payload when [isSuccess] is true.
  final T? data;

  /// Decoded generic error metadata when [isSuccess] is false.
  final DartEdgeClientError? error;

  /// Whether this response matched the generated success status.
  bool get isSuccess => error == null;

  /// Returns [data] or throws when the response is an error or has no data.
  T get requireData {
    if (error case final error?) {
      throw StateError(
        'Expected a successful Dart Edge client response, got '
        '${error.status} ${error.kind.name}.',
      );
    }
    if (data case final data?) {
      return data;
    }
    throw StateError('Expected Dart Edge client response data.');
  }
}

/// Generic non-success response metadata returned by generated HTTP clients.
final class DartEdgeClientError {
  const DartEdgeClientError({
    required this.status,
    this.code,
    required this.kind,
    required this.contentType,
    this.headers = const <String, String>{},
    required this.rawBody,
    this._rawBodyBytes,
    this.body,
  });

  /// Actual HTTP response status.
  final int status;

  /// Documented stable error code, when this status matches route metadata.
  final String? code;

  /// Whether this error matched route metadata.
  final DartEdgeClientErrorKind kind;

  /// Actual HTTP response content type.
  final String contentType;

  /// Actual HTTP response headers.
  final Map<String, String> headers;

  /// Raw transport response body.
  final String rawBody;
  final Uint8List? _rawBodyBytes;

  /// Raw transport response body bytes.
  Uint8List get rawBodyBytes {
    final bytes = _rawBodyBytes;
    if (bytes != null) {
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(utf8.encode(rawBody));
  }

  /// Generic decoded error body.
  final Object? body;
}

/// Error classification for generated HTTP client responses.
enum DartEdgeClientErrorKind { documented, unknownStatus }

/// Documented error response metadata used by generated client invocations.
final class DartEdgeClientErrorSpec {
  const DartEdgeClientErrorSpec({required this.status, this.code});

  /// Documented HTTP error status.
  final int status;

  /// Optional stable application error code.
  final String? code;
}
