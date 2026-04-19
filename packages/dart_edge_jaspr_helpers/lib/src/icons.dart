import 'package:jaspr/dom.dart' show Styles;
import 'package:jaspr/jaspr.dart'
    show BuildContext, Component, StatelessComponent;

import 'html.dart';

/// Inline SVG icons used by the built-in page and email components.
enum DartEdgeIconKind { mail, lock, shield, spark }

/// Renders one inline SVG icon.
final class DartEdgeIcon extends StatelessComponent {
  const DartEdgeIcon({
    required this.kind,
    this.color = '#2563eb',
    this.size = 24,
    super.key,
  });

  final DartEdgeIconKind kind;
  final String color;
  final int size;

  @override
  Component build(BuildContext context) {
    return htmlElement(
      'svg',
      attributes: {
        'xmlns': 'http://www.w3.org/2000/svg',
        'viewBox': '0 0 24 24',
        'width': '$size',
        'height': '$size',
        'fill': 'none',
        'stroke': color,
        'stroke-width': '1.8',
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round',
        'aria-hidden': 'true',
      },
      children: _iconChildren(kind),
    );
  }
}

/// Renders a rounded icon badge.
final class DartEdgeIconBadge extends StatelessComponent {
  const DartEdgeIconBadge({
    required this.kind,
    this.backgroundColor = '#eff5ff',
    this.foregroundColor = '#2563eb',
    this.size = 56,
    super.key,
  });

  final DartEdgeIconKind kind;
  final String backgroundColor;
  final String foregroundColor;
  final int size;

  @override
  Component build(BuildContext context) {
    final iconSize = (size * 0.46).round();
    return htmlElement(
      'div',
      styles: Styles(
        raw: {
          'width': '${size}px',
          'height': '${size}px',
          'display': 'flex',
          'align-items': 'center',
          'justify-content': 'center',
          'border-radius': '${(size / 3).round()}px',
          'background': backgroundColor,
          'box-shadow': 'inset 0 1px 0 rgba(255, 255, 255, 0.26)',
        },
      ),
      children: [
        DartEdgeIcon(kind: kind, color: foregroundColor, size: iconSize),
      ],
    );
  }
}

List<Component> _iconChildren(DartEdgeIconKind kind) {
  return switch (kind) {
    DartEdgeIconKind.mail => [
      _svg('rect', {
        'x': '3.5',
        'y': '6',
        'width': '17',
        'height': '12',
        'rx': '2.5',
      }),
      _svg('path', {'d': 'm4 7 8 6 8-6'}),
    ],
    DartEdgeIconKind.lock => [
      _svg('path', {'d': 'M8 10V8a4 4 0 1 1 8 0v2'}),
      _svg('rect', {
        'x': '5',
        'y': '10',
        'width': '14',
        'height': '10',
        'rx': '2',
      }),
      _svg('path', {'d': 'M12 14v2'}),
    ],
    DartEdgeIconKind.shield => [
      _svg('path', {
        'd': 'M12 3 19 6v6c0 5-3.5 7.5-7 9-3.5-1.5-7-4-7-9V6l7-3Z',
      }),
      _svg('path', {'d': 'm9.5 12 1.7 1.7 3.3-3.3'}),
    ],
    DartEdgeIconKind.spark => [
      _svg('path', {
        'd': 'M12 3 13.9 8.1 19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3Z',
      }),
    ],
  };
}

Component _svg(String tag, Map<String, String> attributes) {
  return Component.element(tag: tag, attributes: attributes);
}
