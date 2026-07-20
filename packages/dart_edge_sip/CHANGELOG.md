## 0.4.14

- Expose the associated SIP trunk ID on call events and inbound dialplan
  invites, including for trunks that do not register with credentials.
- Bump the native SIP artifact to 0.1.6 for the PJSIP account-to-trunk event
  mapping change.

## 0.4.9

- Build SIP native artifacts against PJSIP 2.17 headers.
- Bump the native artifact version to 0.1.4 for Rust 1.95 and dependency
  updates.

## 0.4.6

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2.

## 0.4.4

- Add Linux arm64 native artifact publishing.
- Build prebuilt SIP artifacts without directly linking or bundling PJSIP.

## 0.4.3

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
