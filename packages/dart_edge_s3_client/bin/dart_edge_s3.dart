import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';

Future<void> main(List<String> arguments) async {
  final logger = Logger.standard();
  final runner = CommandRunner<int>(
    'dart_edge_s3',
    'Command-line tools for dart_edge_s3_client.',
  )..addCommand(_UploadCommand(logger));

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    io.exitCode = exitCode;
  } on UsageException catch (error) {
    logger.stderr(error.message);
    logger.stderr('');
    logger.stderr(error.usage);
    io.exitCode = 64;
  } on Object catch (error) {
    logger.stderr(logger.ansi.error('Upload failed: $error'));
    io.exitCode = 1;
  }
}

final class _UploadCommand extends Command<int> {
  _UploadCommand(this._logger) {
    argParser
      ..addOption(
        'endpoint',
        help: 'S3-compatible endpoint URL, for example http://127.0.0.1:9000.',
        mandatory: true,
      )
      ..addOption('bucket', help: 'Destination bucket.', mandatory: true)
      ..addOption('key', help: 'Destination object key.', mandatory: true)
      ..addOption(
        'file-uri',
        help: 'Local file URI to upload, for example file:///tmp/photo.jpg.',
        mandatory: true,
      )
      ..addOption(
        'region',
        help:
            'AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION, then the client default.',
      )
      ..addOption(
        'access-key-id',
        help: 'Access key ID. Defaults to AWS_ACCESS_KEY_ID.',
      )
      ..addOption(
        'secret-access-key',
        help: 'Secret access key. Defaults to AWS_SECRET_ACCESS_KEY.',
      )
      ..addOption(
        'session-token',
        help: 'Session token. Defaults to AWS_SESSION_TOKEN.',
      )
      ..addOption('content-type', help: 'Object content type.')
      ..addFlag('force-path-style', help: 'Use path-style bucket addressing.')
      ..addFlag('allow-http', help: 'Allow plain HTTP endpoints.');
  }

  final Logger _logger;

  @override
  String get description => 'Upload a local file to S3.';

  @override
  String get name => 'upload';

  @override
  Future<int> run() async {
    final results = argResults!;
    final file = _fileFromUri(_stringOption('file-uri'));
    if (!file.existsSync()) {
      usageException('File does not exist: ${file.uri}');
    }

    final client = await DartEdgeS3Client.open(
      S3ClientConfig(
        endpoint: _endpoint,
        region:
            _optionalStringOption('region') ??
            _optionalEnvironmentValue('AWS_REGION') ??
            _optionalEnvironmentValue('AWS_DEFAULT_REGION'),
        accessKeyId:
            _optionalStringOption('access-key-id') ??
            _optionalEnvironmentValue('AWS_ACCESS_KEY_ID'),
        secretAccessKey:
            _optionalStringOption('secret-access-key') ??
            _optionalEnvironmentValue('AWS_SECRET_ACCESS_KEY'),
        sessionToken:
            _optionalStringOption('session-token') ??
            _optionalEnvironmentValue('AWS_SESSION_TOKEN'),
        forcePathStyle: results.flag('force-path-style'),
        allowHttp: results.flag('allow-http'),
      ),
    );

    try {
      final bucket = _stringOption('bucket');
      final key = _stringOption('key');
      final progress = _logger.progress(
        'Uploading ${file.uri} to s3://$bucket/$key',
      );
      final result = await client.putObjectFile(
        S3PutObjectFileRequest(
          bucket: bucket,
          key: key,
          inputPath: file.path,
          contentType: _optionalStringOption('content-type'),
        ),
      );
      progress.finish(message: ' uploaded', showTiming: true);

      _logger.stdout('Uploaded s3://${result.bucket}/${result.key}');
      if (result.eTag case final eTag?) {
        _logger.stdout('ETag: $eTag');
      }
      if (result.versionId case final versionId?) {
        _logger.stdout('Version ID: $versionId');
      }
      return 0;
    } finally {
      client.dispose();
    }
  }

  String get _endpoint => _stringOption('endpoint');

  io.File _fileFromUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.scheme != 'file') {
      usageException('file-uri must be an absolute file:// URI.');
    }
    return io.File.fromUri(uri);
  }

  String _stringOption(String name) {
    final value = _optionalStringOption(name);
    if (value == null) {
      usageException('--$name must not be empty.');
    }
    return value;
  }

  String? _optionalStringOption(String name) {
    final value = argResults![name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? _optionalEnvironmentValue(String name) {
    final value = io.Platform.environment[name];
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
