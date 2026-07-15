import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

final class FlutterReleaseException implements Exception {
  const FlutterReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class FlutterReleaseConfig {
  const FlutterReleaseConfig({
    required this.packagePath,
    required this.targets,
    this.variables = const {},
    this.flutterExecutable = 'flutter',
    this.buildMode = FlutterBuildMode.release,
    this.pubGet = true,
    this.dartDefineFromFiles = const [],
  });

  final String packagePath;
  final String flutterExecutable;
  final FlutterBuildMode buildMode;
  final bool pubGet;
  final Map<String, String> variables;
  final List<String> dartDefineFromFiles;
  final Map<String, FlutterTargetConfig> targets;

  static Future<FlutterReleaseConfig> load(Directory projectRoot) async {
    final file = File('${projectRoot.path}/flutter_release.yaml');
    if (!await file.exists()) {
      throw const FlutterReleaseException('flutter_release.yaml not found.');
    }
    return parse(await file.readAsString());
  }

  static FlutterReleaseConfig parse(String source) {
    final document = loadYaml(source);
    final root = _map(document, 'flutter_release.yaml');
    final variables = _stringMap(root['variables'], 'variables');
    final targetsYaml = _map(root['targets'], 'targets');
    final targets = <String, FlutterTargetConfig>{};
    for (final entry in targetsYaml.entries) {
      final name = _key(entry.key, 'targets');
      final value = _map(entry.value, 'targets.$name');
      targets[name] = FlutterTargetConfig.parse(
        name,
        value,
        variables: variables,
      );
    }
    if (targets.isEmpty) {
      throw const FlutterReleaseException(
        'targets must contain at least one target.',
      );
    }
    return FlutterReleaseConfig(
      packagePath: _requiredString(root['package'], 'package'),
      flutterExecutable: _string(root['flutter'], 'flutter') ?? 'flutter',
      buildMode: FlutterBuildMode.byName(
        _string(root['build_mode'], 'build_mode') ?? 'release',
        'build_mode',
      ),
      pubGet: _bool(root['pub_get'], 'pub_get') ?? true,
      variables: variables,
      dartDefineFromFiles: _stringOrStringList(
        root['dart_define_from_file'],
        'dart_define_from_file',
      ),
      targets: targets,
    );
  }

  FlutterTargetConfig target(String name) {
    final config = targets[name];
    if (config == null) {
      throw FlutterReleaseException('Target "$name" is not configured.');
    }
    return config;
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert({
      'package': packagePath,
      'flutter': flutterExecutable,
      'build_mode': buildMode.name,
      'pub_get': pubGet,
      if (variables.isNotEmpty) 'variables': variables,
      if (dartDefineFromFiles.isNotEmpty) 'dart_define_from_file': dartDefineFromFiles,
      'targets': {for (final entry in targets.entries) entry.key: entry.value.toJson()},
    })}\n';
  }
}

final class FlutterTargetConfig {
  const FlutterTargetConfig({
    required this.name,
    required this.platform,
    required this.signing,
    this.enabled = true,
    this.artifact,
    this.flavor,
    this.target,
    this.buildName,
    this.buildNumber,
    this.dartDefines = const {},
    this.dartDefineFromFiles = const [],
    this.buildArgs = const [],
    this.publish = const FlutterPublishConfig(),
  });

  final String name;
  final FlutterReleasePlatform platform;
  final bool enabled;
  final FlutterSigningConfig signing;
  final String? artifact;
  final String? flavor;
  final String? target;
  final String? buildName;
  final String? buildNumber;
  final Map<String, String> dartDefines;
  final List<String> dartDefineFromFiles;
  final List<String> buildArgs;
  final FlutterPublishConfig publish;

