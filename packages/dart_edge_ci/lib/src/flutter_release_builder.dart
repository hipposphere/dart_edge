import 'dart:convert';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'flutter_release_config.dart';
import 'process_utils.dart';

final class FlutterReleaseBuilder {
  const FlutterReleaseBuilder({
    required this.projectRoot,
    this.processRunner = const CommandProcessRunner(),
  });

  final Directory projectRoot;
  final CommandProcessRunner processRunner;

  Future<FlutterReleaseConfig> loadConfig() {
    return FlutterReleaseConfig.load(projectRoot);
  }

  Future<int> build(
    String targetName, {
    FlutterReleaseConfig? config,
    bool dryRun = false,
  }) async {
    final releaseConfig = config ?? await loadConfig();
    final target = releaseConfig.target(targetName);
    if (!target.enabled) {
      throw FlutterReleaseException(
        'Target "$targetName" is disabled in flutter_release.yaml.',
      );
    }
    if (!dryRun) {
      _validateSigningEnvironment(target);
    }

    final packageRoot = _packageRoot(releaseConfig.packagePath);
    final commands = buildPlan(releaseConfig, targetName);
    for (final command in commands) {
      stdout.writeln('Running: ${shellCommand(command)}');
      if (dryRun) {
        continue;
      }
      final exitCode = await processRunner.run(
        command.first,
        command.skip(1).toList(),
        workingDirectory: packageRoot.path,
      );
      if (exitCode != 0) {
        stderr.writeln('Flutter build failed for "$targetName".');
        stderr.writeln('Command: ${shellCommand(command)}');
        return exitCode;
      }
    }
    return 0;
  }

  Future<int> publishIosAppStore({
    String? targetName,
    FlutterReleaseConfig? config,
    bool dryRun = false,
  }) async {
    final releaseConfig = config ?? await loadConfig();
    final target = targetName == null
        ? _singleAppStoreConnectTarget(releaseConfig)
        : releaseConfig.target(targetName);
    final publishConfig = target.publish.appStoreConnect;
    if (publishConfig == null) {
      throw FlutterReleaseException(
        'targets.${target.name}.publish.app_store_connect is required.',
      );
    }
    if (target.platform != FlutterReleasePlatform.ios) {
      throw FlutterReleaseException(
        'Target "${target.name}" must use platform ios to publish to App Store Connect.',
      );
    }

    final packageRoot = _packageRoot(releaseConfig.packagePath);
    final ipa = dryRun
        ? publishConfig.ipa
        : await _resolveSingleIpa(packageRoot, publishConfig.ipa);
    final apiKeyFile = File(
      p.join(
        projectRoot.path,
        '.dart_tool',
        'dart_edge_ci',
        'app_store_connect_api_key.json',
      ),
    );
    final command = appStoreConnectPublishCommand(
      publishConfig,
      ipaPath: ipa,
      apiKeyPath: apiKeyFile.path,
    );

    if (dryRun) {
      stdout.writeln(
        'Would write App Store Connect API key: ${apiKeyFile.path}',
      );
      stdout.writeln('Running: ${shellCommand(command)}');
      return 0;
    }

    await _writeAppStoreConnectApiKey(
      apiKeyFile,
      publishConfig.apiKey,
      Platform.environment,
    );
    try {
      stdout.writeln('Running: ${shellCommand(command)}');
      final exitCode = await processRunner.run(
        command.first,
        command.skip(1).toList(),
        workingDirectory: packageRoot.path,
      );
      if (exitCode != 0) {
        stderr.writeln('App Store Connect upload failed.');
        stderr.writeln('Command: ${shellCommand(command)}');
      }
      return exitCode;
    } finally {
      if (await apiKeyFile.exists()) {
        await apiKeyFile.delete();
      }
    }
  }

