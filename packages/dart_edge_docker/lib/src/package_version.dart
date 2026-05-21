import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

final class PackageVersionException implements Exception {
  const PackageVersionException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class PackageVersionOutput {
  const PackageVersionOutput({required this.version});

  factory PackageVersionOutput.fromPubspecVersion(String version) {
    return PackageVersionOutput(version: version);
  }

  final String version;

  String get versionTag =>
      'v${version.startsWith('v') ? version.substring(1) : version}'.replaceAll(
        '+',
        '-',
      );

  Map<String, String> toMap() => {
    'version': version,
    'version_tag': versionTag,
  };

  String toJson() => '${const JsonEncoder.withIndent('  ').convert(toMap())}\n';

  String toEnv() =>
      '${toMap().entries.map((entry) => '${entry.key}=${entry.value}').join('\n')}\n';

  static Future<PackageVersionOutput> read(Directory packageRoot) async {
    final pubspecFile = File('${packageRoot.path}/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw PackageVersionException(
        'pubspec.yaml not found: ${pubspecFile.path}',
      );
    }
    final pubspec = loadYaml(await pubspecFile.readAsString());
    if (pubspec is! YamlMap) {
      throw PackageVersionException('${pubspecFile.path} must be a YAML map.');
    }
    final value = pubspec['version'];
    if (value is! String || value.trim().isEmpty) {
      throw PackageVersionException(
        'Could not read version from ${pubspecFile.path}.',
      );
    }
    return PackageVersionOutput(version: value.trim());
  }

  static PackageVersionOutput readSync(Directory packageRoot) {
    final pubspecFile = File('${packageRoot.path}/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw PackageVersionException(
        'pubspec.yaml not found: ${pubspecFile.path}',
      );
    }
    final pubspec = loadYaml(pubspecFile.readAsStringSync());
    if (pubspec is! YamlMap) {
      throw PackageVersionException('${pubspecFile.path} must be a YAML map.');
    }
    final value = pubspec['version'];
    if (value is! String || value.trim().isEmpty) {
      throw PackageVersionException(
        'Could not read version from ${pubspecFile.path}.',
      );
    }
    return PackageVersionOutput(version: value.trim());
  }
}
