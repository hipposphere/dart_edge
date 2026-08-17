# Dart Edge

Dart Edge is a Dart-first backend platform built around:

- a Rust-backed HTTP runtime
- explicit route and schema contracts
- build-time code generation
- focused native service packages for backend concerns such as auth, SQL,
  audio, and SIP/telephony

This repository is a Pub workspace. The app-facing default package is
[`package:dart_edge_http_server`](packages/dart_edge_http_server), while the workspace also contains the
lower-level core contracts, runtime, codegen, auth, SQL, audio, and benchmark
packages.

The current delivered center is HTTP. The HTTP codegen package exposes
annotations, normalized route artifact generation, schema registry generation,
runtime codec registry skeletons, and client-generation pieces. A full
analyzer-backed builder remains a later layer. WebSocket routes are also
supported by the runtime, including text, JSON, binary frames, and native
single-owner binary leases for allocation-sensitive streaming paths.

## Quick Start

Requirements:

- Dart `>=3.13.0 <4.0.0`
- Rust toolchain when working on native-backed packages such as
  `dart_edge_http_server_runtime`, `dart_edge_auth`, `dart_edge_sql`,
  `dart_edge_audio`, `dart_edge_s3_client`, or `dart_edge_sip`
- `pjproject` is required by `dart_edge_sip`; source builds also need
  `pkg-config` so the native bridge can find PJSIP headers

Resolve the workspace:

```sh
dart pub get
```

Run the main application example:

```sh
cd packages/dart_edge_http_server
dart run example/simple_http_server.dart
```

That example starts a Rust-backed HTTP server, mounts OpenAPI JSON and Swagger
UI helpers, and shows manual schema and codec registration.

## Default App Shape

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

Future<void> main() async {
  final app = DartEdge<AppServices>(services: AppServices.new);

  app.get('/health', handler: (_) => const {'status': 'ok'});
  OpenApiHelpers.mountJson(app, path: '/openapi.json');

  await app.listen(host: '0.0.0.0', port: 8080);
}

