part of '../bluetooth_code_emitter.dart';

/// Emits a typed Bluetooth client facade backed by [BluetoothClientBackend].
BluetoothCodeEmission emitBluetoothClient(
  BluetoothGattApplication application, {
  String className = 'GeneratedBluetoothClient',
  String backendClassName = 'BluetoothClientBackend',
}) {
  _validateClassName(className, parameterName: 'className');
  _validateClassName(backendClassName, parameterName: 'backendClassName');

  final fileName = '${_fileStem(className)}.g.dart';
  return BluetoothCodeEmission(
    files: [
      BluetoothCodeEmissionFile(
        relativePath: fileName,
        contents: _format(
          _emitClientLibrary(
            application,
            className: className,
            backendClassName: backendClassName,
          ),
        ),
      ),
    ],
  );
}

/// Emits a typed server facade backed by `DartEdgeBluetoothServer`.
BluetoothCodeEmission emitBluetoothServerFacade(
  BluetoothGattApplication application, {
  String className = 'GeneratedBluetoothServer',
}) {
  _validateClassName(className, parameterName: 'className');

  final fileName = '${_fileStem(className)}.g.dart';
  return BluetoothCodeEmission(
    files: [
      BluetoothCodeEmissionFile(
        relativePath: fileName,
        contents: _format(
          _emitServerLibrary(application, className: className),
        ),
      ),
    ],
  );
}
