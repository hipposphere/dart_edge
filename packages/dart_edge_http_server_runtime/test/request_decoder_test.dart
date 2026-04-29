import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_http_server_runtime/src/runtime/request_decoder.dart';
import 'package:test/test.dart';

void main() {
  test(
    'decodes typed path, query, header, and body values with runtime codecs',
    () async {
      final codecs = DartEdgeCodecRegistry.empty
          .withCodec<UserPath>(
            'UserPath',
            DartEdgeCodec<UserPath>(
              encode: (value) => {'id': value.id},
              decode: (value) {
                final map = _readObject(value);
                return UserPath(id: map['id']! as String);
              },
            ),
          )
          .withCodec<UserQuery>(
            'UserQuery',
            DartEdgeCodec<UserQuery>(
              encode: (value) => {'search': value.search},
              decode: (value) {
                final map = _readObject(value);
                return UserQuery(search: map['search'] as String?);
              },
            ),
          )
          .withCodec<RequestHeaders>(
            'RequestHeaders',
            DartEdgeCodec<RequestHeaders>(
              encode: (value) => {'x-request-id': value.requestId},
              decode: (value) {
                final map = _readObject(value);
                return RequestHeaders(
                  requestId: map['x-request-id']! as String,
                );
              },
            ),
          )
          .withCodec<CreateUserInput>(
            'CreateUserInput',
            DartEdgeCodec<CreateUserInput>(
              encode: (value) => {'name': value.name},
              decode: (value) {
                final map = _readObject(value);
                return CreateUserInput(name: map['name']! as String);
              },
            ),
          );

      final input = await decodeRequestInput(
        TransportRequest(
          routeId: 'route_0',
          pathParams: const {'id': '42'},
          query: const {'search': 'Ada'},
          headers: const {'x-request-id': 'req_1'},
          bodyBytes: Uint8List.fromList(utf8.encode('{"name":"Ada"}')),
          bodyKind: TransportRequestBodyKind.json,
        ),
        codecs: codecs,
        paramsSchemaId: 'UserPath',
        querySchemaId: 'UserQuery',
        headersSchemaId: 'RequestHeaders',
        body: RequestBody.json(schema: const JsonSchema.ref('CreateUserInput')),
      );

      expect(input.params<UserPath>().id, '42');
      expect(input.query<UserQuery>().search, 'Ada');
      expect(input.headers<RequestHeaders>().requestId, 'req_1');
      expect(input.body<CreateUserInput>().name, 'Ada');
    },
  );

  test(
    'preserves raw request values when no runtime codec is registered',
    () async {
      final input = await decodeRequestInput(
        TransportRequest(
          routeId: 'route_0',
          pathParams: const {'id': '42'},
          query: const {'search': 'Ada'},
          headers: const {'x-request-id': 'req_1'},
          bodyBytes: Uint8List.fromList(utf8.encode('{"name":"Ada"}')),
          bodyKind: TransportRequestBodyKind.json,
        ),
        codecs: DartEdgeCodecRegistry.empty,
        paramsSchemaId: 'UserPath',
        querySchemaId: 'UserQuery',
        headersSchemaId: 'RequestHeaders',
        body: RequestBody.json(schema: const JsonSchema.ref('CreateUserInput')),
      );

      expect(input.params<Map<String, String>>(), {'id': '42'});
      expect(input.query<Map<String, String>>(), {'search': 'Ada'});
      expect(input.headers<Map<String, String>>(), {'x-request-id': 'req_1'});
      expect(input.body<Map<String, Object?>>(), {'name': 'Ada'});
    },
  );

  test('decodes request bodies with route-local body decoder', () async {
    final input = await decodeRequestInput(
      TransportRequest(
        routeId: 'route_0',
        pathParams: const <String, String>{},
        query: const <String, String>{},
        headers: const <String, String>{},
        bodyBytes: Uint8List.fromList(utf8.encode('{"name":"Ada"}')),
        bodyKind: TransportRequestBodyKind.json,
      ),
      codecs: DartEdgeCodecRegistry.empty,
      paramsSchemaId: null,
      querySchemaId: null,
      headersSchemaId: null,
      body: RequestBody.json(
        schema: const JsonSchema.ref('CreateUserInput'),
        decoder: (value) {
          final map = _readObject(value);
          return CreateUserInput(name: map['name']! as String);
        },
      ),
    );

    expect(input.body<CreateUserInput>().name, 'Ada');
  });

  test('does not use inline schema ids as body codec targets', () async {
    final codecs = DartEdgeCodecRegistry.empty.withCodec<CreateUserInput>(
      'CreateUserInput',
      DartEdgeCodec<CreateUserInput>(
        encode: (value) => {'name': value.name},
        decode: (value) {
          final map = _readObject(value);
          return CreateUserInput(name: map['name']! as String);
        },
      ),
    );

    final input = await decodeRequestInput(
      TransportRequest(
        routeId: 'route_0',
        pathParams: const <String, String>{},
        query: const <String, String>{},
        headers: const <String, String>{},
        bodyBytes: Uint8List.fromList(utf8.encode('{"name":"Ada"}')),
        bodyKind: TransportRequestBodyKind.json,
      ),
      codecs: codecs,
      paramsSchemaId: null,
      querySchemaId: null,
      headersSchemaId: null,
      body: RequestBody.json(
        schema: const JsonSchema.object(
          id: 'CreateUserInput',
          properties: <String, JsonSchema>{'name': JsonSchema.string()},
        ),
      ),
    );

    expect(input.body<Map<String, Object?>>(), {'name': 'Ada'});
  });
}

Map<String, Object?> _readObject(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }

  throw StateError('Expected a JSON object, got ${value.runtimeType}.');
}

final class UserPath {
  const UserPath({required this.id});

  final String id;
}

final class UserQuery {
  const UserQuery({this.search});

  final String? search;
}

final class RequestHeaders {
  const RequestHeaders({required this.requestId});

  final String requestId;
}

final class CreateUserInput {
  const CreateUserInput({required this.name});

  final String name;
}
