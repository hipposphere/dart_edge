## 0.4.17

- Replace polling-based call-state waits with per-call event waiters and a
  configurable transition timeout.
- Send `180 Ringing` immediately for inbound calls while the Dart dialplan and
  media app prepare.
- Register media-app ports before the final answer, connect them only after the
  call is confirmed, and roll them back if answering fails.
- Bump the native SIP artifact to 0.1.9.

## 0.4.16

- Add pre-answer media-app preparation with `prepareMediaApp` and
  `SipPreparedMediaApp.answerAndAttach`.
- Close prepared resources when calls terminate, attachment fails, or the
  runtime stops, and apply a deterministic media-app termination policy.
- Add bounded capture/playback queues with queue statistics.
- Expose negotiated codec, RTP/RTCP statistics, DTMF events, codec preferences,
  media clock configuration, TLS profiles, SRTP requirements, and NAT settings.
- Validate native PJSIP call capacity and bump the native SIP artifact to
  0.1.8 for the extended media and event ABI.

## 0.4.15

- Let each SIP media app select independent PCM16 mono capture and playback
  formats, including provider-native 16 kHz and 24 kHz rates.
- Delegate conversion between media-app formats and negotiated call codecs to
  the PJSIP conference bridge.
- Bump the native SIP artifact to 0.1.7 for configurable media ports.

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
