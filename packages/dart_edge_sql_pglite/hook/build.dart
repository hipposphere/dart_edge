import 'package:code_assets/code_assets.dart';
import 'package:dart_edge_native_assets/dart_edge_native_assets.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final packageName = input.packageName;

    await DartEdgePrebuiltRustBuilder(
      assetName: '$packageName.dart',
      cratePath: 'rust',
    ).run(input: input, output: output);
  });
}
