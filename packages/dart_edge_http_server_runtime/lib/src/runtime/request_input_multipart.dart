import 'package:dart_edge_core/dart_edge_core.dart';

import 'native_request.dart';

extension MultipartRequestInput on RequestInput {
  /// Parses the request body as `multipart/form-data`.
  ///
  /// This is the ergonomic Dart request surface on top of the runtime-native
  /// multipart parser. Returned file bodies stay borrowed for the current
  /// request lifecycle.
  Future<NativeMultipartForm> multipart() {
    return multipartValue<NativeMultipartForm>();
  }
}
