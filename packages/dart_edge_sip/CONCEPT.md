# dart_edge_sip Concept

## Thesis

`dart_edge_sip` should be a standalone telephony runtime package for Dart
applications that need backend-controlled SIP/VoIP call handling.

It should stay outside `dart_edge_http_server_runtime` and follow the focused native
service-package pattern already used by `dart_edge_auth` and `dart_edge_sql`.

The concrete production runtime choice should be **PJSIP wrapped behind Rust**.
The public Dart API should remain package-owned and stable above that runtime.

## Why PJSIP

PJSIP is the right production target for this package because it already
provides:

- mature SIP, SDP, RTP, STUN, TURN, and ICE support
- high-level call/media APIs through PJSUA
- conference-bridge/media primitives that fit PBX-style call control
- a long-lived deployment track record that current pure-Rust SIP stacks do not
  yet match

Rejected runtime paths for now:

- `rsip` is useful as a parser/generator base library, but not a runtime or
  media engine
- pure-Rust full-stack SIP efforts are promising but still early for the
  production target of this package
- baresip is a strong SIP user-agent stack, but its shape is less aligned with
  the embedded PBX/control-runtime direction here than a PJSIP-backed adapter

Licensing must stay explicit:

- GPL path for open-source-compatible distribution
- commercial license path for proprietary production deployment

## Product Scope

The package is for:

- SIP transports and listener lifecycle
- registrar/authentication and endpoint registration tracking
- trunks and dialplan-driven call routing
- call/session control such as answer, reject, bridge, hold, resume, transfer,
  recording, voicemail, and hangup
- backend-controlled media-app flows such as IVR

The package is not for:

- HTTP route handling
- WebRTC or SIP-over-WebSocket in v1
- carrier-grade SBC policy
- pure-Dart SIP/RTP implementation

## Public API

The package concept should center around:

- `DartEdgeSip`
- `PjsipEngineConfig`
- `SipServerConfig`
- `SipEndpointConfig`
- `SipTrunkConfig`
- `SipDialplan`
- `SipCallSession`
- `SipMediaApp`
- event types for call, registration, trunk, recording, and voicemail

Applications should interact through:

- startup configuration
- async event streams
- command methods on runtime/session handles
- optional Dart policy hooks for routing and authorization

## Native Architecture

The intended layering is:

1. Dart package API
2. Rust adapter layer
3. PJSIP/PJMEDIA underneath
4. optional recording/voicemail storage adapters

Rust should own:

- PJSIP initialization and shutdown
- callback isolation from PJSIP threads into Rust-owned queues
- dialog/call handle mapping
- translation of native callbacks into stable package events
- command dispatch for call/session control

The current implementation now includes:

- a real PJSIP-backed runtime bootstrap behind Rust
- transport creation for UDP/TCP/TLS bindings
- trunk account setup and trunk registration-state events
- outbound call origination plus inbound/outbound call-state events
- call control for answer, reject, hold, resume, transfer, bridge, and hangup
- conference-bridge prompt playback
- WAV recording and voicemail recording via the PJSUA conference bridge

The package is still not a complete PBX or registrar. The main remaining gap is
full endpoint/registrar handling above the PJSUA user-agent layer. Production
scaling also depends on shipping a custom `pjproject` build with higher
`PJSUA_*` compile-time limits than the stock system package usually provides.
