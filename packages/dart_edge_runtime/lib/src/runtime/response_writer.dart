import 'dart:convert';

import 'package:dart_edge_core/dart_edge_core.dart';

final class EncodedResponse {
  const EncodedResponse({
    required this.status,
    required this.contentType,
    required this.body,
    this.headers = const <HttpHeader>[],
  });

  final int status;
  final String contentType;
  final String body;
  final List<HttpHeader> headers;
}

EncodedResponse encodeResponse({
  required ResponseSpec spec,
  required Object? body,
}) {
  if (body case final RawResponse rawResponse) {
    return _encodeRawResponse(rawResponse);
  }

  if (spec.contentType.startsWith('application/json')) {
    return EncodedResponse(
      status: spec.status,
      contentType: spec.contentType,
      body: jsonEncode(_normalizeJson(body)),
    );
  }

  return EncodedResponse(
    status: spec.status,
    contentType: spec.contentType,
    body: body?.toString() ?? '',
  );
}

EncodedResponse _encodeRawResponse(RawResponse response) {
  if (response.isEncodedBody) {
    return EncodedResponse(
      status: response.status,
      contentType: response.contentType,
      body: response.body?.toString() ?? '',
      headers: response.headers,
    );
  }

  if (response.contentType.startsWith('application/json')) {
    return EncodedResponse(
      status: response.status,
      contentType: response.contentType,
      body: jsonEncode(_normalizeJson(response.body)),
      headers: response.headers,
    );
  }

  return EncodedResponse(
    status: response.status,
    contentType: response.contentType,
    body: response.body?.toString() ?? '',
    headers: response.headers,
  );
}

EncodedResponse encodeServerError() {
  return const EncodedResponse(
    status: 500,
    contentType: 'text/plain; charset=utf-8',
    body: 'Internal Server Error',
  );
}

Object? _normalizeJson(Object? value) {
  switch (value) {
    case null:
    case bool():
    case num():
    case String():
      return value;
    case List():
      return value.map(_normalizeJson).toList(growable: false);
    case Map():
      return {
        for (final entry in value.entries)
          entry.key.toString(): _normalizeJson(entry.value),
      };
    case JsonEncodable():
      return _normalizeJson(value.toJson());
    default:
      throw StateError(
        'Response body of type ${value.runtimeType} is not JSON encodable.',
      );
  }
}
