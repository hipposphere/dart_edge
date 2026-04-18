/// Base interface for any route definition that can be registered on a
/// [Router].
abstract class RouteDefinition<TServices> {
  /// Metadata consumed by the runtime when the route is registered.
  Object get contract;
}