final class AppServices {
  const AppServices();
}
```

For local-only development, `listen(port: 8080)` still binds loopback. For
deployment, pass a real bind address such as `0.0.0.0` or `::`.

Import `package:dart_edge_http_server/dart_edge_http_server.dart` when you want the normal developer
experience: the shared contracts from `dart_edge_core`, the concrete runtime
surface from `dart_edge_http_server_runtime`, and app-facing helper APIs such as
`OpenApiHelpers`.

## WebSocket Frames

WebSocket handlers receive the normal handshake request input and a typed
message stream. Use `messages.json<T>()` for JSON text protocols,
`messages.text()` for raw text frames, `messages.binary()` for binary-only
streams, or `messages.frames()` when a route accepts mixed frame types.

```dart
app.websocket('/audio', onConnect: (socket) async {
  await socket.sendJson({'ready': true});

  await for (final bytes in socket.messages.binary()) {
    await socket.sendBinary(bytes);
  }
});
```

Use `messages.leasedBinary()` when a native consumer should receive the frame
without first copying it into Dart-managed memory. WebTransport provides the
same opt-in path through `datagrams.leases()` and `streams.leases()`. Text and
JSON control messages continue to use the normal APIs on the same connection.

## Workspace Layout

- [`packages/dart_edge_http_server`](packages/dart_edge_http_server): app-facing HTTP server package for application
  authors, including OpenAPI JSON and Swagger UI mounting helpers
- [`packages/dart_edge_core`](packages/dart_edge_core): transport-agnostic
  route, request/response, schema, WebSocket, and router contracts
- [`packages/dart_edge_http_server_runtime`](packages/dart_edge_http_server_runtime): Rust-backed HTTP
  runtime that consumes the shared contracts and owns native transport
  integration
- [`packages/dart_edge_http_server_codegen`](packages/dart_edge_http_server_codegen): build-time HTTP route
  generation, normalized metadata, generated route artifacts, schema registries,
  codec registry skeletons, and generated HTTP client support
- [`packages/dart_edge_auth`](packages/dart_edge_auth): Better Auth route
  integration for Dart Edge apps
- [`packages/dart_edge_sql`](packages/dart_edge_sql): native-backed typed SQL
  pools and query builders
- [`packages/dart_edge_sql_pglite`](packages/dart_edge_sql_pglite): embedded
  PGlite PostgreSQL endpoint for local servers and tests
- [`packages/dart_edge_sql_pgrust`](packages/dart_edge_sql_pgrust): managed
  experimental pgrust endpoint for disposable compatibility and performance
  experiments
- [`packages/dart_edge_sql_codegen`](packages/dart_edge_sql_codegen): database
  introspection and Dart descriptor generation
- [`packages/dart_edge_sql_migrator`](packages/dart_edge_sql_migrator): SQL
  migration management on top of `dart_edge_sql`
- [`packages/dart_edge_native_bridge`](packages/dart_edge_native_bridge):
  shared Dart FFI structs and pointer helpers used by native-backed packages
- [`packages/dart_edge_audio`](packages/dart_edge_audio): native-backed audio
  probing and WAV conversion utilities
- [`packages/dart_edge_openai_audio_client`](packages/dart_edge_openai_audio_client):
  native-backed OpenAI-compatible audio transcription client with direct
  native byte-stream consumption
- [`packages/dart_edge_s3_client`](packages/dart_edge_s3_client): native-backed
  S3 client for AWS S3 and compatible object stores with owned-bytes transfer
  support
- [`packages/dart_edge_sip`](packages/dart_edge_sip): standalone PJSIP-backed
  SIP/telephony runtime foundation for backend-controlled VoIP call handling
- [`benchmarks`](benchmarks): reproducible benchmark workspace comparing Dart
  Edge against other server runtimes

## Repo-Wide Commands

Resolve the whole workspace:

```sh
dart pub get
```

List workspace packages:

```sh
dart pub workspace list
```

Analyze the whole repo:

```sh
dart analyze
```

Check package boundaries:

```sh
dart --disable-dart-dev tool/check_package_boundaries.dart
```

Format the repo:

```sh
dart format .
```

Test one package:

```sh
cd packages/<package>
dart test
```

Run the runtime native probe:

```sh
cd packages/dart_edge_http_server_runtime
dart run example/native_probe.dart
```

## Benchmarks

The current HTTP benchmark suite in
[`benchmarks/basic-http-server`](benchmarks/basic-http-server/README.md)
compares the real `DartEdge.listen()` server path against:

- `package:shelf_router`
- Express
- Fastify
- axum

Run the benchmark suite:

```sh
dart pub -C benchmarks/basic-http-server/runner run bin/run.dart
```

See [`benchmarks/basic-http-server/README.md`](benchmarks/basic-http-server/README.md)
for targets, scenarios, external dependencies, and methodology.

## Docs

- [`CONCEPT.md`](CONCEPT.md): product and architecture direction for the repo
- package-level READMEs under [`packages/`](packages)
- benchmark documentation in [`benchmarks/README.md`](benchmarks/README.md)

## Development Notes

- The repo uses a Pub workspace rooted at the repository root.
- First-party packages live under `packages/`.
- Benchmark packages live under `benchmarks/`.
- Keep `dart_edge_http_server` as the default app-facing package.
- Keep transport-agnostic route, request/response, schema, WebSocket, and router
  contracts in `dart_edge_core`.
- Keep helper-only APIs out of `dart_edge_http_server_runtime`.
- Keep app-facing schema annotations in `dart_edge_core` and export them through
  `dart_edge_http_server`.
- Keep shared Dart FFI structs and pointer helpers in
  `dart_edge_native_bridge`, not in `dart_edge_core`.
- Keep generator-facing APIs in `dart_edge_http_server_codegen`.

For lower-level package details, use the package-local READMEs. The root README
should stay focused on the overall platform, workspace shape, and the default
developer path.
