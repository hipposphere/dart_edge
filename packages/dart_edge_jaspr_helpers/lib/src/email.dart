import 'package:jaspr/jaspr.dart'
    show BuildContext, Component, StatelessComponent;
import 'package:jaspr/server.dart' show Document;

import 'html.dart';
import 'icons.dart';
import 'palette.dart';

/// Primary action data for email templates.
final class DartEdgeEmailAction {
  const DartEdgeEmailAction({required this.label, required this.href});

  final String label;
  final String href;
}

/// Branded HTML email scaffold with inline styles.
final class DartEdgeEmailLayout extends StatelessComponent {
  const DartEdgeEmailLayout({
    required this.title,
    required this.headline,
    required this.children,
    this.eyebrow,
    this.previewText,
    this.appName = 'Dart Edge',
    this.icon = DartEdgeIconKind.spark,
    this.action,
    this.footerText = 'If this was not you, you can ignore this message.',
    this.palette = DartEdgeBrandPalette.standard,
    super.key,
  });

  final String title;
  final String headline;
  final List<Component> children;
  final String? eyebrow;
  final String? previewText;
  final String appName;
  final DartEdgeIconKind icon;
  final DartEdgeEmailAction? action;
  final String footerText;
  final DartEdgeBrandPalette palette;

  @override
  Component build(BuildContext context) {
    return Document(
      title: title,
      base: null,
      meta: const {
        'color-scheme': 'light only',
        'supported-color-schemes': 'light',
        'format-detection':
            'telephone=no, date=no, address=no, email=no, url=no',
      },
      body: Component.fragment([
        Document.body(
          attributes: {
            'style':
                'margin:0;background:${palette.background};'
                'font-family:$defaultFontStack;',
          },
        ),
        htmlElement(
          'div',
          styles: rawStyles({
            'margin': '0',
            'padding': '32px 16px 48px',
            'background':
                'linear-gradient(180deg, ${palette.soft} 0%, ${palette.background} 100%)',
            'color': palette.text,
          }),
          children: [
            if (previewText case final preview?)
              htmlElement(
                'div',
                styles: rawStyles({
                  'display': 'none',
                  'max-height': '0',
                  'overflow': 'hidden',
                  'opacity': '0',
                  'color': 'transparent',
                }),
                children: [textNode(preview)],
              ),
            htmlElement(
              'div',
              styles: rawStyles({'max-width': '640px', 'margin': '0 auto'}),
              children: [
                htmlElement(
                  'div',
                  styles: rawStyles({
                    'display': 'flex',
                    'align-items': 'center',
                    'gap': '12px',
                    'margin': '0 0 20px',
                  }),
                  children: [
                    DartEdgeIconBadge(
                      kind: DartEdgeIconKind.spark,
                      backgroundColor: palette.accent,
                      foregroundColor: palette.actionText,
                      size: 44,
                    ),
                    htmlElement(
                      'div',
                      children: [
                        labelText(
                          appName,
                          color: palette.text,
                          fontSize: '13px',
                          letterSpacing: '0.10em',
                        ),
                        paragraph(
                          'Polished HTML from Dart components',
                          color: palette.mutedText,
                          margin: '4px 0 0',
                          fontSize: '14px',
                        ),
                      ],
                    ),
                  ],
                ),
                htmlElement(
                  'div',
                  styles: rawStyles({
                    'background': palette.surface,
                    'border': '1px solid ${palette.border}',
                    'border-radius': '28px',
                    'padding': '32px',
                    'box-shadow':
                        '0 24px 60px rgba(16, 35, 61, 0.10),'
                        ' inset 0 1px 0 rgba(255, 255, 255, 0.50)',
                  }),
                  children: [
                    if (eyebrow case final eyebrow?)
                      htmlElement(
                        'div',
                        styles: rawStyles({
                          'display': 'inline-flex',
                          'align-items': 'center',
                          'padding': '7px 12px',
                          'border-radius': '999px',
                          'background': palette.soft,
                          'border': '1px solid ${palette.border}',
                        }),
                        children: [
                          labelText(
                            eyebrow,
                            color: palette.accentStrong,
                            margin: '0',
                          ),
                        ],
                      ),
                    spacer('24px'),
                    DartEdgeIconBadge(
                      kind: icon,
                      backgroundColor: palette.accent,
                      foregroundColor: palette.actionText,
                      size: 64,
                    ),
                    spacer('24px'),
                    heading('h1', headline, color: palette.text),
                    spacer('20px'),
                    htmlElement(
                      'div',
                      styles: rawStyles({'display': 'grid', 'gap': '14px'}),
                      children: children,
                    ),
                    if (action case final action?) ...[
                      spacer('28px'),
                      _actionButton(action, palette),
                    ],
                    spacer('28px'),
                    htmlElement(
                      'div',
                      styles: rawStyles({
                        'padding': '16px 18px',
                        'border-radius': '18px',
                        'background': palette.soft,
                        'border': '1px solid ${palette.border}',
                      }),
                      children: [
                        paragraph(
                          footerText,
                          color: palette.mutedText,
                          margin: '0',
                          fontSize: '14px',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ]),
    );
  }
}

Component _actionButton(
  DartEdgeEmailAction action,
  DartEdgeBrandPalette palette,
) {
  return htmlElement(
    'a',
    attributes: {'href': action.href},
    styles: rawStyles({
      'display': 'inline-block',
      'padding': '15px 22px',
      'border-radius': '18px',
      'background':
          'linear-gradient(135deg, ${palette.accent} 0%, ${palette.accentStrong} 100%)',
      'color': palette.actionText,
      'font-size': '15px',
      'font-weight': '700',
      'line-height': '1',
      'letter-spacing': '-0.01em',
      'text-decoration': 'none',
      'box-shadow': '0 16px 32px rgba(37, 99, 235, 0.24)',
    }),
    children: [textNode(action.label)],
  );
}
