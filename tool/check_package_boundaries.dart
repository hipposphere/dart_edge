import 'dart:io';

void main() {
  final root = Directory.current;
  final packages = _workspacePackages(root);
  final workspacePackageNames = packages.values.toSet();
  final violations = <String>[];

  for (final package in packages.entries) {
    final packageName = package.value;
    final pubspec = File('${package.key.path}/pubspec.yaml');
    final pubspecText = pubspec.readAsStringSync();

    if (packageName == 'dart_edge_core') {
      for (final forbidden in const [
        'dart_edge_http_server_runtime',
        'dart_edge_http_server',
      ]) {
        if (_declaresDependency(pubspecText, forbidden)) {
          violations.add(
            '${pubspec.path}: dart_edge_core must not depend on $forbidden.',
          );
        }
      }
    }

    if (packageName == 'dart_edge_http_server_runtime' &&
        _declaresDependency(pubspecText, 'dart_edge_http_server')) {
      violations.add(
        '${pubspec.path}: runtime must not depend on the app-facing HTTP package.',
      );
    }
  }

  for (final file in _dartFiles(root)) {
    final currentPackage = _owningPackage(file, packages);
    final lines = file.readAsLinesSync();

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final privateImport = RegExp(
        r'''^\s*(?:import|export)\s+['"]package:([^/]+)/src/''',
      ).firstMatch(line);
      if (privateImport == null) {
        continue;
      }

      final importedPackage = privateImport.group(1)!;
      if (!workspacePackageNames.contains(importedPackage) ||
          importedPackage == currentPackage) {
        continue;
      }

      violations.add(
        '${file.path}:${index + 1}: imports private src API from '
        '$importedPackage.',
      );
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Package boundary check passed.');
    return;
  }

  stderr.writeln('Package boundary check failed:');
  for (final violation in violations) {
    stderr.writeln('- $violation');
  }
  exitCode = 1;
}

Map<Directory, String> _workspacePackages(Directory root) {
  final packagesDir = Directory('${root.path}/packages');
  final packages = <Directory, String>{};

  for (final entity in packagesDir.listSync()) {
    if (entity is! Directory) {
      continue;
    }

    final pubspec = File('${entity.path}/pubspec.yaml');
    if (!pubspec.existsSync()) {
      continue;
    }

    final name = RegExp(
      r'^name:\s*([A-Za-z0-9_]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
    if (name != null) {
      packages[entity.absolute] = name;
    }
  }

  return packages;
}

Iterable<File> _dartFiles(Directory root) sync* {
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    final parts = entity.uri.pathSegments;
    if (parts.contains('.dart_tool') ||
        parts.contains('build') ||
        parts.contains('.pub-cache')) {
      continue;
    }

    yield entity;
  }
}

String? _owningPackage(File file, Map<Directory, String> packages) {
  final filePath = file.absolute.path;

  for (final package in packages.entries) {
    final packagePath = package.key.path;
    if (filePath == packagePath || filePath.startsWith('$packagePath/')) {
      return package.value;
    }
  }

  return null;
}

bool _declaresDependency(String pubspec, String packageName) {
  final dependencyPattern = RegExp('^  $packageName:', multiLine: true);
  return dependencyPattern.hasMatch(pubspec);
}
