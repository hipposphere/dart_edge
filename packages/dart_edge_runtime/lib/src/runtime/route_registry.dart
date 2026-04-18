import '../contracts/http/route_contract.dart';
import '../routes/route_definition.dart';
import 'route_path.dart';

final class RouteRegistry<TServices> {
  final List<RouteRegistration<TServices>> registrations =
      <RouteRegistration<TServices>>[];

  void register({
    required String prefix,
    required List<String> tags,
    required List<Object> guards,
    required RouteDefinition<TServices> route,
  }) {
    registrations.add(
      RouteRegistration(
        prefix: prefix,
        tags: tags,
        guards: guards,
        route: route,
      ),
    );
  }
}

final class RouteRegistration<TServices> {
  RouteRegistration({
    required this.prefix,
    required List<String> tags,
    required List<Object> guards,
    required this.route,
  }) : tags = List<String>.unmodifiable(tags),
       guards = List<Object>.unmodifiable(guards);

  final String prefix;
  final List<String> tags;
  final List<Object> guards;
  final RouteDefinition<TServices> route;

  @override
  String toString() {
    final contract = route.contract;
    if (contract case final RouteContract contract) {
      final fullPath = joinRoutePath(prefix, contract.path);
      final parts = <String>[
        '${contract.method.name.toUpperCase()} $fullPath',
        'operationId: ${contract.operationId}',
        if (tags.isNotEmpty) 'tags: $tags',
        if (guards.isNotEmpty) 'guards: $guards',
        'route: $route',
      ];
      return 'RouteRegistration(${parts.join(', ')})';
    }

    return 'RouteRegistration(prefix: $prefix, tags: $tags, guards: $guards, route: $route)';
  }
}
