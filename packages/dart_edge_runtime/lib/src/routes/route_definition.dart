/// Base interface for any route definition that can be registered on a
/// [Router].
///
/// The exact contract type depends on the route kind. HTTP routes return a
/// [RouteContract], while future route kinds may expose different contract
/// objects.
abstract class RouteDefinition<TServices> {
  /// Metadata consumed by the runtime when the route is registered.
  Object get contract;
}
