# Callo Engine

Callo Engine is an example SIP audio engine that answers inbound SIP calls and
bridges the call audio to Gemini Live.

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
- a SIP softphone such as Linphone Desktop

## Start

From the package directory:

```sh
cd examples/callo_engine
dart run bin/callo_engine.dart --gemini-api-key 'your-api-key'
```

Or use the environment:

```sh
cd examples/callo_engine
export GEMINI_API_KEY='your-api-key'
dart run bin/callo_engine.dart
```

The engine prints the direct SIP URI and the local registrar settings on
startup. With defaults, call:

```text
sip:assistant@127.0.0.1:5060
```

## Configuration

Required:

- `GEMINI_API_KEY`, unless `--gemini-api-key` is passed

Optional:

- `GEMINI_LIVE_MODEL`
  Default: `gemini-3.1-flash-live-preview`
- `GEMINI_VOICE_NAME`
  Default: `Kore`
- `CALLO_SYSTEM_PROMPT`
- `CALLO_INITIAL_PROMPT`
- `CALLO_JINGLE_SECONDS`
  Default: `3`. Set to `0` to disable the local startup jingle.
- `CALLO_ASSISTANT_USER`
  Default: `assistant`
- `SIP_BIND_HOST`
  Default: `0.0.0.0`
- `SIP_BIND_PORT`
  Default: `5060`
- `SIP_TEST_HOST`
  Default: `127.0.0.1`
- `SIP_REALM`
  Default: the `SIP_TEST_HOST` value
- `SIP_TEST_ENDPOINT_ID`
  Default: `test-phone`
- `SIP_TEST_EXTENSION`
  Default: `1000`
- `SIP_TEST_USERNAME`
  Default: the `SIP_TEST_EXTENSION` value
- `SIP_TEST_PASSWORD`
  Default: `change-me`
- `SIP_RTP_START_PORT`
  Default: `40000`
- `SIP_RTP_END_PORT`
  Default: `40100`
- `SIP_EXTERNAL_ADDRESS`
  Useful when the softphone is on another machine and RTP must advertise a
  reachable host or IP.

The older `PHONE_ASSISTANT_SYSTEM_PROMPT`,
`PHONE_ASSISTANT_INITIAL_PROMPT`, and `PHONE_ASSISTANT_JINGLE_SECONDS`
environment names are still accepted as fallbacks.

## Calling From A Softphone

Direct SIP call:

```text
sip:assistant@127.0.0.1:5060
```

Local registrar defaults:

```text
Username / User ID: 1000
Password: change-me
Domain / Realm: 127.0.0.1
Proxy / Registrar / Server: sip:127.0.0.1:5060
Transport: UDP
```

After registration, place a call to:

```text
sip:assistant@127.0.0.1
```

## Notes

- The default registrar credentials are for local testing only.
- If the softphone runs on another machine, set `SIP_TEST_HOST` to the host
  callers use and set `SIP_EXTERNAL_ADDRESS` when RTP needs a LAN or public
  address.
- The bridge sends SIP audio to Gemini as `16 kHz` PCM and downsamples Gemini
  `24 kHz` PCM audio to the SIP assistant format.
