import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:shadcn_jaspr/shadcn_jaspr.dart';

/// Registers shadcn-backed components for MDX-style content blocks.
final class DartEdgeShadcnMdxComponents {
  const DartEdgeShadcnMdxComponents._();

  /// Default components available in `.mdx` files.
  static List<CustomComponent> defaults() {
    return [
      CustomComponent(
        pattern: RegExp(r'^[Cc]allout$'),
        builder: (_, attributes, child) {
          final title = attributes['title'];
          return ShadAlert([
            ?_alertTitle(title),
            ?_alertDescription(child),
          ], variant: _alertVariant(attributes['variant']));
        },
      ),
      CustomComponent(
        pattern: RegExp(r'^[Bb]adge$'),
        builder: (_, attributes, child) {
          return ShadBadge([
            ?child,
          ], variant: _badgeVariant(attributes['variant']));
        },
      ),
      CustomComponent(
        pattern: RegExp(r'^[Cc]ard$'),
        builder: (_, attributes, child) {
          final title = attributes['title'];
          final description = attributes['description'];
          return ShadCard([
            if (title != null || description != null)
              ShadCardHeader([
                if (title != null) ShadCardTitle([Component.text(title)]),
                if (description != null)
                  ShadCardDescription([Component.text(description)]),
              ]),
            if (child != null) ShadCardContent([child]),
          ]);
        },
      ),
      CustomComponent(
        pattern: RegExp(r'^[Bb]utton[Ll]ink$'),
        builder: (_, attributes, child) {
          final href = attributes['href'] ?? '#';
          return Component.element(
            tag: 'a',
            attributes: {'href': href},
            children: [
              ShadButton(
                [?child],
                variant: _buttonVariant(attributes['variant']),
                size: _buttonSize(attributes['size']),
              ),
            ],
          );
        },
      ),
    ];
  }
}

Component? _alertTitle(String? title) {
  return title == null ? null : ShadAlertTitle([Component.text(title)]);
}

Component? _alertDescription(Component? child) {
  return child == null ? null : ShadAlertDescription([child]);
}

AlertVariant _alertVariant(String? value) {
  return switch (value) {
    'destructive' || 'danger' => AlertVariant.destructive,
    _ => AlertVariant.defaultVariant,
  };
}

BadgeVariant _badgeVariant(String? value) {
  return switch (value) {
    'secondary' => BadgeVariant.secondary,
    'destructive' || 'danger' => BadgeVariant.destructive,
    'outline' => BadgeVariant.outline,
    'ghost' => BadgeVariant.ghost,
    'link' => BadgeVariant.link,
    _ => BadgeVariant.defaultVariant,
  };
}

ButtonVariant? _buttonVariant(String? value) {
  return switch (value) {
    'destructive' || 'danger' => ButtonVariant.destructive,
    'outline' => ButtonVariant.outline,
    'secondary' => ButtonVariant.secondary,
    'ghost' => ButtonVariant.ghost,
    'link' => ButtonVariant.link,
    _ => null,
  };
}

ButtonSize? _buttonSize(String? value) {
  return switch (value) {
    'xs' => ButtonSize.xs,
    'sm' => ButtonSize.sm,
    'lg' => ButtonSize.lg,
    'icon' => ButtonSize.icon,
    'icon-xs' => ButtonSize.iconXs,
    'icon-sm' => ButtonSize.iconSm,
    'icon-lg' => ButtonSize.iconLg,
    _ => null,
  };
}
