# Callo Engine

Callo Engine is an example SIP audio engine that registers with a SIP trunk,
answers inbound trunk calls, and bridges the call audio to Gemini Live.

The package is intentionally small:

- `bin/callo_engine.dart` starts the engine from a Gemini API key and
  environment configuration.
- `lib/src/config/` owns the SIP and Gemini settings.
- `lib/src/runtime/` wires the SIP server, dialplan, and media app together.
- `lib/src/media/` bridges SIP realtime media to Gemini Live.
- `lib/src/gemini/` contains the Gemini Live client.
- `lib/src/audio/` contains local PCM helpers.

## Prerequisites

- `pjproject` installed and visible through `pkg-config`
- a Gemini API key with Live API access
- SIP trunk credentials from a carrier or PBX

## Start

From the package directory:

```sh
cd examples/callo_engine
export SIP_TRUNK_USERNAME='your-sip-username'
export SIP_TRUNK_PASSWORD='your-sip-password'
dart run bin/callo_engine.dart --gemini-api-key 'your-api-key'
```

Or use the environment:

```sh
cd examples/callo_engine
export GEMINI_API_KEY='your-api-key'
export SIP_TRUNK_USERNAME='your-sip-username'
export SIP_TRUNK_PASSWORD='your-sip-password'
dart run bin/callo_engine.dart
```

The engine creates a local SIP listener and registers the configured trunk
account. Inbound calls delivered by the trunk are routed to the Gemini Live
assistant media app.

With `just` installed, fill in `.env` and run:

```sh
cd examples/callo_engine
just run
```

## Configuration

Required:

- `GEMINI_API_KEY`, unless `--gemini-api-key` is passed
- `SIP_TRUNK_USERNAME`
- `SIP_TRUNK_PASSWORD`

Optional:

- `GEMINI_LIVE_MODEL`
  Default: `gemini-3.1-flash-live-preview`
- `GEMINI_VOICE_NAME`
  Default: `Kore`
- `CALLO_SYSTEM_PROMPT`
- `CALLO_INITIAL_PROMPT`
- `CALLO_JINGLE_SECONDS`
  Default: `2`. Set to `0` to disable the local startup jingle.
- `CALLO_ASSISTANT_USER`
  Default: `assistant`
  Set to `*` to accept any inbound SIP user, which is useful when a carrier
  trunk sends calls to your phone number instead of `assistant`.
- `SIP_BIND_HOST`
  Default: `0.0.0.0`
- `SIP_BIND_PORT`
  Default: `5060`
- `SIP_PUBLIC_ADDRESS`
  Fallback advertised SIP/RTP address when `SIP_EXTERNAL_ADDRESS` is not set.
- `SIP_TRUNK_ID`
  Default: `easybell`
- `SIP_TRUNK_SERVER_URI`
  Default: `sip:voip.easybell.de`
- `SIP_TRUNK_REALM`
  Default: `voip.easybell.de`
- `SIP_RTP_START_PORT`
  Default: `40000`
- `SIP_RTP_END_PORT`
  Default: `40100`
- `SIP_EXTERNAL_ADDRESS`
  Useful when the trunk requires SDP/RTP to advertise a reachable public host
  or IP.

## Connecting A SIP Trunk

Set the SIP credentials from the carrier portal and start the engine:

```sh
export SIP_TRUNK_USERNAME='YOUR_SIP_USERNAME'
export SIP_TRUNK_PASSWORD='YOUR_SIP_PASSWORD'
export SIP_TRUNK_SERVER_URI='sip:voip.easybell.de'
export SIP_TRUNK_REALM='voip.easybell.de'
export CALLO_ASSISTANT_USER='*'
dart run bin/callo_engine.dart --gemini-api-key 'your-api-key'
```

Use `CALLO_ASSISTANT_USER='*'` when the carrier sends the called number in the
request URI. Keep the default `assistant` only when the trunk delivers INVITEs
to `sip:assistant@...`.

The resulting SIP config includes:

```dart
trunks: [
  SipTrunkConfig(
    id: 'easybell',
    direction: SipTrunkDirection.bidirectional,
    serverUri: 'sip:voip.easybell.de',
    username: 'YOUR_SIP_USERNAME',
    password: 'YOUR_SIP_PASSWORD',
    realm: 'voip.easybell.de',
  ),
]
```

It also disables the built-in registrar and local endpoint authentication:

```dart
features: SipFeatureFlags(
  registrar: false,
  authentication: false,
)
```

## Notes

- The example is trunk-first and does not host a local SIP registrar.
- Set `SIP_EXTERNAL_ADDRESS` when RTP needs a LAN or public address in SDP.
- The bridge sends SIP audio to Gemini as `16 kHz` PCM and downsamples Gemini
  `24 kHz` PCM audio to the SIP assistant format.