  Future<int> installIosSigningMaterial({
    String? targetName,
    FlutterReleaseConfig? config,
    bool dryRun = false,
  }) async {
    if (config != null || targetName != null) {
      final releaseConfig = config ?? await loadConfig();
      final target = targetName == null
          ? _singleIosSigningTarget(releaseConfig)
          : releaseConfig.target(targetName);
      if (target.platform != FlutterReleasePlatform.ios) {
        throw FlutterReleaseException(
          'Target "${target.name}" must use platform ios to install iOS signing material.',
        );
      }
      if (!dryRun) {
        _validateSigningEnvironment(target);
      }
    }

    final plan = iosSigningInstallPlan(
      dryRun ? _iosSigningDryRunEnvironment() : Platform.environment,
    );
    for (final command in plan.commands) {
      stdout.writeln('Running: ${shellCommand(command)}');
      if (dryRun) {
        continue;
      }
      final exitCode = await processRunner.run(command.first, [
        ...command.skip(1),
      ]);
      if (exitCode != 0) {
        stderr.writeln('iOS signing setup failed.');
        stderr.writeln('Command: ${shellCommand(command)}');
        return exitCode;
      }
    }
    return 0;
  }

  List<List<String>> buildPlan(FlutterReleaseConfig config, String targetName) {
    final target = config.target(targetName);
    final commands = <List<String>>[];
    if (config.pubGet) {
      commands.add([..._flutterCommand(config), 'pub', 'get']);
    }
    commands.add(_buildCommand(config, target));
    return commands;
  }

  Directory _packageRoot(String packagePath) {
    return Directory(
      p.isAbsolute(packagePath)
          ? packagePath
          : p.join(projectRoot.path, packagePath),
    );
  }
}

Map<String, String> _iosSigningDryRunEnvironment() {
  return {
    ...Platform.environment,
    'KEYCHAIN_PASSWORD': Platform.environment['KEYCHAIN_PASSWORD'] ?? '***',
    'RUNNER_TEMP':
        Platform.environment['RUNNER_TEMP'] ??
        p.join(Directory.systemTemp.path, 'dart_edge_ci'),
    'HOME': Platform.environment['HOME'] ?? Directory.current.path,
    'IOS_DISTRIBUTION_CERTIFICATE_PASSWORD':
        Platform.environment['IOS_DISTRIBUTION_CERTIFICATE_PASSWORD'] ?? '***',
  };
}

FlutterTargetConfig _singleIosSigningTarget(FlutterReleaseConfig config) {
  final targets = [
    for (final target in config.targets.values)
      if (target.platform == FlutterReleasePlatform.ios &&
          target.signing.enabled)
        target,
  ];
  if (targets.length != 1) {
    throw FlutterReleaseException(
      'Expected exactly one iOS target with signing enabled, found ${targets.length}.',
    );
  }
  return targets.single;
}

FlutterTargetConfig _singleAppStoreConnectTarget(FlutterReleaseConfig config) {
  final targets = [
    for (final target in config.targets.values)
      if (target.publish.appStoreConnect != null) target,
  ];
  if (targets.length != 1) {
    throw FlutterReleaseException(
      'Expected exactly one target with publish.app_store_connect, found ${targets.length}.',
    );
  }
  return targets.single;
}

final class IosSigningInstallPlan {
  const IosSigningInstallPlan({required this.commands});

  final List<List<String>> commands;
}

