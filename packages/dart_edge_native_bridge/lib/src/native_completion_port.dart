import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

/// Receive-port wrapper for native job completion notifications.
///
/// Native code should post completed job ids to [nativePort]. Dart code can
/// listen to [completedJobIds] and then fetch the actual result through the
/// package-specific FFI API.
final class NativeCompletionPort {
  NativeCompletionPort() : _receivePort = ReceivePort() {
    _subscription = _receivePort.listen(_handleMessage);
  }

  final ReceivePort _receivePort;
  late final StreamSubscription<Object?> _subscription;
  final _controller = StreamController<int>.broadcast(sync: true);

  /// Port value suitable for passing to native code.
  int get nativePort => _receivePort.sendPort.nativePort;

  /// Completed native job ids.
  Stream<int> get completedJobIds => _controller.stream;

  void _handleMessage(Object? message) {
    if (message is int) {
      _controller.add(message);
      return;
    }
    _controller.addError(
      StateError('Native completion port received non-integer message.'),
    );
  }

  /// Closes the underlying receive port.
  Future<void> close() async {
    await _subscription.cancel();
    _receivePort.close();
    await _controller.close();
  }
}
