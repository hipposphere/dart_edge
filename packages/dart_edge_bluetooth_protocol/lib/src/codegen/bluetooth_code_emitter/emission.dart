part of '../bluetooth_code_emitter.dart';

/// One generated Dart file in a Bluetooth code emission.
final class BluetoothCodeEmissionFile {
  const BluetoothCodeEmissionFile({
    required this.relativePath,
    required this.contents,
  });

  final String relativePath;
  final String contents;
}

/// Structured output tree generated from a Bluetooth GATT application.
final class BluetoothCodeEmission {
  BluetoothCodeEmission({required Iterable<BluetoothCodeEmissionFile> files})
    : files = List<BluetoothCodeEmissionFile>.unmodifiable(files);

  final List<BluetoothCodeEmissionFile> files;

  BluetoothCodeEmissionFile fileAt(String relativePath) {
    for (final file in files) {
      if (file.relativePath == relativePath) {
        return file;
      }
    }
    throw StateError('Generated file "$relativePath" was not found.');
  }

  void writeToDirectory(String outputDirectory) {
    final root = Directory(outputDirectory);
    root.createSync(recursive: true);

    for (final file in files) {
      final outputFile = File('${root.path}/${file.relativePath}');
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(file.contents);
    }
  }
}
