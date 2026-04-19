/// Shared color palette used by the built-in Jaspr helper components.
final class DartEdgeBrandPalette {
  const DartEdgeBrandPalette({
    this.accent = '#2563eb',
    this.accentStrong = '#174ac7',
    this.surface = '#ffffff',
    this.background = '#edf4ff',
    this.soft = '#f7faff',
    this.text = '#10233d',
    this.mutedText = '#5b6b82',
    this.border = '#d8e2f0',
    this.actionText = '#ffffff',
  });

  static const DartEdgeBrandPalette standard = DartEdgeBrandPalette();

  final String accent;
  final String accentStrong;
  final String surface;
  final String background;
  final String soft;
  final String text;
  final String mutedText;
  final String border;
  final String actionText;

  DartEdgeBrandPalette copyWith({
    String? accent,
    String? accentStrong,
    String? surface,
    String? background,
    String? soft,
    String? text,
    String? mutedText,
    String? border,
    String? actionText,
  }) {
    return DartEdgeBrandPalette(
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      surface: surface ?? this.surface,
      background: background ?? this.background,
      soft: soft ?? this.soft,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      actionText: actionText ?? this.actionText,
    );
  }
}
