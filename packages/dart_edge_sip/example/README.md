# Gemini Live Phone Assistant Example

This example runs `dart_edge_sip` as a small inbound SIP server and routes each
incoming call into a Gemini Live audio session.

The example is implemented in
`example/gemini_live_phone_assistant.dart`.

## What It Does

- listens for inbound SIP calls on UDP and TCP
- runs a local SIP registrar with a default test endpoint
- auto-answers calls sent to the configured assistant URI user
- plays a short local startup jingle through SIP/RTP before Gemini is ready
- uses `googleai_dart` to connect to Gemini Live
- streams inbound call audio to Gemini Live as `16 kHz` PCM through the SDK
- down-samples Gemini Live `24 kHz` audio output back to the
  `16 kHz` `dart_edge_sip` assistant media format
- clears queued playback when Gemini reports an interruption

## Prerequisites

- `pjproject` installed and visible through `pkg-config`
- a Gemini API key with Live API access
- a desktop SIP softphone on the same machine or LAN

One practical desktop client is Linphone Desktop. Its current desktop docs show
that it can place calls to SIP URIs directly, including from the command line
via a `sip:` URI or `linphone "call sip-address=..."`.

## Environment

Required:

- `GEMINI_API_KEY`

Optional:

- `GEMINI_LIVE_MODEL`
  Default: `gemini-3.1-flash-live-preview`
- `GEMINI_VOICE_NAME`
  Default: `Kore`
- `PHONE_ASSISTANT_SYSTEM_PROMPT`
- `PHONE_ASSISTANT_INITIAL_PROMPT`
- `PHONE_ASSISTANT_JINGLE_SECONDS`
  Default: `3`. Set to `0` to disable the local startup jingle.
- `SIP_BIND_HOST`
  Default: `0.0.0.0`
- `SIP_BIND_PORT`
  Default: `5060`
- `SIP_TEST_HOST`
  Default: `127.0.0.1`
- `SIP_REALM`
  Default: the `SIP_TEST_HOST` value
- `SIP_ASSISTANT_USER`
  Default: `assistant`
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
  reachable host or IP

## Start The Example

From the repo root:

```sh
export GEMINI_API_KEY='your-api-key'
export SIP_BIND_HOST='0.0.0.0'
export SIP_BIND_PORT='5060'
dart run packages/dart_edge_sip/example/gemini_live_phone_assistant.dart
```

On startup the example prints the direct SIP URI to call, for example:

```text
sip:assistant@127.0.0.1:5060
```

It also prints registrar settings for a test softphone account:

```text
Registrar: 127.0.0.1:5060 (realm 127.0.0.1)
Test endpoint: 1000 / change-me
Registered endpoint call URI: sip:assistant@127.0.0.1
```

## Test From Your PC

### Option 1: Register Linphone Desktop

1. Start the example.
2. Open Linphone Desktop on the same computer.
3. Add a SIP account with these settings:
   - username/user ID: `1000`
   - password: `change-me`
   - domain/realm: `127.0.0.1`
   - proxy/server: `sip:127.0.0.1:5060`
4. Wait for a `SipRegistrationEvent` in the example logs.
5. Place a call to `sip:assistant@127.0.0.1`.
6. Speak after the call connects. The assistant should answer through Gemini
   Live audio.

Adjust the values if you changed `SIP_TEST_HOST`, `SIP_REALM`,
`SIP_TEST_USERNAME`, `SIP_TEST_PASSWORD`, or `SIP_BIND_PORT`.

### Option 2: Direct SIP URI Call

You can still call the assistant without registration:

```text
sip:assistant@127.0.0.1:5060
```

### Option 3: Use Linphone Desktop From The Command Line

If Linphone Desktop is installed and its CLI integration is available:

```sh
linphone "call sip-address=sip:assistant@127.0.0.1:5060"
```

Adjust the URI if you changed `SIP_ASSISTANT_USER`, `SIP_TEST_HOST`, or
`SIP_BIND_PORT`.

## Important Testing Notes

- The default registrar is intended for local testability. Change
  `SIP_TEST_PASSWORD` before exposing the example outside a private machine or
  LAN.
- If your softphone runs on a different machine, call the host or IP that can
  reach this example and set `SIP_EXTERNAL_ADDRESS` if RTP needs a public or
  LAN-facing address.
- Allow the SIP signaling port and RTP port range through the local firewall.
- Gemini Live input is sent as raw `16 kHz` PCM and audio output comes back as
  raw `24 kHz` PCM, which this example down-samples before playback.
- The startup jingle is generated locally and does not require Gemini. If you
  hear it in Linphone, SIP signaling and RTP playback are working and remaining
  failures are in the Gemini Live setup or response path.

## Troubleshooting

- If the call rings but there is no audio, check microphone permissions in the
  softphone and confirm UDP RTP ports are reachable.
- If the example exits immediately, verify that `GEMINI_API_KEY` is present in
  the environment.
- If the Gemini Live SDK setup fails, confirm the selected model is enabled for
  your API key and that the key has Live API access.
- If the startup jingle plays but Gemini never produces audio, keep the call
  open until the example logs either `Gemini Live setup complete` or a
  timestamped setup error.
