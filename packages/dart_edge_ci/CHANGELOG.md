## 0.1.11

- Add App Store Connect publish configuration for Fastlane precheck behavior,
  defaulting unsupported in-app purchase checks off for API key uploads.
- Install iOS provisioning profiles into both the legacy MobileDevice location
  and Xcode's current UserData location so Flutter can generate complete manual
  signing export options.

## 0.1.7

- Add `flutter_release.yaml` variables for reusing values in target
  `dart_defines`.

## 0.1.0

- Initial internal release.
- Add precompiled GitHub Action distribution for the `dart_edge_ci` CLI.
