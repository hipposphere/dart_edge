# dart_edge_sip

Standalone native SIP runtime package for Dart Edge.

`dart_edge_sip` is intended to be a focused telephony service package, not an
HTTP runtime feature and not a helper-layer convenience wrapper. It follows the
same workspace pattern as `dart_edge_auth` and `dart_edge_sql`: a Dart API,
native build hook, Rust crate, header-defined C ABI, and generated FFI
bindings.

The package now includes a real **PJSIP-backed native runtime foundation**:
runtime lifecycle, transport/trunk setup, outbound/inbound call state events,
call control, bridge/hold/resume/transfer commands, prompt playback, call
recording, voicemail recording hooks, and first-pass media-app attachment with
assistant-oriented PCM audio access.

It is still not a finished PBX. Full registrar/auth endpoint handling,
distributed telephony concerns, and browser/WebRTC edges remain outside the
current implementation.

## Runtime Choice

This package wraps **PJSIP** behind Rust. That is the concrete runtime choice
reflected in the current config API and native bridge.

Why PJSIP:

- mature SIP, SDP, RTP, STUN, TURN, and ICE stack
- high-level call/media APIs and conference-bridge support
- long-lived project with broad deployment history

Why not a pure-Rust runtime yet:

- `rsip` is a SIP parsing/generation library, not a server/media runtime
- newer full-Rust stacks are promising but not stable enough for this repo's
  production target yet

Operational notes:

- the native bridge requires `pjproject` to be installed and discoverable
  through `pkg-config`
- the default `PjsipEngineConfig` values are sized for a stock `pjproject`
  build, which commonly compiles with `PJSUA_MAX_CALLS=4`
- larger production deployments should ship a custom `pjproject` build with
  higher `PJSUA_*` limits

Licensing note:

- PJSIP is dual-licensed GPL/commercial, so production rollout must choose a
  licensing path deliberately

## V1 Intent

The current package targets backend-controlled VoIP call handling for Dart apps
with:

- SIP transports and listener lifecycle
- registrar/authentication and endpoint registration tracking
- trunks and dialplan-driven call routing
- call/session control for answer, reject, hold, resume, bridge, transfer, and
  hangup
- media-app concepts for IVR, recording, voicemail, and assistant-style audio
  loops
- embedded Dart control APIs plus async event streams

## Non-Goals For V1

- WebRTC or SIP-over-WebSocket
- carrier-grade SBC policy and topology hiding
- clustering or distributed media coordination
- generic transcoding-heavy media pipelines
- browser-facing admin APIs as the primary control surface
- a pure Dart SIP stack

## Public API Shape

The top-level package exports these main concepts:

- `DartEdgeSip`: runtime entrypoint and lifecycle owner
- `PjsipEngineConfig`: explicit production runtime choice and engine settings
- `SipServerConfig`: top-level telephony runtime configuration
- `SipEndpointConfig`: managed endpoint/extension configuration
- `SipTrunkConfig`: trunk definitions
- `SipDialplan`: inbound/outbound routing policy interface
- `SipCallSession`: one call/session control handle
- `SipMediaApp`: engine-neutral media app interface
- `SipRealtimeMediaSession` and `SipAudioFormat`: attached media session and
  normalized audio format
- `SipCallEvent`, `SipRegistrationEvent`, `SipTrunkEvent`,
  `SipRecordingEvent`, `SipVoicemailEvent`: event categories

## Example

```dart
import 'dart:async';

import 'package:dart_edge_sip/dart_edge_sip.dart';

Future<void> main() async {
  final sip = DartEdgeSip(
    config: SipServerConfig(
      engine: const PjsipEngineConfig(
        licenseMode: SipRuntimeLicenseMode.commercial,
        maxCalls: 4,
        maxConferencePorts: 32,
        maxRegistrations: 10000,
      ),
      transports: const [
        SipTransportBinding.udp(host: '0.0.0.0', port: 5060),
        SipTransportBinding.tcp(host: '0.0.0.0', port: 5060),
      ],
      realms: const [
        SipRealmConfig(domain: 'pbx.example.com', realm: 'pbx.example.com'),
      ],
      endpoints: const [
        SipEndpointConfig(
          id: 'sales-1000',
          extension: '1000',
          username: '1000',
          password: 'change-me',
          realm: 'pbx.example.com',
        ),
      ],
      trunks: const [
        SipTrunkConfig(
          id: 'carrier-a',
          direction: SipTrunkDirection.bidirectional,
          serverUri: 'sip:carrier.example.net',
        ),
      ],
    ),
  );

  final subscription = sip.events.listen(print);
  await sip.start();

  final call = await sip.originateCall(
    const SipOutboundCallRequest(
      trunkId: 'carrier-a',
      fromUri: 'sip:1000@pbx.example.com',
      toUri: 'sip:+49301234567@carrier.example.net',
    ),
  );

  await call.hangup();

  await sip.dispose();
  await subscription.cancel();
}
```

## Native Layout

- build hook: `hook/build.dart`
- Rust crate: `rust/`
- ABI header: `rust/include/dart_edge_sip.h`
- generated bindings: `lib/src/native/generated_bindings.dart`

The package keeps the Dart API intentionally engine-neutral even though the
current native layer is PJSIP-backed. That keeps application code stable while
the underlying telephony backend grows.

## Realtime Media Apps

The current media-app attachment path is designed as a first pass for phone
assistant and IVR style features:

- attach a registered `SipMediaApp` to a call with `call.attachMediaApp(...)`
- read normalized PCM16 mono frames from `session.media.pollIncomingFrame()`
  or `session.media.incomingFrames()`
- play synthesized PCM16 clips back into the call with
  `session.media.playAudioBytes(...)`

The normalized assistant format is currently `16 kHz`, mono, `20 ms` PCM16LE
frames exposed through `SipAudioFormat.voiceAssistant()`.

Media apps now use long-lived conference ports for both directions:

- inbound call audio is captured into a native PCM ring buffer and exposed to
  Dart as normalized frames
- outbound PCM bytes are queued directly into a native playback ring buffer and
  streamed into the call without staging temporary media files

The realtime media path currently assumes normalized `16 kHz` mono PCM16 for
assistant playback.

See [CONCEPT.md](CONCEPT.md) for the fuller package concept and phased
implementation direction.