IosSigningInstallPlan iosSigningInstallPlan(Map<String, String> environment) {
  final keychainPassword = _requiredEnvironment(
    environment,
    'KEYCHAIN_PASSWORD',
  );
  final runnerTemp = environment['RUNNER_TEMP'] ?? Directory.systemTemp.path;
  final home = environment['HOME'] ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw const FlutterReleaseException(
      'iOS signing setup requires HOME to locate provisioning profiles.',
    );
  }

  final certificatePath = p.join(runnerTemp, 'ios_distribution.p12');
  final profilesArchivePath = p.join(runnerTemp, 'profiles.tar.gz');
  final profilesExtractDir = p.join(runnerTemp, 'profiles');
  final profilesDestination = p.join(
    home,
    'Library',
    'MobileDevice',
    'Provisioning Profiles',
  );

  return IosSigningInstallPlan(
    commands: [
      ['security', 'create-keychain', '-p', keychainPassword, 'build.keychain'],
      ['security', 'default-keychain', '-s', 'build.keychain'],
      ['security', 'unlock-keychain', '-p', keychainPassword, 'build.keychain'],
      ['security', 'set-keychain-settings', '-lut', '21600', 'build.keychain'],
      [
        'sh',
        '-c',
        'printf %s "\$IOS_DISTRIBUTION_CERTIFICATE_BASE64" | base64 --decode > ${_shellPath(certificatePath)}',
      ],
      [
        'security',
        'import',
        certificatePath,
        '-k',
        'build.keychain',
        '-P',
        _requiredEnvironment(
          environment,
          'IOS_DISTRIBUTION_CERTIFICATE_PASSWORD',
        ),
        '-T',
        '/usr/bin/codesign',
        '-T',
        '/usr/bin/security',
      ],
      [
        'security',
        'set-key-partition-list',
        '-S',
        'apple-tool:,apple:,codesign:',
        '-s',
        '-k',
        keychainPassword,
        'build.keychain',
      ],
      ['mkdir', '-p', profilesExtractDir, profilesDestination],
      [
        'sh',
        '-c',
        'printf %s "\$IOS_PROVISIONING_PROFILES_BASE64" | base64 --decode > ${_shellPath(profilesArchivePath)}',
      ],
      ['tar', '-xzf', profilesArchivePath, '-C', profilesExtractDir],
      [
        'find',
        profilesExtractDir,
        '-name',
        '*.mobileprovision',
        '-exec',
        'cp',
        '{}',
        profilesDestination,
        ';',
      ],
    ],
  );
}

String _shellPath(String path) {
  return "'${path.replaceAll("'", "'\\''")}'";
}

List<String> appStoreConnectPublishCommand(
  AppStoreConnectPublishConfig config, {
  required String ipaPath,
  required String apiKeyPath,
}) {
  return [
    ..._commandParts(config.fastlaneExecutable),
    'deliver',
    '--ipa',
    ipaPath,
    '--api_key_path',
    apiKeyPath,
    '--skip_metadata',
    config.skipMetadata.toString(),
    '--skip_screenshots',
    config.skipScreenshots.toString(),
    '--submit_for_review',
    config.submitForReview.toString(),
  ];
}

Map<String, Object?> appStoreConnectApiKeyJson(
  AppStoreConnectApiKeyConfig config,
  Map<String, String> environment,
) {
  final keyId = _requiredEnvironment(environment, config.keyIdEnv);
  final issuerId = _requiredEnvironment(environment, config.issuerIdEnv);
  final privateKey = _requiredEnvironment(
    environment,
    config.privateKeyEnv,
  ).replaceAll(r'\n', '\n');

  return {'key_id': keyId, 'issuer_id': issuerId, 'key': privateKey};
}

Future<void> _writeAppStoreConnectApiKey(
  File output,
  AppStoreConnectApiKeyConfig config,
  Map<String, String> environment,
) async {
  await output.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await output.writeAsString(
    '${encoder.convert(appStoreConnectApiKeyJson(config, environment))}\n',
  );
}

String _requiredEnvironment(Map<String, String> environment, String name) {
  final value = environment[name];
  if (value == null || value.isEmpty) {
    throw FlutterReleaseException(
      'App Store Connect publish requires missing environment variable: $name.',
    );
  }
  return value;
}

Future<String> _resolveSingleIpa(Directory packageRoot, String pattern) async {
  final matches = await Glob(pattern)
      .list(root: packageRoot.path)
      .where((entity) => entity is File)
      .map((entity) => entity.path)
      .toList();
  if (matches.length != 1) {
    throw FlutterReleaseException(
      'Expected exactly one IPA matching "$pattern" in ${packageRoot.path}, '
      'found ${matches.length}.',
    );
  }
  return matches.single;
}

