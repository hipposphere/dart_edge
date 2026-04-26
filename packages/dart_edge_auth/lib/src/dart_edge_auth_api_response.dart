part of 'dart_edge_auth.dart';

/// One direct Better Auth backend response.
final class DartEdgeAuthApiResponse {
  DartEdgeAuthApiResponse({
    required this.status,
    required this.contentType,
    required this.headers,
    required this.body,
  });

  final int status;
  final String contentType;
  final List<HttpHeader> headers;
  final String body;

  late final Object? jsonBody = _decodeJsonBody();

  bool get isSuccess => status >= 200 && status < 300;

  DartEdgeAuthApiResponse requireSuccess() {
    if (isSuccess) {
      return this;
    }
    throw DartEdgeAuthApiException(this);
  }

  Map<String, Object?> get jsonObject => switch (jsonBody) {
    final Map<String, Object?> body => body,
    null => throw StateError('Auth response body is empty.'),
    _ => throw StateError('Auth response body is not a JSON object.'),
  };

  List<Object?> get jsonList => switch (jsonBody) {
    final List<Object?> body => body,
    null => throw StateError('Auth response body is empty.'),
    _ => throw StateError('Auth response body is not a JSON array.'),
  };

  String? header(String name) {
    for (final entry in headers) {
      if (entry.name.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  Object? _decodeJsonBody() {
    if (body.isEmpty) {
      return null;
    }
    if (!_looksLikeJson(contentType: contentType, body: body)) {
      return null;
    }
    return jsonDecode(body);
  }

  @override
  String toString() {
    return 'DartEdgeAuthApiResponse(status: $status, '
        'contentType: $contentType, headers: ${headers.length})';
  }
}

/// Thrown when a direct Better Auth backend call returns a non-success status.
final class DartEdgeAuthApiException implements Exception {
  const DartEdgeAuthApiException(this.response);

  final DartEdgeAuthApiResponse response;

  int get status => response.status;

  String get message {
    final jsonBody = response.jsonBody;
    if (jsonBody case {'message': final String message}) {
      return message;
    }
    if (response.body.isNotEmpty) {
      return response.body;
    }
    return 'Better Auth call failed with status $status.';
  }

  @override
  String toString() {
    return 'DartEdgeAuthApiException(status: $status, message: $message)';
  }
}

_AsyncAuthResponse _performNativeAuthRequest(_AsyncAuthRequest request) {
  final response = DartEdgeAuthNative.handleRequest(
    request.handle,
    method: _httpMethodFromName(request.method),
    path: request.path,
    query: request.query,
    headers: request.headers,
    body: request.body,
  );

  return (
    status: response.status,
    contentType: response.contentType,
    headers: [
      for (final header in response.headers)
        (name: header.name, value: header.value),
    ],
    body: response.body,
  );
}

DartEdgeAuthApiResponse _responseFromAsync(_AsyncAuthResponse response) {
  return DartEdgeAuthApiResponse(
    status: response.status,
    contentType: response.contentType,
    headers: [
      for (final header in response.headers)
        HttpHeader(header.name, header.value),
    ],
    body: response.body,
  );
}

HttpMethod _httpMethodFromName(String method) => switch (method) {
  'get' => HttpMethod.get,
  'post' => HttpMethod.post,
  'put' => HttpMethod.put,
  'patch' => HttpMethod.patch,
  'delete' => HttpMethod.delete,
  'head' => HttpMethod.head,
  'options' => HttpMethod.options,
  _ => throw StateError('Unsupported HTTP method name "$method".'),
};

bool _containsHeader(Map<String, String> headers, String name) {
  return headers.keys.any((key) => key.toLowerCase() == name.toLowerCase());
}

String? _defaultOrigin(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  return uri.origin;
}

String _qualifyPath(String basePath, String path) {
  final normalizedPath = switch (path) {
    '' => '/',
    final value when value.startsWith('/') => value,
    final value => '/$value',
  };

  if (basePath == '/' ||
      normalizedPath == basePath ||
      normalizedPath.startsWith('$basePath/')) {
    return normalizedPath;
  }

  return '$basePath$normalizedPath';
}

bool _looksLikeJson({required String contentType, required String body}) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return true;
  }
  return contentType.toLowerCase().contains('json');
}
