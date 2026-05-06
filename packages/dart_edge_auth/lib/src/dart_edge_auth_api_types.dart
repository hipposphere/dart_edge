part of 'dart_edge_auth.dart';

typedef _AsyncAuthRequest = ({
  int handle,
  String method,
  String path,
  Map<String, String> query,
  Map<String, String> headers,
  Uint8List? body,
});

typedef _AsyncAuthResponse = ({
  int status,
  String contentType,
  List<({String name, String value})> headers,
  String body,
});

typedef _AsyncTrustedAdminRequest = ({
  int handle,
  String operation,
  Map<String, Object?> query,
  Object? body,
});
