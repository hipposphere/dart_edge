import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

/// Builds a Dart Edge Rust native asset from a prebuilt release artifact when
/// one is available, falling back to [RustBuilder] for unsupported targets.
final class DartEdgePrebuiltRustBuilder {
  const DartEdgePrebuiltRustBuilder({
    required this.assetName,
    this.cratePath = 'rust',
    this.buildMode = BuildMode.release,
    this.enableDefaultFeatures = true,
    this.features = const <String>[],
    this.extraCargoBuildArgs = const <String>[],
    this.extraCargoEnvironmentVariables = const <String, String>{},
    this.releaseOwner = 'hipposphere',
    this.releaseRepository = 'dart_edge',
  });

  final String assetName;
  final String cratePath;
  final BuildMode buildMode;
  final bool enableDefaultFeatures;
  final List<String> features;
  final List<String> extraCargoBuildArgs;
  final Map<String, String> extraCargoEnvironmentVariables;
  final String releaseOwner;
  final String releaseRepository;

  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
  }) async {
    if (await _tryUsePrebuilt(input: input, output: output)) {
      return;
    }

    await RustBuilder(
      assetName: assetName,
      cratePath: cratePath,
      buildMode: buildMode,
      enableDefaultFeatures: enableDefaultFeatures,
      features: features,
      extraCargoBuildArgs: extraCargoBuildArgs,
      extraCargoEnvironmentVariables: extraCargoEnvironmentVariables,
    ).run(input: input, output: output);
  }

  Future<bool> _tryUsePrebuilt({
    required BuildInput input,
    required BuildOutputBuilder output,
  }) async {
    if (Platform.environment['DART_EDGE_BUILD_RUST_FROM_SOURCE'] == '1') {
      return false;
    }

    final codeConfig = input.config.code;
    final targetOS = codeConfig.targetOS;
    if (targetOS != OS.linux && targetOS != OS.macOS) {
      return false;
    }

    final targetArchitecture = codeConfig.targetArchitecture;
    if (!_hasPrebuiltTarget(targetOS, targetArchitecture)) {
      return false;
    }

    final packageRoot = Directory.fromUri(input.packageRoot);
    final nativeVersion = await _readCargoPackageVersion(packageRoot);
    final packageName = input.packageName;
    if (!_hasPrebuiltPackage(packageName)) {
      return false;
    }

    final linkMode = _linkMode(codeConfig);
    if (linkMode is! DynamicLoadingBundled) {
      return false;
    }

    final artifactName = _artifactName(
      packageName: packageName,
      nativeVersion: nativeVersion,
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      linkMode: linkMode,
    );

    final cacheDirectory = Directory(
      _cacheDirectoryPath(packageName, nativeVersion),
    );
    final cachedArtifact = File('${cacheDirectory.path}/$artifactName');
    final cachedChecksum = File('${cacheDirectory.path}/$artifactName.sha256');

    if (!await cachedArtifact.exists() || !await cachedChecksum.exists()) {
      final downloaded = await _downloadPrebuilt(
        artifactName: artifactName,
        packageName: packageName,
        nativeVersion: nativeVersion,
        cachedArtifact: cachedArtifact,
        cachedChecksum: cachedChecksum,
      );
      if (!downloaded) {
        return false;
      }
    }

    if (!await _verifyChecksum(cachedArtifact, cachedChecksum)) {
      await _deleteIfExists(cachedArtifact);
      await _deleteIfExists(cachedChecksum);
      return false;
    }

    final outputDirectory = Directory.fromUri(input.outputDirectory);
    await outputDirectory.create(recursive: true);
    final outputFile = File('${outputDirectory.path}/$artifactName');
    await cachedArtifact.copy(outputFile.path);

    output.dependencies.addAll([
      packageRoot.uri.resolve('$cratePath/Cargo.toml'),
      cachedArtifact.uri,
      cachedChecksum.uri,
    ]);
    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: assetName,
        linkMode: linkMode,
        file: outputFile.uri,
      ),
    );
    return true;
  }

  Future<bool> _downloadPrebuilt({
    required String artifactName,
    required String packageName,
    required String nativeVersion,
    required File cachedArtifact,
    required File cachedChecksum,
  }) async {
    final baseUrl = _baseUrl(packageName, nativeVersion);
    final artifactUri = Uri.parse('$baseUrl/$artifactName');
    final checksumUri = Uri.parse('$baseUrl/$artifactName.sha256');

    final tempDirectory = Directory('${cachedArtifact.parent.path}.tmp');
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
    await tempDirectory.create(recursive: true);

    final tempArtifact = File('${tempDirectory.path}/$artifactName');
    final tempChecksum = File('${tempDirectory.path}/$artifactName.sha256');

    final artifactDownloaded = await _downloadFile(artifactUri, tempArtifact);
    final checksumDownloaded = await _downloadFile(checksumUri, tempChecksum);
    if (!artifactDownloaded || !checksumDownloaded) {
      await _deleteIfExists(tempDirectory, recursive: true);
      return false;
    }

    if (!await _verifyChecksum(tempArtifact, tempChecksum)) {
      await _deleteIfExists(tempDirectory, recursive: true);
      return false;
    }

    await cachedArtifact.parent.create(recursive: true);
    await tempArtifact.rename(cachedArtifact.path);
    await tempChecksum.rename(cachedChecksum.path);
    await _deleteIfExists(tempDirectory, recursive: true);
    return true;
  }

  Future<bool> _downloadFile(Uri uri, File destination) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }

      final sink = destination.openWrite();
      await response.pipe(sink);
      return true;
    } on IOException {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _verifyChecksum(File artifact, File checksumFile) async {
    final expected = (await checksumFile.readAsString())
        .trim()
        .split(' ')
        .first;
    final actual = await _sha256(artifact);
    return expected == actual;
  }

  Future<String> _sha256(File file) async {
    return (await sha256.bind(file.openRead()).first).toString();
  }

  Future<void> _deleteIfExists(
    FileSystemEntity entity, {
    bool recursive = false,
  }) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: recursive);
      }
    } on IOException {
      // Failed cache cleanup should not prevent falling back to a source build.
    }
  }

  Future<String> _readCargoPackageVersion(Directory packageRoot) async {
    final cargoManifest = await File(
      '${packageRoot.path}/$cratePath/Cargo.toml',
    ).readAsString();
    final match = RegExp(
      r'''^version\s*=\s*["']([^"']+)["']\s*$''',
      multiLine: true,
    ).firstMatch(cargoManifest);
    if (match == null) {
      throw StateError('Rust Cargo.toml does not declare a package version.');
    }
    return match.group(1)!.replaceAll('"', '').replaceAll("'", '');
  }

  String _artifactName({
    required String packageName,
    required String nativeVersion,
    required OS targetOS,
    required Architecture targetArchitecture,
    required LinkMode linkMode,
  }) {
    final libraryName = targetOS
        .libraryFileName(packageName, linkMode)
        .replaceAll('-', '_');
    return '$packageName-$nativeVersion-${targetOS.name}-'
        '${targetArchitecture.name}-$libraryName';
  }

  LinkMode _linkMode(CodeConfig codeConfig) {
    return switch (codeConfig.linkModePreference) {
      LinkModePreference.dynamic ||
      LinkModePreference.preferDynamic => DynamicLoadingBundled(),
      LinkModePreference.static ||
      LinkModePreference.preferStatic => StaticLinking(),
      _ => throw UnsupportedError(
        'Unsupported LinkModePreference: ${codeConfig.linkModePreference}',
      ),
    };
  }

  bool _hasPrebuiltTarget(OS targetOS, Architecture targetArchitecture) {
    return switch ((targetOS, targetArchitecture)) {
      (OS.linux, Architecture.x64) => true,
      (OS.macOS, Architecture.arm64) => true,
      _ => false,
    };
  }

  bool _hasPrebuiltPackage(String packageName) {
    return switch (packageName) {
      'dart_edge_sip' => false,
      _ => true,
    };
  }

  String _baseUrl(String packageName, String nativeVersion) {
    final override = Platform.environment['DART_EDGE_PREBUILT_BASE_URL'];
    if (override != null && override.isNotEmpty) {
      return override.replaceFirst(RegExp(r'/$'), '');
    }

    final tag = '$packageName-native-v$nativeVersion';
    return 'https://github.com/$releaseOwner/$releaseRepository/releases/'
        'download/$tag';
  }

  String _cacheDirectoryPath(String packageName, String nativeVersion) {
    final override = Platform.environment['DART_EDGE_NATIVE_CACHE'];
    final root = override != null && override.isNotEmpty
        ? override
        : _defaultCacheRoot();
    return '$root/$packageName/$nativeVersion';
  }

  String _defaultCacheRoot() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/.cache/dart_edge/native_assets';
    }
    return Directory.systemTemp.createTempSync('dart_edge_native_assets').path;
  }
}
