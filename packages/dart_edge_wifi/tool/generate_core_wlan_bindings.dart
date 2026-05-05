import 'package:ffigen/ffigen.dart';

final _coreWlanHeader = Uri.file(
  '$macSdkPath/System/Library/Frameworks/CoreWLAN.framework/Versions/A/Headers/CoreWLAN.h',
);

final _config = FfiGenerator(
  headers: Headers(entryPoints: [_coreWlanHeader]),
  objectiveC: ObjectiveC(
    categories: const Categories(includeTransitive: false),
    protocols: const Protocols(includeTransitive: false),
    interfaces: Interfaces(
      include: Declarations.includeSet({
        'CWWiFiClient',
        'CWInterface',
        'CWNetwork',
        'CWChannel',
      }),
      includeMember: Declarations.includeMemberSet({
        'CWWiFiClient': {'sharedWiFiClient', 'interface', 'interfaceWithName:'},
        'CWInterface': {
          'interfaceName',
          'ssid',
          'bssid',
          'scanForNetworksWithSSID:error:',
          'scanForNetworksWithSSID:includeHidden:error:',
          'scanForNetworksWithName:error:',
          'scanForNetworksWithName:includeHidden:error:',
          'associateToNetwork:password:error:',
        },
        'CWNetwork': {
          'ssid',
          'bssid',
          'wlanChannel',
          'rssiValue',
          'supportsSecurity:',
        },
        'CWChannel': {'channelNumber'},
      }),
    ),
  ),
  output: Output(
    dartFile: Uri.file('lib/src/core_wlan_bindings.dart'),
    sort: true,
    commentType: const CommentType.none(),
    preamble:
        '// ignore_for_file: camel_case_types, non_constant_identifier_names',
    style: const DynamicLibraryBindings(wrapperName: 'CoreWlanLibrary'),
  ),
);

void main() {
  _config.generate();
}
