import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:dart_edge_jaspr_helpers/dart_edge_jaspr_helpers.dart';
import 'package:test/test.dart';

void main() {
  test('renders the password reset email template', () async {
    final html = await JasprRenderer.renderString(
      const DartEdgePasswordResetEmail(
        resetUrl: 'https://example.com/reset?token=abc123',
        expiresInText: '15 minutes',
        supportEmail: 'support@example.com',
      ),
    );

    expect(html, contains('<title>Reset your password</title>'));
    expect(html, contains('Reset your password'));
    expect(html, contains('https://example.com/reset?token=abc123'));
    expect(html, contains('<svg'));
  });

  test('renders the notice page scaffold with actions', () async {
    final html = await JasprRenderer.renderString(
      const DartEdgeNoticePage(
        title: 'Email verified',
        headline: 'Your email is verified',
        message: 'You can head back to the app now.',
        detail: 'The next sign-in will use the updated address.',
        primaryAction: DartEdgeNoticePageAction(
          label: 'Open app',
          href: 'https://example.com/app',
        ),
        secondaryAction: DartEdgeNoticePageAction(
          label: 'Account settings',
          href: 'https://example.com/settings',
        ),
      ),
    );

    expect(html, contains('<title>Email verified</title>'));
    expect(html, contains('Your email is verified'));
    expect(html, contains('https://example.com/app'));
    expect(html, contains('https://example.com/settings'));
  });
}
