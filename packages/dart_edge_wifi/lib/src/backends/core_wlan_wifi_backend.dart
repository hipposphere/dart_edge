import 'dart:ffi';

import 'package:objective_c/objective_c.dart' as objc;

import '../core_wlan_bindings.dart' as cw;
import '../wifi_backend.dart';
import '../wifi_connection_request.dart';
import '../wifi_connection_result.dart';
import '../wifi_exception.dart';
import '../wifi_network.dart';
import '../wifi_rescan_policy.dart';

/// macOS Wi-Fi backend backed by CoreWLAN through Objective-C interop.
final class CoreWlanWifiBackend implements WifiBackend {
  const CoreWlanWifiBackend();

  static bool _frameworkLoaded = false;

  @override
  Future<List<WifiNetwork>> listNetworks({
    String? interfaceName,
    WifiRescanPolicy rescan = WifiRescanPolicy.auto,
  }) async {
    final interface = _interfaceForName(interfaceName);
    final networks =
        interface.scanForNetworksWithName$1(
          null,
          includeHidden: rescan != WifiRescanPolicy.no,
        ) ??
        objc.NSSet();
    final currentBssid = interface.bssid()?.toDartString();
    final result = networks
        .asDart()
        .map((object) {
          return _networkFromCoreWlan(cw.CWNetwork.as(object), currentBssid);
        })
        .toList(growable: false);

    result.sort((a, b) {
      final signal = (b.signalPercent ?? -1).compareTo(a.signalPercent ?? -1);
      if (signal != 0) {
        return signal;
      }
      return a.ssid.compareTo(b.ssid);
    });
    return result;
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

    final interface = _interfaceForName(request.interfaceName);
    final network = _findNetwork(interface, request);
    final password = request.password?.toNSString();
    try {
      interface.associateToNetwork(network, password: password);
    } on objc.NSErrorException catch (error) {
      throw WifiException(
        'Failed to connect to Wi-Fi network.',
        stderr: error.toString(),
      );
    }

    return WifiConnectionResult(
      ssid: request.ssid,
      stdout: 'Connected through CoreWLAN.',
    );
  }

  static cw.CWInterface _interfaceForName(String? interfaceName) {
    _loadFramework();
    final client = cw.CWWiFiClient.sharedWiFiClient();
    final interface = interfaceName == null
        ? client.interface()
        : client.interfaceWithName(interfaceName.toNSString());
    if (interface == null) {
      throw WifiException(
        interfaceName == null
            ? 'No default Wi-Fi interface was found.'
            : 'Wi-Fi interface `$interfaceName` was not found.',
      );
    }
    return interface;
  }

  static cw.CWNetwork _findNetwork(
    cw.CWInterface interface,
    WifiConnectionRequest request,
  ) {
    final networks =
        interface.scanForNetworksWithName$1(
          request.ssid.toNSString(),
          includeHidden: request.hidden,
        ) ??
        objc.NSSet();

    for (final object in networks.asDart()) {
      final network = cw.CWNetwork.as(object);
      final bssid = network.bssid?.toDartString();
      final bssidMatches = request.bssid == null
          ? true
          : bssid?.toLowerCase() == request.bssid!.toLowerCase();
      if (bssidMatches) {
        return network;
      }
    }

    throw WifiException('Wi-Fi network `${request.ssid}` was not found.');
  }

  static WifiNetwork _networkFromCoreWlan(
    cw.CWNetwork network,
    String? currentBssid,
  ) {
    final bssid = network.bssid?.toDartString();
    final channel = network.wlanChannel?.channelNumber;
    final rssiDbm = network.rssiValue == 0 ? null : network.rssiValue;

    return WifiNetwork(
      ssid: network.ssid?.toDartString() ?? '',
      bssid: bssid,
      channel: channel,
      frequencyMHz: channel == null ? null : _channelFrequencyMHz(channel),
      signalPercent: rssiDbm == null
          ? null
          : ((rssiDbm + 100) * 2).clamp(0, 100),
      rssiDbm: rssiDbm,
      security: _securityLabel(network),
      inUse:
          bssid != null &&
          currentBssid != null &&
          bssid.toLowerCase() == currentBssid.toLowerCase(),
      mode: 'Infra',
    );
  }

  static String _securityLabel(cw.CWNetwork network) {
    const checks = [
      (cw.CWSecurity.kCWSecurityWPA3Transition, 'WPA3/WPA2'),
      (cw.CWSecurity.kCWSecurityWPA3Personal, 'WPA3'),
      (cw.CWSecurity.kCWSecurityWPA3Enterprise, 'WPA3 Enterprise'),
      (cw.CWSecurity.kCWSecurityWPA2Personal, 'WPA2'),
      (cw.CWSecurity.kCWSecurityWPA2Enterprise, 'WPA2 Enterprise'),
      (cw.CWSecurity.kCWSecurityWPAPersonalMixed, 'WPA/WPA2'),
      (cw.CWSecurity.kCWSecurityWPAEnterpriseMixed, 'WPA/WPA2 Enterprise'),
      (cw.CWSecurity.kCWSecurityWPAPersonal, 'WPA'),
      (cw.CWSecurity.kCWSecurityWPAEnterprise, 'WPA Enterprise'),
      (cw.CWSecurity.kCWSecurityPersonal, 'Personal'),
      (cw.CWSecurity.kCWSecurityEnterprise, 'Enterprise'),
      (cw.CWSecurity.kCWSecurityDynamicWEP, 'Dynamic WEP'),
      (cw.CWSecurity.kCWSecurityWEP, 'WEP'),
      (cw.CWSecurity.kCWSecurityOWETransition, 'OWE Transition'),
      (cw.CWSecurity.kCWSecurityOWE, 'OWE'),
    ];

    for (final (security, label) in checks) {
      if (network.supportsSecurity(security)) {
        return label;
      }
    }
    if (network.supportsSecurity(cw.CWSecurity.kCWSecurityNone)) {
      return '--';
    }
    return 'unknown';
  }

  static int? _channelFrequencyMHz(int channel) {
    return switch (channel) {
      >= 1 && <= 13 => 2407 + channel * 5,
      14 => 2484,
      >= 32 && <= 177 => 5000 + channel * 5,
      _ => null,
    };
  }

  static void _loadFramework() {
    if (_frameworkLoaded) {
      return;
    }
    DynamicLibrary.open(
      '/System/Library/Frameworks/CoreWLAN.framework/CoreWLAN',
    );
    _frameworkLoaded = true;
  }
}
