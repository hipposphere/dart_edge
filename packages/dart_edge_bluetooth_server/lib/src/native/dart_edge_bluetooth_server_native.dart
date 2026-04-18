import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../config/bluetooth_server_config.dart';
import 'generated_bindings.dart' as gen;

abstract final class DartEdgeBluetoothServerNative {
  static int get abiVersion =>
      gen.dart_edge_bluetooth_server_native_abi_version();

  static bool get isSupportedPlatform =>
      gen.dart_edge_bluetooth_server_is_supported_platform();

  static int create(BluetoothServerConfig config) {
    final configJsonPtr = jsonEncode(config.toJson()).toNativeUtf8();
    try {
      final handle = gen.dart_edge_bluetooth_server_create(
        configJsonPtr.cast<Char>(),
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(configJsonPtr);
    }
  }

  static void start(int handle) {
    final ok = gen.dart_edge_bluetooth_server_start(handle);
    if (!ok) {
      throw StateError(_takeLastError());
    }
  }

  static void stop(int handle) {
    final ok = gen.dart_edge_bluetooth_server_stop(handle);
    if (!ok) {
      throw StateError(_takeLastError());
    }
  }

  static void dispose(int handle) {
    gen.dart_edge_bluetooth_server_dispose(handle);
  }

  static Map<String, Object?> issueCommand(
    int handle,
    Map<String, Object?> command,
  ) {
    final commandJsonPtr = jsonEncode(command).toNativeUtf8();
    try {
      final resultPtr = gen.dart_edge_bluetooth_server_issue_command(
        handle,
        commandJsonPtr.cast<Char>(),
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }
      try {
        return jsonDecode(resultPtr.cast<Utf8>().toDartString())
            as Map<String, Object?>;
      } finally {
        gen.dart_edge_bluetooth_server_free_string(resultPtr);
      }
    } finally {
      calloc.free(commandJsonPtr);
    }
  }

  static Map<String, Object?>? pollEvent(int handle) {
    final resultPtr = gen.dart_edge_bluetooth_server_poll_event(handle);
    if (resultPtr == nullptr) {
      return null;
    }

    try {
      return jsonDecode(resultPtr.cast<Utf8>().toDartString())
          as Map<String, Object?>;
    } finally {
      gen.dart_edge_bluetooth_server_free_string(resultPtr);
    }
  }
}

String _takeLastError() {
  final errorPtr = gen.dart_edge_bluetooth_server_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_bluetooth_server native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    return message.isEmpty
        ? 'dart_edge_bluetooth_server native call failed.'
        : message;
  } finally {
    gen.dart_edge_bluetooth_server_free_string(errorPtr);
  }
}
