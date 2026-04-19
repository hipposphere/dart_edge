import '../http/route_contract.dart';
import 'guard.dart';
import 'route_definition.dart';
import 'route_path.dart';

/// In-memory route registration table shared across router scopes.
final class RouteRegistry<TServices> {
  final List<RouteRegistration<TServices>> registrations =
      <RouteRegistration<TServices>>[];

  void register({
    required String prefix,
    required List<String> tags,
    required List<Guard<TServices>> guards,
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

/// One registered route together with inherited router metadata.
final class RouteRegistration<TServices> {
  RouteRegistration({
    required this.prefix,
    required List<String> tags,
    required List<Guard<TServices>> guards,
    required this.route,
  }) : tags = List<String>.unmodifiable(tags),
       guards = List<Guard<TServices>>.unmodifiable(guards);

  final String prefix;
  final List<String> tags;
  final List<Guard<TServices>> guards;
  final RouteDefinition<TServices> route;

  @override
  String toString() {
    final contract = route.contract;
    if (contract case final RouteContract contract) {
      final fullPath = joinRoutePath(prefix, contract.path);
      final routeTags = _mergeTags(tags, contract.options.tags);
      final parts = <String>[
        '${contract.method.name.toUpperCase()} $fullPath',
        'operationId: ${contract.options.operationId!}',
        if (routeTags.isNotEmpty) 'tags: $routeTags',
        if (guards.isNotEmpty) 'guards: $guards',
        'route: $route',
      ];
      return 'RouteRegistration(${parts.join(', ')})';
    }

    return 'RouteRegistration(prefix: $prefix, tags: $tags, guards: $guards, route: $route)';
  }
}

List<String> _mergeTags(Iterable<String> first, Iterable<String> second) {
  final merged = <String>[];
  final seen = <String>{};
  for (final tag in [...first, ...second]) {
    if (seen.add(tag)) {
      merged.add(tag);
    }
  }
  return merged;
}
