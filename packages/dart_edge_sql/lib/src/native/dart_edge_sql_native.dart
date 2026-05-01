import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../core/sql_result.dart';
import '../core/sql_row.dart';
import '../core/sql_statement.dart';
import 'generated_bindings.dart' as gen;

abstract final class DartEdgeSqlNative {
  static int get abiVersion => gen.dart_edge_sql_native_abi_version();

  static int openPostgresPool(
    String connectionString, {
    required int maxSessions,
  }) {
    final connectionStringPtr = connectionString.toNativeUtf8();
    try {
      final handle = gen.dart_edge_sql_open_postgres_pool_with_max_sessions(
        connectionStringPtr.cast<Char>(),
        maxSessions,
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(connectionStringPtr);
    }
  }

  static int openSqlitePool(String path, {required int maxSessions}) {
    final pathPtr = path.toNativeUtf8();
    try {
      final handle = gen.dart_edge_sql_open_sqlite_pool(
        pathPtr.cast<Char>(),
        maxSessions,
      );
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(pathPtr);
    }
  }

  static int openSqliteInMemoryPool({required int maxSessions}) {
    final handle = gen.dart_edge_sql_open_sqlite_in_memory_pool(maxSessions);
    if (handle <= 0) {
      throw StateError(_takeLastError());
    }
    return handle;
  }

  static void closePool(int handle) {
    gen.dart_edge_sql_close_pool(handle);
  }

  static SqlResult executePool(int handle, SqlStatement statement) {
    final statementPtr = _encodeStatement(statement);
    try {
      return _execute(
        () => gen.dart_edge_sql_execute_pool(handle, statementPtr),
      );
    } finally {
      calloc.free(statementPtr.cast<Utf8>());
    }
  }

  static int beginTransaction(int handle) {
    final transactionHandle = gen.dart_edge_sql_begin_transaction(handle);
    if (transactionHandle <= 0) {
      throw StateError(_takeLastError());
    }
    return transactionHandle;
  }

  static SqlResult executeTransaction(int handle, SqlStatement statement) {
    final statementPtr = _encodeStatement(statement);
    try {
      return _execute(
        () => gen.dart_edge_sql_execute_transaction(handle, statementPtr),
      );
    } finally {
      calloc.free(statementPtr.cast<Utf8>());
    }
  }

  static void commitTransaction(int handle) {
    final committed = gen.dart_edge_sql_commit_transaction(handle);
    if (!committed) {
      throw StateError(_takeLastError());
    }
  }

  static void rollbackTransaction(int handle) {
    gen.dart_edge_sql_rollback_transaction(handle);
  }
}

SqlResult _execute(Pointer<Char> Function() invoke) {
  final resultPtr = invoke();
  if (resultPtr == nullptr) {
    throw StateError(_takeLastError());
  }

  try {
    final payload =
        jsonDecode(resultPtr.cast<Utf8>().toDartString())
            as Map<String, Object?>;
    return SqlResult(
      affectedRows: payload['affectedRows'] as int? ?? 0,
      rows: [
        for (final row in (payload['rows'] as List<Object?>? ?? const []))
          _decodeRow(row as Map<String, Object?>),
      ],
    );
  } finally {
    gen.dart_edge_sql_free_string(resultPtr);
  }
}

SqlRow _decodeRow(Map<String, Object?> row) {
  final values = row['values'] as List<Object?>? ?? const <Object?>[];
  return SqlRow({
    for (final value in values)
      (value as Map<String, Object?>)['name'] as String: _decodeValue(
        value['value'] as Map<String, Object?>,
      ),
  });
}

Object? _decodeValue(Map<String, Object?> payload) {
  return switch (payload['kind']) {
    'null' => null,
    'integer' => payload['value'] as int,
    'double' => (payload['value'] as num).toDouble(),
    'boolean' => payload['value'] as bool,
    'string' => payload['value'] as String,
    'bytes' => Uint8List.fromList(base64Decode(payload['value'] as String)),
    'dateTime' => DateTime.parse(payload['value'] as String),
    'json' => payload['value'],
    final Object? value => throw StateError(
      'Unsupported SQL value kind: $value',
    ),
  };
}

Pointer<Char> _encodeStatement(SqlStatement statement) {
  final payload = jsonEncode({
    'sql': statement.sql,
    'parameters': [
      for (final value in statement.positionalParameters) _encodeValue(value),
    ],
  });
  return payload.toNativeUtf8().cast<Char>();
}

Map<String, Object?> _encodeValue(Object? value) => switch (value) {
  null => {'kind': 'null'},
  final int value => {'kind': 'integer', 'value': value},
  final double value => {'kind': 'double', 'value': value},
  final bool value => {'kind': 'boolean', 'value': value},
  final String value => {'kind': 'string', 'value': value},
  final Uint8List value => {'kind': 'bytes', 'value': base64Encode(value)},
  final List<int> value => {'kind': 'bytes', 'value': base64Encode(value)},
  final DateTime value => {
    'kind': 'dateTime',
    'value': value.toUtc().toIso8601String(),
  },
  final Map<String, Object?> value => {'kind': 'json', 'value': value},
  final List<Object?> value => {'kind': 'json', 'value': value},
  final Object value => throw ArgumentError.value(
    value,
    'value',
    'Unsupported SQL parameter value.',
  ),
};

String _takeLastError() {
  final errorPtr = gen.dart_edge_sql_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_sql native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    return message.isEmpty ? 'dart_edge_sql native call failed.' : message;
  } finally {
    gen.dart_edge_sql_free_string(errorPtr);
  }
}
