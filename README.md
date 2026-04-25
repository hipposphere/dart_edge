# Dart Edge

Dart Edge is a Dart-first backend platform built around:

- a Rust-backed HTTP runtime
- explicit route and schema contracts
- build-time code generation
- focused native service packages for backend concerns such as auth, SQL,
  audio, and SIP/telephony

This repository is a Pub workspace. The app-facing default package is
[`package:dart_edge_http_server`](packages/dart_edge_http_server), while the workspace also contains the
lower-level runtime, helper, codegen, auth, SQL, audio, and benchmark
packages.

The current delivered center is HTTP. The HTTP codegen package exposes
annotations, normalized route artifact generation, schema registry generation,
runtime codec registry skeletons, and client-generation pieces. A full
analyzer-backed builder remains a later layer. WebSocket contract types exist,
but WebSocket transport is not the shipped path yet.

## Quick Start

Requirements:

- Dart `>=3.11.0 <4.0.0`
- Rust toolchain when working on native-backed packages such as
  `dart_edge_http_server_runtime`, `dart_edge_auth`, `dart_edge_sql`,
  `dart_edge_audio`, `dart_edge_s3_client`, or `dart_edge_sip`
- `pjproject` plus `pkg-config` when building `dart_edge_sip`

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
experience: the runtime surface from `dart_edge_http_server_runtime` plus the helper APIs
from `dart_edge_helpers`.

## Workspace Layout

- [`packages/dart_edge_http_server`](packages/dart_edge_http_server): app-facing HTTP server package for application
  authors
- [`packages/dart_edge_http_server_runtime`](packages/dart_edge_http_server_runtime): Rust-backed HTTP
  runtime plus shared route, schema, and context contracts
- [`packages/dart_edge_helpers`](packages/dart_edge_helpers): helper-layer APIs
  such as OpenAPI JSON and Swagger UI mounting
- [`packages/dart_edge_http_server_codegen`](packages/dart_edge_http_server_codegen): build-time HTTP route
  annotations, normalized metadata, generated route artifacts, schema registries,
  codec registry skeletons, and generated HTTP client support
- [`packages/dart_edge_auth`](packages/dart_edge_auth): Better Auth route
  integration for Dart Edge apps
- [`packages/dart_edge_sql`](packages/dart_edge_sql): native-backed typed SQL
  pools and query builders
- [`packages/dart_edge_sql_codegen`](packages/dart_edge_sql_codegen): database
  introspection and Dart descriptor generation
- [`packages/dart_edge_sql_migrator`](packages/dart_edge_sql_migrator): SQL
  migration management on top of `dart_edge_sql`
- [`packages/dart_edge_audio`](packages/dart_edge_audio): native-backed audio
  probing and WAV conversion utilities
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
- Keep helper-only APIs out of `dart_edge_http_server_runtime`.
- Keep build-time HTTP annotations and generator-facing APIs in
  `dart_edge_http_server_codegen`.

For lower-level package details, use the package-local READMEs. The root README
should stay focused on the overall platform, workspace shape, and the default
developer path.
