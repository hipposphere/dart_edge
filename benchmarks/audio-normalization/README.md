# Audio Normalization Benchmark

Measures `dart_edge_audio` probe and normalization latency plus `dart_edge_vad`
Silero detection and WAV trimming latency for real cached audio fixtures across
MP3, AAC, WAV, M4A, FLAC, and OGG inputs.

Prepare fixtures once:

```sh
cd packages/dart_edge_audio
dart run tool/download_audio_fixtures.dart
```

Run the benchmark:

```sh
cd benchmarks/audio-normalization/runner
dart run bin/run.dart \
  --iterations=10 \
  --warmups=2 \
  --concurrency=1 \
  --json-out=latest.json
```

Increase `--concurrency` to measure concurrent in-memory audio jobs on the
warmed native audio pool.
