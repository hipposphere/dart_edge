import 'dart:convert';
import 'dart:io';

import '../wifi_backend.dart';
import '../wifi_command_result.dart';
import '../wifi_connection_request.dart';
import '../wifi_connection_result.dart';
import '../wifi_exception.dart';
import '../wifi_network.dart';
import '../wifi_rescan_policy.dart';

typedef WifiCommandRunner =
    Future<WifiCommandResult> Function(String executable, List<String> args);

/// Linux Wi-Fi backend backed by NetworkManager's `nmcli` command.
final class NmcliWifiBackend implements WifiBackend {
  const NmcliWifiBackend({
    this.nmcliExecutable = 'nmcli',
    WifiCommandRunner? commandRunner,
  }) : _commandRunner = commandRunner ?? _runProcess;

  final String nmcliExecutable;
  final WifiCommandRunner _commandRunner;

  @override
  Future<List<WifiNetwork>> listNetworks({
    String? interfaceName,
    WifiRescanPolicy rescan = WifiRescanPolicy.auto,
  }) async {
    final args = [
      '-t',
      '-f',
      'SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY,IN-USE,MODE',
      'device',
      'wifi',
      'list',
      if (interfaceName != null) ...['ifname', interfaceName],
      '--rescan',
      rescan.wireValue,
    ];

    final result = await _commandRunner(nmcliExecutable, args);
    _throwIfFailed(result, 'Failed to list Wi-Fi networks.');

    return result.stdout
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(_parseNetworkLine)
        .toList(growable: false);
  }

  @override
  Future<WifiConnectionResult> connect(WifiConnectionRequest request) async {
    if (request.ssid.isEmpty) {
      throw ArgumentError.value(
        request.ssid,
        'ssid',
        'SSID must not be empty.',
      );
    }

    final args = [
      'device',
      'wifi',
      'connect',
      request.ssid,
      if (request.password != null) ...['password', request.password!],
      if (request.interfaceName != null) ...['ifname', request.interfaceName!],
      if (request.bssid != null) ...['bssid', request.bssid!],
      if (request.connectionName != null) ...['name', request.connectionName!],
      if (request.hidden) ...['hidden', 'yes'],
    ];

    final result = await _commandRunner(nmcliExecutable, args);
    _throwIfFailed(result, 'Failed to connect to Wi-Fi network.');

    return WifiConnectionResult(ssid: request.ssid, stdout: result.stdout);
  }

  static Future<WifiCommandResult> _runProcess(
    String executable,
    List<String> args,
  ) async {
    final result = await Process.run(executable, args);
    return WifiCommandResult(
      exitCode: result.exitCode,
      stdout: _decodeProcessOutput(result.stdout),
      stderr: _decodeProcessOutput(result.stderr),
    );
  }

  static String _decodeProcessOutput(Object? output) {
    return switch (output) {
      final String value => value,
      final List<int> value => utf8.decode(value),
      null => '',
      _ => output.toString(),
    };
  }

  static void _throwIfFailed(WifiCommandResult result, String message) {
    if (result.exitCode == 0) {
      return;
    }
    throw WifiException(
      message,
      exitCode: result.exitCode,
      stderr: result.stderr.trim(),
    );
  }

  static WifiNetwork _parseNetworkLine(String line) {
    final fields = _splitNmcliTerseLine(line);
    if (fields.length != 8) {
      throw WifiException(
        'Unexpected nmcli Wi-Fi list output with ${fields.length} fields.',
        stderr: line,
      );
    }

    return WifiNetwork(
      ssid: fields[0],
      bssid: fields[1].isEmpty ? null : fields[1],
      channel: _parseNullableInt(fields[2]),
      frequencyMHz: _parseNullableInt(fields[3]),
      signalPercent: _parseNullableInt(fields[4]),
      rssiDbm: null,
      security: fields[5],
      inUse: fields[6] == '*',
      mode: fields[7],
    );
  }

  static int? _parseNullableInt(String value) {
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  static List<String> _splitNmcliTerseLine(String line) {
    final fields = <String>[];
    final current = StringBuffer();
    var escaping = false;

    for (final codeUnit in line.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (escaping) {
        current.write(char);
        escaping = false;
        continue;
      }
      if (char == r'\') {
        escaping = true;
        continue;
      }
      if (char == ':') {
        fields.add(current.toString());
        current.clear();
        continue;
      }
      current.write(char);
    }

    if (escaping) {
      current.write(r'\');
    }
    fields.add(current.toString());
    return fields;
  }
}