List<String> flutterReleaseArtifactPaths(
  FlutterReleaseConfig config,
  String targetName,
) {
  final packagePath = config.packagePath;
  final target = config.target(targetName);
  return switch (target.platform) {
    FlutterReleasePlatform.android => [
      if (target.androidArtifact == AndroidArtifact.apk)
        '$packagePath/build/app/outputs/flutter-apk/*.apk'
      else
        '$packagePath/build/app/outputs/bundle/release/*.aab',
    ],
    FlutterReleasePlatform.ios => ['$packagePath/build/ios/ipa/*.ipa'],
    FlutterReleasePlatform.linux => [
      '$packagePath/build/linux/x64/release/bundle/**',
    ],
    FlutterReleasePlatform.macos => [
      '$packagePath/build/macos/Build/Products/Release/*.app',
    ],
    FlutterReleasePlatform.web => ['$packagePath/build/web/**'],
    FlutterReleasePlatform.windows => [
      '$packagePath/build/windows/x64/runner/Release/**',
    ],
  };
}

List<String> _buildCommand(
  FlutterReleaseConfig config,
  FlutterTargetConfig target,
) {
  final platform = target.platform;
  final command = <String>[
    ..._flutterCommand(config),
    'build',
    _flutterBuildTarget(target),
    '--${config.buildMode.name}',
  ];

  if (platform == FlutterReleasePlatform.ios && !target.signing.enabled) {
    command.add('--no-codesign');
  }
  if (target.flavor case final flavor?) {
    command.addAll(['--flavor', flavor]);
  }
  if (target.target case final buildTarget?) {
    command.addAll(['--target', buildTarget]);
  }
  if (target.buildName case final buildName?) {
    command.addAll(['--build-name', buildName]);
  }
  if (target.buildNumber case final buildNumber?) {
    command.addAll(['--build-number', buildNumber]);
  }
  for (final path in config.dartDefineFromFiles) {
    command.addAll(['--dart-define-from-file', path]);
  }
  for (final path in target.dartDefineFromFiles) {
    command.addAll(['--dart-define-from-file', path]);
  }
  for (final entry in target.dartDefines.entries) {
    command.add('--dart-define=${entry.key}=${entry.value}');
  }
  command.addAll(target.buildArgs);
  return command;
}

String _flutterBuildTarget(FlutterTargetConfig config) {
  return switch (config.platform) {
    FlutterReleasePlatform.android =>
      config.androidArtifact == AndroidArtifact.apk ? 'apk' : 'appbundle',
    FlutterReleasePlatform.ios => 'ipa',
    FlutterReleasePlatform.linux => 'linux',
    FlutterReleasePlatform.macos => 'macos',
    FlutterReleasePlatform.web => 'web',
    FlutterReleasePlatform.windows => 'windows',
  };
}

void _validateSigningEnvironment(FlutterTargetConfig target) {
  if (!target.signing.enabled) {
    return;
  }
  final missing = [
    for (final name in target.signing.requiredEnv)
      if ((Platform.environment[name] ?? '').isEmpty) name,
  ];
  if (missing.isEmpty) {
    return;
  }
  throw FlutterReleaseException(
    'Signing for target "${target.name}" requires missing environment variables: '
    '${missing.join(', ')}.',
  );
}

List<String> _flutterCommand(FlutterReleaseConfig config) {
  return _commandParts(config.flutterExecutable);
}

List<String> _commandParts(String command) {
  return command
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

enum AndroidArtifact { appbundle, apk }

extension FlutterTargetConfigArtifact on FlutterTargetConfig {
  AndroidArtifact get androidArtifact {
    final value = artifact ?? 'appbundle';
    return switch (value) {
      'appbundle' || 'aab' => AndroidArtifact.appbundle,
      'apk' => AndroidArtifact.apk,
      _ => throw FlutterReleaseException(
        'targets.$name.artifact must be one of appbundle, aab, apk.',
      ),
    };
  }
}
