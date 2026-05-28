import 'dart:io';

import 'package:dart_edge_ci/dart_edge_ci.dart';
import 'package:test/test.dart';

void main() {
  test('constructs macOS build plan with pub get and build args', () async {
    final root = await Directory.systemTemp.createTemp('dart_edge_ci_');
    addTearDown(() => root.delete(recursive: true));
    final config = FlutterReleaseConfig.parse('''
package: app
dart_define_from_file: ../.local.env.json
variables:
  PUBLIC_API_URL: https://api.example.com
targets:
  macos_release:
    platform: macos
    dart_defines:
      API_URL: \${PUBLIC_API_URL}
    dart_define_from_file:
      - ../macos.env.json
    build_args:
      - --split-debug-info=build/symbols
''');

    final plan = FlutterReleaseBuilder(
      projectRoot: root,
    ).buildPlan(config, 'macos_release');

    expect(plan, [
      ['flutter', 'pub', 'get'],
      [
        'flutter',
        'build',
        'macos',
        '--release',
        '--dart-define-from-file',
        '../.local.env.json',
        '--dart-define-from-file',
        '../macos.env.json',
        '--dart-define=API_URL=https://api.example.com',
        '--split-debug-info=build/symbols',
      ],
    ]);
  });

  test('constructs web build with base href build arg', () async {
    final root = await Directory.systemTemp.createTemp('dart_edge_ci_');
    addTearDown(() => root.delete(recursive: true));
    final config = FlutterReleaseConfig.parse('''
package: app
pub_get: false
targets:
  web_release:
    platform: web
    dart_defines:
      API_URL: https://api.example.com
    build_args:
      - --base-href=/dicto/
''');

    final plan = FlutterReleaseBuilder(
      projectRoot: root,
    ).buildPlan(config, 'web_release');

    expect(plan, [
      [
        'flutter',
        'build',
        'web',
        '--release',
        '--dart-define=API_URL=https://api.example.com',
        '--base-href=/dicto/',
      ],
    ]);
  });

  test('constructs unsigned iOS ipa build with no-codesign', () async {
    final root = await Directory.systemTemp.createTemp('dart_edge_ci_');
    addTearDown(() => root.delete(recursive: true));
    final config = FlutterReleaseConfig.parse('''
package: app
pub_get: false
targets:
  ios_release:
    platform: ios
    signing: false
''');

    final plan = FlutterReleaseBuilder(
      projectRoot: root,
    ).buildPlan(config, 'ios_release');

    expect(plan, [
      ['flutter', 'build', 'ipa', '--release', '--no-codesign'],
    ]);
  });

  test('constructs Android apk build when configured', () async {
    final root = await Directory.systemTemp.createTemp('dart_edge_ci_');
    addTearDown(() => root.delete(recursive: true));
    final config = FlutterReleaseConfig.parse('''
package: app
pub_get: false
targets:
  android_release:
    platform: android
    artifact: apk
    flavor: production
    build_name: 1.2.3
    build_number: 42
''');

    final plan = FlutterReleaseBuilder(
      projectRoot: root,
    ).buildPlan(config, 'android_release');

    expect(plan, [
      [
        'flutter',
        'build',
        'apk',
        '--release',
        '--flavor',
        'production',
        '--build-name',
        '1.2.3',
        '--build-number',
        '42',
      ],
    ]);
  });

  test('returns default artifact upload paths', () {
    final config = FlutterReleaseConfig.parse('''
package: app
targets:
  android_release:
    platform: android
    artifact: appbundle
  ios_release:
    platform: ios
    signing: true
  linux_release:
    platform: linux
    enabled: true
  macos_release:
    platform: macos
    enabled: true
  web_release:
    platform: web
    enabled: true
  windows_release:
    platform: windows
    enabled: true
''');

    expect(flutterReleaseArtifactPaths(config, 'android_release'), [
      'app/build/app/outputs/bundle/release/*.aab',
    ]);
    expect(flutterReleaseArtifactPaths(config, 'ios_release'), [
      'app/build/ios/ipa/*.ipa',
    ]);
    expect(flutterReleaseArtifactPaths(config, 'macos_release'), [
      'app/build/macos/Build/Products/Release/*.app',
    ]);
    expect(flutterReleaseArtifactPaths(config, 'web_release'), [
      'app/build/web/**',
    ]);
  });

  test('constructs App Store Connect publish command', () {
    final command = appStoreConnectPublishCommand(
      const AppStoreConnectPublishConfig(
        ipa: 'build/ios/ipa/Dicto.ipa',
        fastlaneExecutable: 'bundle exec fastlane',
        submitForReview: true,
        skipMetadata: false,
        skipScreenshots: false,
        apiKey: AppStoreConnectApiKeyConfig(),
      ),
      ipaPath: 'build/ios/ipa/Dicto.ipa',
      apiKeyPath: '.dart_tool/dart_edge_ci/app_store_connect_api_key.json',
    );

    expect(command, [
      'bundle',
      'exec',
      'fastlane',
      'deliver',
      '--ipa',
      'build/ios/ipa/Dicto.ipa',
      '--api_key_path',
      '.dart_tool/dart_edge_ci/app_store_connect_api_key.json',
      '--skip_metadata',
      'false',
      '--skip_screenshots',
      'false',
      '--submit_for_review',
      'true',
    ]);
  });

  test('builds App Store Connect API key json from environment', () {
    final json = appStoreConnectApiKeyJson(
      const AppStoreConnectApiKeyConfig(
        keyIdEnv: 'ASC_KEY_ID',
        issuerIdEnv: 'ASC_ISSUER_ID',
        privateKeyEnv: 'ASC_PRIVATE_KEY',
      ),
      {
        'ASC_KEY_ID': 'ABC123',
        'ASC_ISSUER_ID': 'issuer-id',
        'ASC_PRIVATE_KEY':
            r'-----BEGIN PRIVATE KEY-----\nkey\n-----END PRIVATE KEY-----',
      },
    );

    expect(json, {
      'key_id': 'ABC123',
      'issuer_id': 'issuer-id',
      'key': '-----BEGIN PRIVATE KEY-----\nkey\n-----END PRIVATE KEY-----',
    });
  });

  test('constructs iOS signing install plan', () {
    final plan = iosSigningInstallPlan({
      'KEYCHAIN_PASSWORD': 'keychain-secret',
      'RUNNER_TEMP': '/tmp/runner',
      'HOME': '/Users/runner',
      'IOS_DISTRIBUTION_CERTIFICATE_PASSWORD': 'certificate-secret',
    });

    expect(plan.commands.first, [
      'security',
      'create-keychain',
      '-p',
      'keychain-secret',
      'build.keychain',
    ]);
    expect(plan.commands[1], [
      'security',
      'default-keychain',
      '-s',
      'build.keychain',
    ]);
    expect(plan.commands[5], [
      'security',
      'import',
      '/tmp/runner/ios_distribution.p12',
      '-k',
      'build.keychain',
      '-P',
      'certificate-secret',
      '-T',
      '/usr/bin/codesign',
      '-T',
      '/usr/bin/security',
    ]);
    expect(plan.commands.last, [
      'find',
      '/tmp/runner/profiles',
      '-name',
      '*.mobileprovision',
      '-exec',
      'cp',
      '{}',
      '/Users/runner/Library/MobileDevice/Provisioning Profiles',
      ';',
    ]);
  });
}
