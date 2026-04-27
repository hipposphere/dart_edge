import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql/src/native/generated_bindings.dart' as sql_gen;
import 'package:ffi/ffi.dart';

import '../dart_edge_auth_config.dart';
import '../dart_edge_auth_database.dart';
import 'generated_bindings.dart' as gen;

typedef AuthNativeRouteDescriptor = NativeHttpRouteDescriptor;

final class NativeAuthResponseData {
  const NativeAuthResponseData({
    required this.status,
    required this.contentType,
    required this.headers,
    required this.body,
  });

  final int status;
  final String contentType;
  final List<HttpHeader> headers;
  final String body;
}

final class NativeAuthInstance {
  NativeAuthInstance._(this.handle, this._disposeCallbacks);

  final int handle;
  final void Function()? _disposeCallbacks;

  void dispose() {
    gen.dart_edge_auth_dispose(handle);
    _disposeCallbacks?.call();
  }
}

final Pointer<NativeFunction<Pointer<Char> Function(Int64, Pointer<Char>)>>
_sharedExecutePoolPointer = Native.addressOf(
  sql_gen.dart_edge_sql_execute_pool,
);
final Pointer<NativeFunction<Pointer<Char> Function()>>
_sharedTakeLastErrorPointer = Native.addressOf(
  sql_gen.dart_edge_sql_take_last_error,
);
final Pointer<NativeFunction<Void Function(Pointer<Char>)>>
_sharedFreeStringPointer = Native.addressOf(sql_gen.dart_edge_sql_free_string);
final Pointer<
  NativeFunction<
    Pointer<gen.NativeHttpResponse> Function(
      Int64,
      Pointer<gen.NativeHttpRequest>,
    )
  >
>
_authHandleRequestPointer = Native.addressOf(gen.dart_edge_auth_handle_request);
final Pointer<NativeFunction<Void Function(Pointer<gen.NativeHttpResponse>)>>
_authFreeResponsePointer = Native.addressOf(gen.dart_edge_auth_free_response);

abstract final class DartEdgeAuthNative {
  static int get abiVersion => gen.dart_edge_auth_native_abi_version();

  static int get handleRequestAddress => _authHandleRequestPointer.address;

  static int get freeResponseAddress => _authFreeResponsePointer.address;

  static NativeAuthInstance create(DartEdgeAuthConfig config) {
    return switch (config.database) {
      final SharedDartEdgeAuthDatabase database => _createWithSharedDatabase(
        config,
        database,
      ),
      _ => _createDedicated(config),
    };
  }

  static NativeAuthInstance _createDedicated(DartEdgeAuthConfig config) {
    final configJsonPtr = jsonEncode(config.toJson()).toNativeUtf8();

    try {
      final handle = gen.dart_edge_auth_create(configJsonPtr.cast<Char>());
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return NativeAuthInstance._(handle, null);
    } finally {
      calloc.free(configJsonPtr);
    }
  }

