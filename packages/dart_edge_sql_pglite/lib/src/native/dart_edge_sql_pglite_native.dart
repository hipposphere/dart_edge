import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart' as gen;

abstract final class DartEdgeSqlPgliteNative {
  static int get abiVersion => gen.dart_edge_sql_pglite_native_abi_version();

  static int openTemporary() {
    final handle = gen.dart_edge_sql_pglite_open_temporary();
    if (handle <= 0) {
      throw StateError(_takeLastError());
    }
    return handle;
  }

  static int openPersistent(String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      final handle = gen.dart_edge_sql_pglite_open_persistent(
        pathPtr.cast<Char>(),
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(pathPtr);
    }
  }

  static String connectionString(int handle) {
    final valuePtr = gen.dart_edge_sql_pglite_connection_string(handle);
    if (valuePtr == nullptr) {
      throw StateError(_takeLastError());
    }

    try {
      return valuePtr.cast<Utf8>().toDartString();
    } finally {
      gen.dart_edge_sql_pglite_free_string(valuePtr);
    }
  }

  static void close(int handle) {
    final closed = gen.dart_edge_sql_pglite_close(handle);
    if (!closed) {
      throw StateError(_takeLastError());
    }
  }
}

String _takeLastError() {
  final errorPtr = gen.dart_edge_sql_pglite_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_sql_pglite native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    return message.isEmpty
        ? 'dart_edge_sql_pglite native call failed.'
        : message;
  } finally {
    gen.dart_edge_sql_pglite_free_string(errorPtr);
  }
}
