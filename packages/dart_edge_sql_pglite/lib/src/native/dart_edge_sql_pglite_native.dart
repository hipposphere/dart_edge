import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart' as gen;

abstract final class DartEdgeSqlPgliteNative {
  static int get abiVersion => gen.dart_edge_sql_pglite_native_abi_version();

  static int openTemporary({Iterable<String> extensions = const []}) {
    final extensionsPtr = _extensionsToNativeUtf8(extensions);
    try {
      final handle = gen.dart_edge_sql_pglite_open_temporary_with_extensions(
        extensionsPtr.cast<Char>(),
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(extensionsPtr);
    }
  }

  static int openPersistent(
    String path, {
    Iterable<String> extensions = const [],
  }) {
    final pathPtr = path.toNativeUtf8();
    final extensionsPtr = _extensionsToNativeUtf8(extensions);
    try {
      final handle = gen.dart_edge_sql_pglite_open_persistent_with_extensions(
        pathPtr.cast<Char>(),
        extensionsPtr.cast<Char>(),
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(pathPtr);
      calloc.free(extensionsPtr);
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

  static void closeAll() {
    final closed = gen.dart_edge_sql_pglite_close_all();
    if (!closed) {
      throw StateError(_takeLastError());
    }
  }
}

Pointer<Utf8> _extensionsToNativeUtf8(Iterable<String> extensions) {
  final names = extensions.toList(growable: false);
  for (final name in names) {
    if (name.isEmpty ||
        name.contains('\n') ||
        name.contains('\r') ||
        name.contains('\x00')) {
      throw ArgumentError.value(
        name,
        'extensions',
        'PGlite extension names must be non-empty SQL names.',
      );
    }
  }
  return names.join('\n').toNativeUtf8();
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
