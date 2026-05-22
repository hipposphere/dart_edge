import 'dart:io';

import 'package:data_assets/data_assets.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildDataAssets) {
      return;
    }

    final docsDirectory = Directory.fromUri(
      input.packageRoot.resolve('content/docs'),
    );
    if (!await docsDirectory.exists()) {
      return;
    }

    output.dependencies.add(docsDirectory.uri);

    await for (final entity in docsDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !_isMdxFile(entity)) {
        continue;
      }

      final relativeName = _relativeAssetName(
        entity.uri,
        input.packageRoot.resolve('content'),
      );

      output.assets.data.add(
        DataAsset(
          package: input.packageName,
          name: relativeName,
          file: entity.uri,
        ),
      );
      output.dependencies.add(entity.uri);
    }
  });
}

bool _isMdxFile(File file) {
  return file.path.endsWith('.md') || file.path.endsWith('.mdx');
}

String _relativeAssetName(Uri file, Uri root) {
  final rootPath = root.toFilePath(windows: false);
  final filePath = file.toFilePath(windows: false);
  final relative = filePath.substring(rootPath.length);
  return relative.replaceAll(RegExp(r'^/+'), '');
}
