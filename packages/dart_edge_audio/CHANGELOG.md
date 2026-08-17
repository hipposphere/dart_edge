## Unreleased

## 0.3.17

- Add codec-neutral `AudioOutputSpec` conversion targets while preserving the
  legacy WAV `AudioTargetFormat` API.
- Add in-memory M4A/AAC-LC encoding with a configurable target bitrate through
  a statically linked FFmpeg library backend; no subprocesses or temporary
  files are used.
- Add in-memory FFmpeg FLAC encoding with configurable compression.
- Support compressed output from byte conversion, file conversion, native
  stream concatenation, and pooled PCM16 streaming sessions.
- Bump the native artifact version to 0.1.15 for the new encoder backends and
  build bundled FFmpeg for the portable target baseline.

## 0.3.16

- Add transient native-audio memory reservations that participate in the
  shared pool spool ceiling.
- Report current and peak transient reservations for bounded VAD look-behind
  and other external native audio buffers.

## 0.3.15

- Add `NativeAudioPcm16StreamSession` for consuming single-owner transport
  leases into a bounded native PCM buffer and sealing them as a transferable
  native WAV stream.
- Support zero-copy protocol-envelope slicing, optional resampling, and channel
  remixing when the stream is finalized.
- Add configurable memory and adaptive audio spool policies. Adaptive spooling
  remains memory-only and never implicitly enables disk writes.
- Finish PCM sessions through the bounded native audio pool and expose global
  spool limits plus current, peak, and queued-byte metrics.
- Add typed spool-limit errors, remaining-capacity reporting, abandoned-session
  cleanup, and fallible native PCM buffer growth.
- Borrow native transport lease pointers directly while retaining a safe
  copying fallback for Dart-backed leases.
- Bump the native artifact version to 0.1.12 for the pooled finishing ABI.

## 0.3.14

- Add a stateful native PCM16LE waveform session for generating compact peaks
  while audio arrives, including a borrowed-pointer input path that avoids
  Dart-side chunk allocation and copies.
- Bump the native artifact version to 0.1.10 for the streaming waveform ABI.

## 0.3.13

- Generate optional signed, multi-resolution waveform peaks while native WAV
  conversion writes samples, without an additional decoded-audio pass.
- Add waveform-only analysis for upload paths that do not need converted WAV
  bytes in the Dart heap.
- Keep concatenated WAV output in native memory and expose it as a transferable
  native stream instead of using anonymous temporary-file storage.
- Bump the native artifact version to 0.1.9 for the waveform result ABI.

## 0.3.12

- Add native audio-stream normalization and concatenation with anonymous
  temporary-file output and transferable native response bodies.
- Bump the native artifact version to 0.1.8 for the stream concatenation ABI.

## 0.3.7

- Add a native audio worker pool for in-memory probe and conversion jobs.
- Route `DartEdgeAudio.initialize()` through the native pool so warmed bytes
- Remove the legacy Dart worker path so audio APIs use the native pool.
- Bump the native artifact version to 0.1.5 for the native pool ABI.

## 0.3.6

- Add `DartEdgeAudio.initialize()` for warming audio probing/conversion before
  latency-sensitive requests.

## 0.3.4

- Bump the native artifact version to 0.1.3 for Rust 1.95 and dependency
  updates.

## 0.3.3

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2.

## 0.3.2

- Publish Linux arm64 native artifacts.

## 0.3.1

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
