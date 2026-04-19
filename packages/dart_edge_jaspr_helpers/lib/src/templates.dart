import 'package:jaspr/jaspr.dart'
    show BuildContext, Component, StatelessComponent;

import 'email.dart';
import 'html.dart';
import 'icons.dart';
import 'palette.dart';

/// Ready-to-render password reset email template.
final class DartEdgePasswordResetEmail extends StatelessComponent {
  const DartEdgePasswordResetEmail({
    required this.resetUrl,
    this.appName = 'Dart Edge',
    this.expiresInText = '30 minutes',
    this.supportEmail,
    this.palette = DartEdgeBrandPalette.standard,
    super.key,
  });

  final String resetUrl;
  final String appName;
  final String expiresInText;
  final String? supportEmail;
  final DartEdgeBrandPalette palette;

  @override
  Component build(BuildContext context) {
    return DartEdgeEmailLayout(
      title: 'Reset your password',
      eyebrow: 'Security',
      headline: 'Reset your password',
      previewText: 'Use the secure link to choose a new password.',
      appName: appName,
      icon: DartEdgeIconKind.lock,
      action: DartEdgeEmailAction(label: 'Reset password', href: resetUrl),
      footerText: switch (supportEmail) {
        final email? =>
          'If you need help, contact $email. If you did not request this reset, ignore this email.',
        null =>
          'If you did not request a password reset, you can safely ignore this email.',
      },
      palette: palette,
      children: [
        paragraph(
          'We received a request to reset the password for your $appName account.',
          color: palette.text,
        ),
        paragraph(
          'This secure link stays active for $expiresInText and can be used once.',
          color: palette.mutedText,
        ),
        paragraph(
          'If the button does not open correctly, copy and paste this URL:',
          color: palette.mutedText,
        ),
        _urlPanel(label: 'Reset link', url: resetUrl, palette: palette),
      ],
    );
  }
}

/// Ready-to-render email verification template.
final class DartEdgeVerificationEmail extends StatelessComponent {
  const DartEdgeVerificationEmail({
    required this.verifyUrl,
    this.appName = 'Dart Edge',
    this.palette = DartEdgeBrandPalette.standard,
    super.key,
  });

  final String verifyUrl;
  final String appName;
  final DartEdgeBrandPalette palette;

  @override
  Component build(BuildContext context) {
    return DartEdgeEmailLayout(
      title: 'Verify your email',
      eyebrow: 'Account',
      headline: 'Verify your email address',
      previewText: 'Confirm your email to finish setting up your account.',
      appName: appName,
      icon: DartEdgeIconKind.shield,
      action: DartEdgeEmailAction(label: 'Verify email', href: verifyUrl),
      footerText:
          'If you did not create an account, no further action is required.',
      palette: palette,
      children: [
        paragraph(
          'Confirming your email unlocks the rest of the $appName sign-in flow and helps keep your account secure.',
          color: palette.text,
        ),
        paragraph(
          'If the verification button does not work, copy and paste this URL:',
          color: palette.mutedText,
        ),
        _urlPanel(label: 'Verification link', url: verifyUrl, palette: palette),
      ],
    );
  }
}

Component _urlPanel({
  required String label,
  required String url,
  required DartEdgeBrandPalette palette,
}) {
  return htmlElement(
    'div',
    styles: rawStyles({
      'padding': '14px 16px',
      'border-radius': '18px',
      'background': palette.soft,
      'border': '1px solid ${palette.border}',
    }),
    children: [
      labelText(label, color: palette.mutedText, margin: '0 0 8px'),
      htmlElement(
        'a',
        attributes: {'href': url},
        styles: rawStyles({
          'color': palette.accentStrong,
          'font-family':
              '"SFMono-Regular", "SF Mono", ui-monospace, Menlo, monospace',
          'font-size': '13px',
          'line-height': '1.7',
          'text-decoration': 'none',
          'word-break': 'break-all',
        }),
        children: [textNode(url)],
      ),
    ],
  );
}
