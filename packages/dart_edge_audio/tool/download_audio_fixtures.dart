import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_edge_audio/dart_edge_audio_testing.dart';

Future<void> main(List<String> args) async {
  final cachePath =
      _optionValue(args, '--fixtures-dir') ??
      _resolveRepoRelativePath(defaultAudioFixtureCachePath);
  final cacheDir = Directory(cachePath);
  await cacheDir.create(recursive: true);

  for (final fixture in audioFixtureManifest) {
    final file = File(fixture.pathIn(cacheDir.path));
    if (await file.exists()) {
      final digest = await _sha256(file);
      if (digest == fixture.sha256) {
        stdout.writeln('ok ${fixture.fileName}');
        continue;
      }
      stderr.writeln(
        'replacing ${fixture.fileName}: expected ${fixture.sha256}, got $digest',
      );
      await file.delete();
    }

    stdout.writeln('download ${fixture.fileName}');
    await _download(fixture.url, file);
    final digest = await _sha256(file);
    if (digest != fixture.sha256) {
      await file.delete();
      throw StateError(
        'SHA-256 mismatch for ${fixture.fileName}: '
        'expected ${fixture.sha256}, got $digest.',
      );
    }
  }

  stdout.writeln('audio fixtures ready in ${cacheDir.path}');
}

Future<void> _download(String url, File output) async {
  try {
    await _downloadWithHttpClient(url, output);
  } on HttpException {
    await _downloadWithCurl(url, output);
  }
}

Future<void> _downloadWithHttpClient(String url, File output) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (compatible; dart_edge_audio_fixture_downloader/1.0)',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'audio/*,*/*;q=0.8');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $url: HTTP ${response.statusCode}.',
        uri: Uri.parse(url),
      );
    }

    await response.pipe(output.openWrite());
  } finally {
    client.close(force: true);
  }
}

Future<void> _downloadWithCurl(String url, File output) async {
  final result = await Process.run('curl', [
    '--location',
    '--fail',
    '--silent',
    '--show-error',
    url,
    '--output',
    output.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to download $url with curl: ${result.stderr}'.trim(),
    );
  }
}

Future<String> _sha256(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

String _resolveRepoRelativePath(String repoRelativePath) {
  var directory = Directory.current;
  while (true) {
    final candidate = File('${directory.path}/pubspec.yaml');
    final audioPackage = Directory(
      '${directory.path}/packages/dart_edge_audio',
    );
    if (candidate.existsSync() && audioPackage.existsSync()) {
      return '${directory.path}/$repoRelativePath';
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      return repoRelativePath;
    }
    directory = parent;
  }
}

String? _optionValue(List<String> args, String name) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == name && index + 1 < args.length) {
      return args[index + 1];
    }
    if (arg.startsWith('$name=')) {
      return arg.substring(name.length + 1);
    }
  }
  return null;
}
