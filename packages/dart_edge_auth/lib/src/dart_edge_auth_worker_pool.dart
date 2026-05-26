part of 'dart_edge_auth.dart';

final class _DartEdgeAuthWorkerPool {
  _DartEdgeAuthWorkerPool({required this.size});

  final int size;
  Future<DartEdgeIsolateWorkerPool>? _poolFuture;

  Future<_AsyncAuthResponse> request(Object request) async {
    final pool = await _pool();
    return pool.request<_AsyncAuthResponse>(request);
  }

  Future<DartEdgeIsolateWorkerPool> _pool() {
    return _poolFuture ??= DartEdgeIsolateWorkerPool.spawn(
      handler: _handleAuthWorkerRequest,
      debugName: 'DartEdgeAuthWorker',
      size: size,
      strategy: DartEdgeIsolateWorkerPoolStrategy.leastPending,
    );
  }

  void close() {
    final poolFuture = _poolFuture;
    _poolFuture = null;
    if (poolFuture != null) {
      unawaited(poolFuture.then((pool) => pool.close()));
    }
  }
}

Object? _handleAuthWorkerRequest(Object? request) {
  return switch (request) {
    final _AsyncAuthRequest authRequest => _performNativeAuthRequest(
      authRequest,
    ),
    final _AsyncTrustedAdminRequest adminRequest =>
      _performNativeTrustedAdminCall(adminRequest),
    _ => throw StateError('Unknown Dart Edge auth worker request: $request'),
  };
}