  static NativeAuthInstance _createWithSharedDatabase(
    DartEdgeAuthConfig config,
    SharedDartEdgeAuthDatabase database,
  ) {
    final databaseHandle = _sharedDatabaseHandle(database.database);
    final configJsonPtr = jsonEncode(config.toJson()).toNativeUtf8();

    try {
      final handle = gen.dart_edge_auth_create_with_shared_database(
        configJsonPtr.cast<Char>(),
        _encodeSqlDialect(database.dialect),
        databaseHandle,
        _sharedExecutePoolPointer,
        _sharedTakeLastErrorPointer,
        _sharedFreeStringPointer,
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return NativeAuthInstance._(handle, null);
    } finally {
      calloc.free(configJsonPtr);
    }
  }

  static List<AuthNativeRouteDescriptor> listRoutes(int handle) {
    final routesPtr = gen.dart_edge_auth_list_routes(handle);
    if (routesPtr == nullptr) {
      throw StateError(_takeLastError());
    }

    try {
      final decoded =
          jsonDecode(routesPtr.cast<Utf8>().toDartString()) as List<Object?>;
      return NativeHttpRouteDescriptor.listFromJson(decoded);
    } finally {
      gen.dart_edge_auth_free_string(routesPtr);
    }
  }

  static NativeAuthResponseData handleRequest(
    int handle, {
    required HttpMethod method,
    required String path,
    required Map<String, String> query,
    required Map<String, String> headers,
    required Uint8List? body,
  }) {
    final pathPtr = path.toNativeUtf8();
    final queryEntries = _encodePairs(query);
    final headerEntries = _encodePairs(headers);
    final queryStorage = calloc<core_ffi.NativePair>(queryEntries.length);
    final headerStorage = calloc<core_ffi.NativePair>(headerEntries.length);
    final bodyStorage = body == null ? nullptr : calloc<Uint8>(body.length);
    final requestStorage = calloc<gen.NativeHttpRequest>();

    try {
      _writePairs(queryStorage, queryEntries);
      _writePairs(headerStorage, headerEntries);

      if (body case final body?) {
        bodyStorage.asTypedList(body.length).setAll(0, body);
      }

      requestStorage.ref
        ..method = _encodeMethod(method)
        ..path = pathPtr.cast<Char>()
        ..query_count = queryEntries.length
        ..query = queryEntries.isEmpty ? nullptr : queryStorage
        ..header_count = headerEntries.length
        ..headers = headerEntries.isEmpty ? nullptr : headerStorage
        ..body.ptr = bodyStorage
        ..body.len = body?.length ?? 0;

      final responsePtr = gen.dart_edge_auth_handle_request(
        handle,
        requestStorage,
      );
      if (responsePtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        return _decodeResponse(responsePtr);
      } finally {
        gen.dart_edge_auth_free_response(responsePtr);
      }
    } finally {
      calloc.free(pathPtr);
      calloc.free(queryStorage);
      calloc.free(headerStorage);
      calloc.free(requestStorage);
      if (bodyStorage != nullptr) {
        calloc.free(bodyStorage);
      }
      _freePairs(queryEntries);
      _freePairs(headerEntries);
    }
  }
}

int _sharedDatabaseHandle(SqlPool database) => switch (database) {
  final PostgresPool database => database.nativeHandle,
  final SqliteDatabase database => database.nativeHandle,
  _ => throw ArgumentError.value(
    database,
    'database',
    'Only native PostgresPool and SqliteDatabase instances can be shared '
        'with dart_edge_auth.',
  ),
};

NativeAuthResponseData _decodeResponse(
  Pointer<gen.NativeHttpResponse> responsePtr,
) {
  final response = responsePtr.ref;

  return NativeAuthResponseData(
    status: response.status,
    contentType: core_ffi.decodeNativeUtf8(response.content_type),
    headers: _decodePairs(response.headers, response.header_count),
    body: core_ffi.decodeNativeUtf8(response.body),
  );
}

List<({int keyLength, Pointer<Utf8> key, int valueLength, Pointer<Utf8> value})>
_encodePairs(Map<String, String> values) {
  return [
    for (final entry in values.entries)
      (
        keyLength: utf8.encode(entry.key).length,
        key: entry.key.toNativeUtf8(),
        valueLength: utf8.encode(entry.value).length,
        value: entry.value.toNativeUtf8(),
      ),
  ];
}

void _writePairs(
  Pointer<core_ffi.NativePair> storage,
  List<
    ({int keyLength, Pointer<Utf8> key, int valueLength, Pointer<Utf8> value})
  >
  values,
) {
  for (var index = 0; index < values.length; index += 1) {
    (storage + index).ref
      ..key.ptr = values[index].key.cast<Uint8>()
      ..key.len = values[index].keyLength
      ..value.ptr = values[index].value.cast<Uint8>()
      ..value.len = values[index].valueLength;
  }
}

void _freePairs(
  List<
    ({int keyLength, Pointer<Utf8> key, int valueLength, Pointer<Utf8> value})
  >
  values,
) {
  for (final value in values) {
    calloc.free(value.key);
    calloc.free(value.value);
  }
}

List<HttpHeader> _decodePairs(Pointer<core_ffi.NativePair> pairs, int count) {
  return [
    for (final pair in core_ffi.copyNativePairs(pairs, count))
      HttpHeader(pair.key, pair.value),
  ];
}

String _takeLastError() {
  final errorPtr = gen.dart_edge_auth_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_auth native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    if (message.isEmpty) {
      return 'dart_edge_auth native call failed.';
    }
    return message;
  } finally {
    gen.dart_edge_auth_free_string(errorPtr);
  }
}

int _encodeMethod(HttpMethod method) => switch (method) {
  HttpMethod.get => 0,
  HttpMethod.post => 1,
  HttpMethod.put => 2,
  HttpMethod.patch => 3,
  HttpMethod.delete => 4,
  HttpMethod.head => 5,
  HttpMethod.options => 6,
};

int _encodeSqlDialect(SqlDialect dialect) => switch (dialect) {
  SqlDialect.postgres => 0,
  SqlDialect.sqlite => 1,
};
