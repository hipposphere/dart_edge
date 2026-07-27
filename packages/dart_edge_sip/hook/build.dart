import 'package:code_assets/code_assets.dart';
import 'package:dart_edge_native_assets/dart_edge_native_assets.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final packageName = input.packageName;
    final pkgConfigPath = input.userDefines.path('pkg_config_path');
    if (pkgConfigPath != null) {
      output.dependencies.add(pkgConfigPath);
    }

    await DartEdgePrebuiltRustBuilder(
      assetName: '$packageName.dart',
      cratePath: 'rust',
      extraCargoEnvironmentVariables: {
        if (pkgConfigPath != null)
          'PKG_CONFIG_PATH': pkgConfigPath.toFilePath(),
      },
    ).run(input: input, output: output);
  });
}
