import 'package:jaspr/jaspr.dart'
    show BuildContext, Component, StatelessComponent;
import 'package:jaspr/server.dart' show Document;

import 'html.dart';
import 'icons.dart';
import 'palette.dart';

/// Action button data for notice pages.
final class DartEdgeNoticePageAction {
  const DartEdgeNoticePageAction({required this.label, required this.href});

  final String label;
  final String href;
}

/// Branded browser-facing confirmation or next-step page.
final class DartEdgeNoticePage extends StatelessComponent {
  const DartEdgeNoticePage({
    required this.title,
    required this.headline,
    required this.message,
    this.detail,
    this.appName = 'Dart Edge',
    this.icon = DartEdgeIconKind.spark,
    this.primaryAction,
    this.secondaryAction,
    this.palette = DartEdgeBrandPalette.standard,
    super.key,
  });

  final String title;
  final String headline;
  final String message;
  final String? detail;
  final String appName;
  final DartEdgeIconKind icon;
  final DartEdgeNoticePageAction? primaryAction;
  final DartEdgeNoticePageAction? secondaryAction;
  final DartEdgeBrandPalette palette;

  @override
  Component build(BuildContext context) {
    return Document(
      title: title,
      base: null,
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
            'min-height': '100vh',
            'padding': '32px 16px',
            'display': 'flex',
            'align-items': 'center',
            'justify-content': 'center',
            'background':
                'radial-gradient(circle at top, ${palette.soft} 0%, ${palette.background} 54%, ${palette.surface} 100%)',
          }),
          children: [
            htmlElement(
              'div',
              styles: rawStyles({'width': '100%', 'max-width': '760px'}),
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
                      size: 46,
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
                          'Jaspr-powered HTML surface',
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
                    'background': 'rgba(255, 255, 255, 0.82)',
                    'backdrop-filter': 'blur(16px)',
                    'border': '1px solid ${palette.border}',
                    'border-radius': '32px',
                    'padding': '32px',
                    'box-shadow': '0 28px 80px rgba(16, 35, 61, 0.12)',
                  }),
                  children: [
                    htmlElement(
                      'div',
                      styles: rawStyles({
                        'display': 'grid',
                        'grid-template-columns':
                            'minmax(0, 96px) minmax(0, 1fr)',
                        'gap': '24px',
                        'align-items': 'center',
                      }),
                      children: [
                        DartEdgeIconBadge(
                          kind: icon,
                          backgroundColor: palette.accent,
                          foregroundColor: palette.actionText,
                          size: 96,
                        ),
                        htmlElement(
                          'div',
                          children: [
                            labelText(
                              title,
                              color: palette.accentStrong,
                              margin: '0 0 12px',
                            ),
                            heading('h1', headline, color: palette.text),
                            spacer('16px'),
                            paragraph(
                              message,
                              color: palette.text,
                              margin: '0',
                              fontSize: '18px',
                              lineHeight: '1.65',
                            ),
                            if (detail case final detail?) ...[
                              spacer('12px'),
                              paragraph(
                                detail,
                                color: palette.mutedText,
                                margin: '0',
                                fontSize: '15px',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (primaryAction != null || secondaryAction != null) ...[
                      spacer('28px'),
                      htmlElement(
                        'div',
                        styles: rawStyles({
                          'display': 'flex',
                          'flex-wrap': 'wrap',
                          'gap': '12px',
                        }),
                        children: [
                          if (primaryAction case final action?)
                            _pageActionButton(action, palette, filled: true),
                          if (secondaryAction case final action?)
                            _pageActionButton(action, palette, filled: false),
                        ],
                      ),
                    ],
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

Component _pageActionButton(
  DartEdgeNoticePageAction action,
  DartEdgeBrandPalette palette, {
  required bool filled,
}) {
  return htmlElement(
    'a',
    attributes: {'href': action.href},
    styles: rawStyles({
      'display': 'inline-block',
      'padding': '15px 20px',
      'border-radius': '18px',
      'text-decoration': 'none',
      'font-size': '15px',
      'font-weight': '700',
      'line-height': '1',
      'letter-spacing': '-0.01em',
      'background': filled ? palette.accent : palette.surface,
      'border': '1px solid ${filled ? palette.accent : palette.border}',
      'color': filled ? palette.actionText : palette.text,
      'box-shadow': filled ? '0 14px 28px rgba(37, 99, 235, 0.22)' : 'none',
    }),
    children: [textNode(action.label)],
  );
}
