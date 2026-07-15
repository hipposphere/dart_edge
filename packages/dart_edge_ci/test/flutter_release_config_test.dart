import 'package:dart_edge_ci/dart_edge_ci.dart';
import 'package:test/test.dart';

void main() {
  test('parses Flutter release config', () {
    final config = FlutterReleaseConfig.parse('''
package: app
flutter: fvm flutter
build_mode: release
pub_get: false
variables:
  PUBLIC_API_URL: https://api.example.com
dart_define_from_file: .local.env.json
targets:
  macos_release:
    platform: macos
    signing:
      enabled: true
      required_env:
        - MACOS_CERTIFICATE
    dart_defines:
      API_URL: \${PUBLIC_API_URL}
    dart_define_from_file:
      - macos.env.json
    build_args:
      - --obfuscate
  android_release:
    platform: android
    artifact: apk
    flavor: production
    build_name: 1.2.3
    build_number: 42
    signing: false
  web_release:
    platform: web
    enabled: true
    build_args:
      - --wasm
  ios_release:
    platform: ios
    publish:
      app_store_connect:
        ipa: build/ios/ipa/Dicto.ipa
        fastlane: bundle exec fastlane
        submit_for_review: true
        skip_metadata: false
        skip_screenshots: false
        run_precheck_before_submit: false
        precheck_include_in_app_purchases: true
        api_key:
          key_id_env: ASC_KEY_ID
          issuer_id_env: ASC_ISSUER_ID
          private_key_env: ASC_PRIVATE_KEY
''');

    expect(config.packagePath, 'app');
    expect(config.flutterExecutable, 'fvm flutter');
    expect(config.pubGet, isFalse);
    expect(config.variables, {'PUBLIC_API_URL': 'https://api.example.com'});
    expect(config.dartDefineFromFiles, ['.local.env.json']);

    final macos = config.target('macos_release');
    expect(macos.signing.enabled, isTrue);
    expect(macos.signing.requiredEnv, ['MACOS_CERTIFICATE']);
    expect(macos.dartDefines, {'API_URL': 'https://api.example.com'});
    expect(macos.dartDefineFromFiles, ['macos.env.json']);
    expect(macos.buildArgs, ['--obfuscate']);

    final android = config.target('android_release');
    expect(android.androidArtifact, AndroidArtifact.apk);
    expect(android.flavor, 'production');
    expect(android.buildName, '1.2.3');
    expect(android.buildNumber, '42');

    final web = config.target('web_release');
    expect(web.enabled, isTrue);
    expect(web.buildArgs, ['--wasm']);

    final publish = config.target('ios_release').publish.appStoreConnect!;
    expect(publish.ipa, 'build/ios/ipa/Dicto.ipa');
    expect(publish.fastlaneExecutable, 'bundle exec fastlane');
    expect(publish.submitForReview, isTrue);
    expect(publish.skipMetadata, isFalse);
    expect(publish.skipScreenshots, isFalse);
    expect(publish.runPrecheckBeforeSubmit, isFalse);
    expect(publish.precheckIncludeInAppPurchases, isTrue);
    expect(publish.apiKey.keyIdEnv, 'ASC_KEY_ID');
    expect(publish.apiKey.issuerIdEnv, 'ASC_ISSUER_ID');
    expect(publish.apiKey.privateKeyEnv, 'ASC_PRIVATE_KEY');
  });

  test('disables unsupported in-app purchase precheck by default', () {
    final config = FlutterReleaseConfig.parse('''
package: app
targets:
  ios_release:
    platform: ios
    publish:
      app_store_connect:
        api_key: {}
''');

    final publish = config.target('ios_release').publish.appStoreConnect!;
    expect(publish.runPrecheckBeforeSubmit, isTrue);
    expect(publish.precheckIncludeInAppPurchases, isFalse);
  });

  test('reports undefined Flutter release variables', () {
    expect(
      () => FlutterReleaseConfig.parse('''
package: app
targets:
  macos_release:
    platform: macos
    dart_defines:
      API_URL: \${PUBLIC_API_URL}
'''),
      throwsA(
        isA<FlutterReleaseException>().having(
          (error) => error.message,
          'message',
          contains(
            'targets.macos_release.dart_defines.API_URL references undefined variable "PUBLIC_API_URL"',
          ),
        ),
      ),
    );
  });

  test('reports invalid platform names', () {
    expect(
      () => FlutterReleaseConfig.parse('''
package: app
targets:
  beos:
    enabled: true
'''),
      throwsA(
        isA<FlutterReleaseException>().having(
          (error) => error.message,
          'message',
          contains('targets.beos.platform is required'),
        ),
      ),
    );
  });
}