  static FlutterTargetConfig parse(
    String name,
    YamlMap map, {
    Map<String, String> variables = const {},
  }) {
    final platform = FlutterReleasePlatform.byName(
      _requiredString(map['platform'], 'targets.$name.platform'),
      'targets.$name.platform',
    );
    return FlutterTargetConfig(
      name: name,
      platform: platform,
      enabled: _bool(map['enabled'], 'targets.$name.enabled') ?? true,
      artifact: _string(map['artifact'], 'targets.$name.artifact'),
      flavor: _string(map['flavor'], 'targets.$name.flavor'),
      target: _string(map['target'], 'targets.$name.target'),
      buildName: _stringScalar(map['build_name'], 'targets.$name.build_name'),
      buildNumber: _stringScalar(
        map['build_number'],
        'targets.$name.build_number',
      ),
      dartDefines: _stringMap(map['dart_defines'], 'targets.$name.dart_defines')
          .map(
            (key, value) => MapEntry(
              key,
              _resolveVariables(
                value,
                variables,
                'targets.$name.dart_defines.$key',
              ),
            ),
          ),
      dartDefineFromFiles: _stringOrStringList(
        map['dart_define_from_file'],
        'targets.$name.dart_define_from_file',
      ),
      buildArgs: _stringList(map['build_args'], 'targets.$name.build_args'),
      publish: FlutterPublishConfig.parse(
        map['publish'],
        'targets.$name.publish',
      ),
      signing: FlutterSigningConfig.parse(
        map['signing'],
        'targets.$name.signing',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'platform': platform.name,
    'enabled': enabled,
    if (artifact != null) 'artifact': artifact,
    if (flavor != null) 'flavor': flavor,
    if (target != null) 'target': target,
    if (buildName != null) 'build_name': buildName,
    if (buildNumber != null) 'build_number': buildNumber,
    if (dartDefines.isNotEmpty) 'dart_defines': dartDefines,
    if (dartDefineFromFiles.isNotEmpty)
      'dart_define_from_file': dartDefineFromFiles,
    if (buildArgs.isNotEmpty) 'build_args': buildArgs,
    if (!publish.isEmpty) 'publish': publish.toJson(),
    'signing': signing.toJson(),
  };
}

final class FlutterPublishConfig {
  const FlutterPublishConfig({this.appStoreConnect});

  final AppStoreConnectPublishConfig? appStoreConnect;

  bool get isEmpty => appStoreConnect == null;

  static FlutterPublishConfig parse(Object? value, String path) {
    if (value == null) {
      return const FlutterPublishConfig();
    }
    final map = _map(value, path);
    return FlutterPublishConfig(
      appStoreConnect: AppStoreConnectPublishConfig.parse(
        map['app_store_connect'],
        '$path.app_store_connect',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    if (appStoreConnect != null) 'app_store_connect': appStoreConnect!.toJson(),
  };
}

final class AppStoreConnectPublishConfig {
  const AppStoreConnectPublishConfig({
    required this.apiKey,
    this.ipa = 'build/ios/ipa/*.ipa',
    this.fastlaneExecutable = 'fastlane',
    this.submitForReview = false,
    this.skipMetadata = true,
    this.skipScreenshots = true,
    this.runPrecheckBeforeSubmit = true,
    this.precheckIncludeInAppPurchases = false,
  });

  final String ipa;
  final String fastlaneExecutable;
  final bool submitForReview;
  final bool skipMetadata;
  final bool skipScreenshots;
  final bool runPrecheckBeforeSubmit;
  final bool precheckIncludeInAppPurchases;
  final AppStoreConnectApiKeyConfig apiKey;

  static AppStoreConnectPublishConfig? parse(Object? value, String path) {
    if (value == null) {
      return null;
    }
    final map = _map(value, path);
    return AppStoreConnectPublishConfig(
      ipa: _string(map['ipa'], '$path.ipa') ?? 'build/ios/ipa/*.ipa',
      fastlaneExecutable:
          _string(map['fastlane'], '$path.fastlane') ?? 'fastlane',
      submitForReview:
          _bool(map['submit_for_review'], '$path.submit_for_review') ?? false,
      skipMetadata: _bool(map['skip_metadata'], '$path.skip_metadata') ?? true,
      skipScreenshots:
          _bool(map['skip_screenshots'], '$path.skip_screenshots') ?? true,
      runPrecheckBeforeSubmit:
          _bool(
            map['run_precheck_before_submit'],
            '$path.run_precheck_before_submit',
          ) ??
          true,
      precheckIncludeInAppPurchases:
          _bool(
            map['precheck_include_in_app_purchases'],
            '$path.precheck_include_in_app_purchases',
          ) ??
          false,
      apiKey: AppStoreConnectApiKeyConfig.parse(
        map['api_key'],
        '$path.api_key',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'ipa': ipa,
    'fastlane': fastlaneExecutable,
    'submit_for_review': submitForReview,
    'skip_metadata': skipMetadata,
    'skip_screenshots': skipScreenshots,
    'run_precheck_before_submit': runPrecheckBeforeSubmit,
    'precheck_include_in_app_purchases': precheckIncludeInAppPurchases,
    'api_key': apiKey.toJson(),
  };
}

final class AppStoreConnectApiKeyConfig {
  const AppStoreConnectApiKeyConfig({
    this.keyIdEnv = 'APP_STORE_CONNECT_KEY_ID',
    this.issuerIdEnv = 'APP_STORE_CONNECT_ISSUER_ID',
    this.privateKeyEnv = 'APP_STORE_CONNECT_PRIVATE_KEY',
  });

  final String keyIdEnv;
  final String issuerIdEnv;
  final String privateKeyEnv;

  static AppStoreConnectApiKeyConfig parse(Object? value, String path) {
    if (value == null) {
      return const AppStoreConnectApiKeyConfig();
    }
    final map = _map(value, path);
    return AppStoreConnectApiKeyConfig(
      keyIdEnv:
          _string(map['key_id_env'], '$path.key_id_env') ??
          'APP_STORE_CONNECT_KEY_ID',
      issuerIdEnv:
          _string(map['issuer_id_env'], '$path.issuer_id_env') ??
          'APP_STORE_CONNECT_ISSUER_ID',
      privateKeyEnv:
          _string(map['private_key_env'], '$path.private_key_env') ??
          'APP_STORE_CONNECT_PRIVATE_KEY',
    );
  }

  Map<String, Object?> toJson() => {
    'key_id_env': keyIdEnv,
    'issuer_id_env': issuerIdEnv,
    'private_key_env': privateKeyEnv,
  };
}

final class FlutterSigningConfig {
  const FlutterSigningConfig({
    this.enabled = false,
    this.requiredEnv = const [],
  });

  final bool enabled;
  final List<String> requiredEnv;

  static FlutterSigningConfig parse(Object? value, String path) {
    if (value == null) {
      return const FlutterSigningConfig();
    }
    if (value is bool) {
      return FlutterSigningConfig(enabled: value);
    }
    final map = _map(value, path);
    return FlutterSigningConfig(
      enabled: _bool(map['enabled'], '$path.enabled') ?? true,
      requiredEnv: _stringList(map['required_env'], '$path.required_env'),
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    if (requiredEnv.isNotEmpty) 'required_env': requiredEnv,
  };
}

enum FlutterReleasePlatform {
  android('android'),
  ios('ios'),
  linux('linux'),
  macos('macos'),
  web('web'),
  windows('windows');

  const FlutterReleasePlatform(this.name);

  final String name;

  static FlutterReleasePlatform byName(String value, String path) {
    for (final platform in values) {
      if (platform.name == value) {
        return platform;
      }
    }
    throw FlutterReleaseException(
      '$path must be one of ${values.map((platform) => platform.name).join(', ')}.',
    );
  }
}

enum FlutterBuildMode {
  debug('debug'),
  profile('profile'),
  release('release');

  const FlutterBuildMode(this.name);

  final String name;

  static FlutterBuildMode byName(String value, String path) {
    for (final mode in values) {
      if (mode.name == value) {
        return mode;
      }
    }
    throw FlutterReleaseException(
      '$path must be one of ${values.map((mode) => mode.name).join(', ')}.',
    );
  }
}

YamlMap _map(Object? value, String path) {
  if (value is YamlMap) {
    return value;
  }
  throw FlutterReleaseException('$path must be a YAML map.');
}

String _key(Object? value, String path) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FlutterReleaseException('$path contains a non-string key.');
}

String _requiredString(Object? value, String path) {
  final result = _string(value, path);
  if (result == null || result.isEmpty) {
    throw FlutterReleaseException('$path is required.');
  }
  return result;
}

String? _string(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FlutterReleaseException('$path must be a string.');
}

String? _stringScalar(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is String || value is num) {
    return value.toString();
  }
  throw FlutterReleaseException('$path must be a string or number.');
}

bool? _bool(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw FlutterReleaseException('$path must be a boolean.');
}

List<String> _stringList(Object? value, String path) {
  if (value == null) {
    return const [];
  }
  if (value is! YamlList) {
    throw FlutterReleaseException('$path must be a YAML list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _requiredString(value[index], '$path[$index]'),
  ];
}

List<String> _stringOrStringList(Object? value, String path) {
  if (value == null) {
    return const [];
  }
  if (value is String) {
    return [value];
  }
  return _stringList(value, path);
}

Map<String, String> _stringMap(Object? value, String path) {
  if (value == null) {
    return const {};
  }
  final map = _map(value, path);
  return {
    for (final entry in map.entries)
      _key(entry.key, path): _requiredString(entry.value, '$path.${entry.key}'),
  };
}

String _resolveVariables(
  String value,
  Map<String, String> variables,
  String path,
) {
  return value.replaceAllMapped(RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}'), (
    match,
  ) {
    final name = match.group(1)!;
    final variable = variables[name];
    if (variable == null) {
      throw FlutterReleaseException(
        '$path references undefined variable "$name".',
      );
    }
    return variable;
  });
}
