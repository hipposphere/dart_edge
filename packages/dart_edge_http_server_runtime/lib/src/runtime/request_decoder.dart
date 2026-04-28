import 'dart:convert';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'dart_edge_codec.dart';
import 'json_schema_route_id.dart';
import 'native_request.dart';
import 'transport_request.dart';

Future<RequestInput> decodeRequestInput(
  TransportRequest request, {
  required DartEdgeCodecRegistry codecs,
  NativeRequest? nativeRequest,
  required String? paramsSchemaId,
  required String? querySchemaId,
  required String? headersSchemaId,
  required RequestBody? body,
}) async {
  final paramsValue = _decodeStringMap(
    request.pathParams,
    schemaId: paramsSchemaId,
    codecs: codecs,
  );
  final queryValue = _decodeStringMap(
    request.query,
    schemaId: querySchemaId,
    codecs: codecs,
  );
  final headerValue = _decodeStringMap(
    request.headers,
    schemaId: headersSchemaId,
    codecs: codecs,
  );
  final bodyValue = _decodeBody(request, body, codecs: codecs);

  return RequestInput(
    params: paramsValue,
    query: queryValue,
    headers: headerValue,
    body: bodyValue,
    paramsMap: request.pathParams,
    queryMap: request.query,
    headersMap: request.headers,
    multipartLoader: nativeRequest?.multipart,
    nativeBody: nativeRequest?.body,
  );
}

Object? _decodeStringMap(
  Map<String, String> values, {
  required String? schemaId,
  required DartEdgeCodecRegistry codecs,
}) {
  if (values.isEmpty) {
    return null;
  }

  return codecs.decodeValueOrRaw(
    schemaId,
    Map<String, String>.unmodifiable(values),
  );
}

Object? _decodeBody(
  TransportRequest request,
  RequestBody? body, {
  required DartEdgeCodecRegistry codecs,
}) {
  if (body == null) {
    return null;
  }

  if (request.bodyKind == TransportRequestBodyKind.multipart) {
    return null;
  }

  final payload = request.bodyBytes;
  if (payload == null || payload.isEmpty) {
    return null;
  }

  final decoded = switch (request.bodyKind) {
    TransportRequestBodyKind.json => jsonDecode(utf8.decode(payload)),
    _ when body.contentType.startsWith('application/json') => jsonDecode(
      utf8.decode(payload),
    ),
    _ => utf8.decode(payload),
  };

  if (body.decoder case final decoder?) {
    return decoder(decoded);
  }

  return codecs.decodeValueOrRaw(jsonSchemaRouteId(body.schema), decoded);
}
