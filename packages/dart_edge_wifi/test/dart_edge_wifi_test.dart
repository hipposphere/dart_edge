import 'package:dart_edge_wifi/dart_edge_wifi.dart';
import 'package:test/test.dart';

void main() {
  test('lists networks from nmcli terse output', () async {
    final calls = <(String, List<String>)>[];
    final wifi = DartEdgeWifi(
      backend: NmcliWifiBackend(
        commandRunner: (executable, args) async {
          calls.add((executable, args));
          return const WifiCommandResult(
            exitCode: 0,
            stdout: r'''
Office\:Lab:AA\:BB\:CC\:DD\:EE\:FF:11:2462:88:WPA2:*:
Guest:11\:22\:33\:44\:55\:66:6:2437:45:--::Infra
''',
            stderr: '',
          );
        },
      ),
    );

    final networks = await wifi.listNetworks(
      interfaceName: 'wlan0',
      rescan: WifiRescanPolicy.no,
    );

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'nmcli');
    expect(calls.single.$2, [
      '-t',
      '-f',
      'SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY,IN-USE,MODE',
      'device',
      'wifi',
      'list',
      'ifname',
      'wlan0',
      '--rescan',
      'no',
    ]);
    expect(networks, hasLength(2));
    expect(networks.first.ssid, 'Office:Lab');
    expect(networks.first.bssid, 'AA:BB:CC:DD:EE:FF');
    expect(networks.first.channel, 11);
    expect(networks.first.frequencyMHz, 2462);
    expect(networks.first.signalPercent, 88);
    expect(networks.first.security, 'WPA2');
    expect(networks.first.inUse, isTrue);
    expect(networks.first.mode, '');
    expect(networks.last.ssid, 'Guest');
    expect(networks.last.isSecured, isFalse);
    expect(networks.last.inUse, isFalse);
    expect(networks.last.mode, 'Infra');
  });

  test('connects to a network with optional arguments', () async {
    final calls = <(String, List<String>)>[];
    final wifi = DartEdgeWifi(
      backend: NmcliWifiBackend(
        nmcliExecutable: '/usr/bin/nmcli',
        commandRunner: (executable, args) async {
          calls.add((executable, args));
          return const WifiCommandResult(
            exitCode: 0,
            stdout: 'Device successfully activated.\n',
            stderr: '',
          );
        },
      ),
    );

    final result = await wifi.connect(
      const WifiConnectionRequest(
        ssid: 'Office',
        password: 'secret',
        interfaceName: 'wlan0',
        bssid: 'AA:BB:CC:DD:EE:FF',
        connectionName: 'office-profile',
        hidden: true,
      ),
    );

    expect(result.ssid, 'Office');
    expect(calls, hasLength(1));
    expect(calls.single.$1, '/usr/bin/nmcli');
    expect(calls.single.$2, [
      'device',
      'wifi',
      'connect',
      'Office',
      'password',
      'secret',
      'ifname',
      'wlan0',
      'bssid',
      'AA:BB:CC:DD:EE:FF',
      'name',
      'office-profile',
      'hidden',
      'yes',
    ]);
  });

  test('throws WifiException when nmcli fails', () async {
    final wifi = DartEdgeWifi(
      backend: const NmcliWifiBackend(commandRunner: _failingCommandRunner),
    );

    await expectLater(
      wifi.listNetworks(),
      throwsA(
        isA<WifiException>()
            .having((error) => error.exitCode, 'exitCode', 10)
            .having((error) => error.stderr, 'stderr', 'no permissions'),
      ),
    );
  });

  test('rejects empty SSID before running nmcli', () async {
    final wifi = DartEdgeWifi(
      backend: const NmcliWifiBackend(commandRunner: _failingCommandRunner),
    );

    await expectLater(
      wifi.connect(const WifiConnectionRequest(ssid: '')),
      throwsArgumentError,
    );
  });
}

Future<WifiCommandResult> _failingCommandRunner(
  String executable,
  List<String> args,
) async {
  return const WifiCommandResult(
    exitCode: 10,
    stdout: '',
    stderr: 'no permissions',
  );
}
