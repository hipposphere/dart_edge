import '../http/http_method.dart';
import 'route_options.dart';

/// Binds native HTTP route metadata to a native handler function.
final class NativeHttpRouteMount {
  const NativeHttpRouteMount({
    required this.method,
    required this.path,
    required this.options,
    required this.nativeHandle,
    required this.nativeHandlerAddress,
    required this.nativeFreeResponseAddress,
  });

  /// HTTP method accepted by the native route.
  final HttpMethod method;

  /// Route path pattern, for example `/auth/sign-in/email`.
  final String path;

  /// Documentation and validation options for the route.
  final RouteOptions options;

  /// Opaque native instance handle passed to the handler.
  final int nativeHandle;

  /// Address of a native HTTP handler function.
  final int nativeHandlerAddress;

  /// Address of the function that frees responses from [nativeHandlerAddress].
  final int nativeFreeResponseAddress;
}
