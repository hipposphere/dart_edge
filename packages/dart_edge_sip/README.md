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
assistant-oriented PCM audio access. Configured endpoints can also register
with the built-in registrar, surface registration events, be queried from Dart,
and receive routed calls through active contacts.

It is still not a finished PBX. Distributed telephony concerns, advanced
registrar policy, and browser/WebRTC edges remain outside the current
implementation.

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

- `pjproject` is required; prebuilt `dart_edge_sip` artifacts do not bundle or
  directly link PJSIP, so PJSIP must be installed and loadable by the host
  process
- source builds require `pjproject` headers discoverable through `pkg-config`,
  but still do not directly link PJSIP
- the default `PjsipEngineConfig` values are sized for a stock `pjproject`
  build, which commonly compiles with `PJSUA_MAX_CALLS=4`
- larger production deployments should ship a custom `pjproject` build with
  higher `PJSUA_*` limits
- set `DART_EDGE_SIP_PJPROJECT_LIBRARIES` to a semicolon-separated list of
  shared PJSIP library paths if the platform loader cannot find them by name

Licensing note:

- PJSIP is dual-licensed GPL/commercial, so production rollout must choose a
  licensing path deliberately

## Installing PJSIP

`dart_edge_sip` needs `pjproject` on the machine that builds or runs the SIP
runtime.

macOS with Homebrew:

```bash
brew install pkg-config pjproject
pkg-config --cflags --libs libpjproject
```

Ubuntu or Debian, when your distribution provides PJSIP packages:

```bash
sudo apt update
sudo apt install pkg-config libpjproject-dev
pkg-config --cflags --libs libpjproject
```

Some Ubuntu environments, including GitHub Actions runners, do not provide
`libpjproject-dev` in the default repositories. In that case install PJSIP from
source:

```bash
sudo apt update
sudo apt install build-essential curl pkg-config

version="2.17"
curl -fsSL "https://github.com/pjsip/pjproject/archive/refs/tags/$version.tar.gz" \
  -o "pjproject-$version.tar.gz"
tar -xzf "pjproject-$version.tar.gz"
cd "pjproject-$version"
cp pjlib/include/pj/config_site_sample.h pjlib/include/pj/config_site.h
./configure --prefix=/usr/local
make dep
make
sudo make install
sudo ldconfig

pkg-config --cflags --libs libpjproject
```

For CI jobs that only need to compile `dart_edge_sip` without linking PJSIP,
the native asset workflow downloads pjproject sources, runs `./configure` to
generate platform headers, copies the PJSIP public include trees into a
temporary include prefix, and provides a header-only `libpjproject.pc`.


If `pkg-config` cannot find `libpjproject`, set `PKG_CONFIG_PATH` to the
directory containing `libpjproject.pc`. For example:

```bash
export PKG_CONFIG_PATH="/opt/homebrew/opt/pjproject/lib/pkgconfig:$PKG_CONFIG_PATH"
```

`dart_edge_sip` artifacts intentionally do not bundle or directly link PJSIP.
If the runtime loader cannot find shared PJSIP libraries, provide them through
`DART_EDGE_SIP_PJPROJECT_LIBRARIES`.

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
- `SipRegisteredEndpoint`: active endpoint contact snapshots from the registrar
- `SipMediaApp`: engine-neutral media app interface
- `SipRealtimeMediaSession` and `SipAudioFormat`: attached media session and
  normalized audio format
- `SipCallEvent`, `SipRegistrationEvent`, `SipTrunkEvent`,
  `SipRecordingEvent`, `SipVoicemailEvent`: event categories

Inbound `SipCallEvent` values and `SipInboundInvite` dialplan requests expose
the matched `trunkId` when the call arrived through a configured trunk. Each
trunk owns a PJSIP account even when it does not register with credentials, so
applications can route calls by trunk without relying on rewritten SIP URIs.

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

  final registeredContacts = await sip.registeredEndpoints();
  print('Registered endpoints: $registeredContacts');

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

## Registrar and Endpoint Routing

Configured `SipEndpointConfig` entries are installed into the native registrar
when `SipFeatureFlags.registrar` is enabled. SIP user agents can `REGISTER`
against the configured realm, registration state is emitted through
`sip.registrationEvents`, and Dart can inspect active contacts with:

```dart
final contacts = await sip.registeredEndpoints();
final salesPhone = await sip.registeredEndpoint('sales-1000');
```

An app can call a registered endpoint directly:

```dart
final call = await sip.callEndpoint(
  const SipEndpointCallRequest(endpointId: 'sales-1000'),
);
```

Inbound dialplans can now return `SipDialplanDecision.routeToEndpoint(...)` or
`SipDialplanDecision.routeToTrunk(...)`. The native runtime creates the routed
outbound leg and bridges media once both legs are established.

## Dynamic Trunks

Trunks can be configured at startup through `SipServerConfig.trunks` or managed
after `start()` with the trunk-focused runtime API:

```dart
await sip.addTrunk(
  const SipTrunkConfig(
    id: 'carrier-b',
    direction: SipTrunkDirection.bidirectional,
    serverUri: 'sip:carrier-b.example.net',
  ),
);

await sip.updateTrunk(
  'carrier-b',
  const SipTrunkConfig(
    id: 'carrier-b',
    direction: SipTrunkDirection.outbound,
    serverUri: 'sip:backup-carrier.example.net',
  ),
);

await sip.setTrunkRegistration('carrier-b', enabled: false);
await sip.removeTrunk('carrier-b');
```

Use `sip.trunks` to inspect the current runtime trunk definitions.

PJSIP accounts remain an implementation detail of the native runtime. A trunk
with registration credentials is backed by a PJSUA account; a trunk without
credentials routes through the default local account.

For a full inbound voice-assistant package that attaches Gemini Live realtime
audio to a SIP call, see [`examples/callo_engine`](../../examples/callo_engine).

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
