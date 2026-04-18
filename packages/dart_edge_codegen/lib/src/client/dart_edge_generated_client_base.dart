import 'dart:convert';

import 'package:dart_edge_runtime/dart_edge_runtime.dart';

import 'dart_edge_client_codec.dart';
import 'dart_edge_client_transport.dart';

/// Base class that generated HTTP clients extend.
abstract base class DartEdgeGeneratedClientBase {
  const DartEdgeGeneratedClientBase({
    required this.baseUri,
    required this.transport,
    this.codecs = DartEdgeClientCodecRegistry.empty,
    this.defaultHeaders = const <String, String>{},
  });

  final Uri baseUri;
  final DartEdgeClientTransport transport;
  final DartEdgeClientCodecRegistry codecs;
  final Map<String, String> defaultHeaders;

  Future<T> invoke<T>({
    required HttpMethod method,
    required String pathTemplate,
    required int successStatus,
    required String successContentType,
    String? successSchemaId,
    String? paramsSchemaId,
    Object? params,
    String? querySchemaId,
    Object? query,
    String? headersSchemaId,
    Object? headers,
    String? requestContentType,
    String? bodySchemaId,
    Object? body,
  }) async {
    final request = DartEdgeClientRequest(
      method: method,
      uri: _buildUri(
        pathTemplate,
        paramsSchemaId: paramsSchemaId,
        params: params,
        querySchemaId: querySchemaId,
        query: query,
      ),
      headers: _buildHeaders(
        headersSchemaId: headersSchemaId,
        headers: headers,
        requestContentType: requestContentType,
        body: body,
      ),
      body: _encodeRequestBody(
        requestContentType: requestContentType,
        bodySchemaId: bodySchemaId,
        body: body,
      ),
    );

    final response = await transport.send(request);
    if (response.status != successStatus) {
      throw DartEdgeClientResponseException(
        method: method,
        uri: request.uri,
        expectedStatus: successStatus,
        actualStatus: response.status,
        body: response.body,
      );
    }

    return _decodeResponse<T>(
      response,
      expectedContentType: successContentType,
      schemaId: successSchemaId,
    );
  }

  Uri _buildUri(
    String pathTemplate, {
    String? paramsSchemaId,
    Object? params,
    String? querySchemaId,
    Object? query,
  }) {
    final resolvedPath = _joinPaths(
      baseUri.path,
      _resolvePathTemplate(
        pathTemplate,
        paramsSchemaId: paramsSchemaId,
        params: params,
      ),
    );
    final queryParametersAll = _normalizeQueryValues(
      _encodeObject(paramsSchemaId: querySchemaId, value: query),
    );

    return baseUri.replace(
      path: resolvedPath,
      query: queryParametersAll.isEmpty
          ? null
          : _encodeQueryString(queryParametersAll),
    );
  }

  Map<String, String> _buildHeaders({
    String? headersSchemaId,
    Object? headers,
    String? requestContentType,
    Object? body,
  }) {
    final builtHeaders = <String, String>{
      ...defaultHeaders,
      ..._normalizeHeaderValues(
        _encodeObject(paramsSchemaId: headersSchemaId, value: headers),
      ),
    };

    if (requestContentType case final contentType? when body != null) {
      builtHeaders.putIfAbsent('content-type', () => contentType);
    }

    return builtHeaders;
  }

  String? _encodeRequestBody({
    required String? requestContentType,
    required String? bodySchemaId,
    required Object? body,
  }) {
    if (body == null) {
      return null;
    }

    final encodedBody = bodySchemaId == null
        ? body
        : codecs.encodeValue(bodySchemaId, body);
    final contentType = requestContentType?.toLowerCase() ?? '';

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
    required String expectedContentType,
    required String? schemaId,
  }) {
    if (_isJsonContentType(expectedContentType)) {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (schemaId case final schemaId?) {
        return codecs.decodeValue<T>(schemaId, decoded);
      }
      return decoded as T;
    }

    if (_isTextContentType(expectedContentType)) {
      return response.body as T;
    }

    if (schemaId case final schemaId?) {
      return codecs.decodeValue<T>(schemaId, response.body);
    }

    return response.body as T;
  }

  String _resolvePathTemplate(
    String template, {
    required String? paramsSchemaId,
    required Object? params,
  }) {
    final encodedParams = _normalizeScalarValues(
      _encodeObject(paramsSchemaId: paramsSchemaId, value: params),
    );

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

  Map<String, Object?> _encodeObject({
    required String? paramsSchemaId,
    required Object? value,
  }) {
    if (value == null) {
      return const <String, Object?>{};
    }

    final encoded = paramsSchemaId == null
        ? value
        : codecs.encodeValue(paramsSchemaId, value);
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
      'Expected an encoded object map for schema "$paramsSchemaId", '
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

  bool _isJsonContentType(String value) {
    return value.toLowerCase().startsWith('application/json');
  }

  bool _isTextContentType(String value) {
    return value.toLowerCase().startsWith('text/plain');
  }
}

final _pathParameterPattern = RegExp(r'<([^>]+)>');
