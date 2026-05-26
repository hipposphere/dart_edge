# dart_edge_ci

CI utilities for Dart Edge and Hipposphere workspaces. The first feature is
reusable Docker image generation.

Projects define Docker images in `docker.yaml`; `dart_edge_ci docker` writes
inspectable Dockerfiles and a Docker Bake file under
`.dart_tool/dart_edge_ci/docker/`.
Generated files are deterministic build artifacts and do not need to be
committed.

## Commands

```sh
dart run dart_edge_ci docker generate
dart run dart_edge_ci docker generate server
dart run dart_edge_ci docker build server
dart run dart_edge_ci docker build --push server
dart run dart_edge_ci docker bake
dart run dart_edge_ci docker print-config
dart run dart_edge_ci package-version packages/server
dart run dart_edge_ci test routes --suite packages/my_test_suite --base-url http://localhost:3000
dart run dart_edge_ci test e2e --suite packages/my_test_suite --compose-file environment/compose.yaml
dart run dart_edge_ci bench server --url http://localhost:3000/ --duration 30 --concurrency 32
```

`build` prints the generated Dockerfile path and the exact
`docker buildx build` command. If Docker fails, both are printed again with the
failure.

## Basic Server Image

```yaml
source: https://github.com/hipposphere/my-product
flutter_version: 3.44.0

images:
  server:
    type: dart_server
    package: server
    target: bin/main.dart
    executable: main
    expose: 3000
    title: My Product Server
    description: My Product API server
    presets:
      pjproject:
        version: 2.17
```

The server template uses a Flutter SDK builder image, runs `flutter pub get` at
the workspace root, builds the package with:

```sh
dart build cli --target=bin/main.dart --output=/app/build-output
```

The runtime image is `debian:trixie-slim` with a non-root user and minimal
runtime libraries. `presets.pjproject: true` or
`presets.pjproject.version: 2.17` adds a pjproject build stage and runtime
`LD_PRELOAD` for SIP/native audio stacks.

## Dockerfile Extension Snippets

Use first-class presets for common behavior. For uncommon native
dependencies or product-specific setup, each image also accepts Dockerfile
snippet extension points:

```yaml
images:
  server:
    type: dart_server
    package: server
    target: bin/main.dart
    dockerfile:
      prelude:
        - |
          FROM debian:trixie-slim AS custom_native
          RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates
      build_before_pub_get:
        - COPY --from=custom_native /usr/local/lib/ /usr/local/lib/
      build_after_pub_get:
        - RUN dart run tool/prepare_native_assets.dart
      build_before_compile:
        - RUN ldconfig
      runtime_before_labels:
        - COPY --from=custom_native /usr/local/lib/*.so* /usr/local/lib/
```

Available hooks are `prelude`, `build_before_pub_get`,
`build_after_pub_get`, `build_before_compile`, and `runtime_before_labels`.
Snippets are emitted as-is into the generated Dockerfile, so keep them small and
inspect `.dart_tool/dart_edge_ci/docker/<image>/Dockerfile` after generation.

## DB Migrator Image

```yaml
images:
  migrator:
    type: db_migrator
    package: packages/db_migrator
    target: bin/migrator.dart
    executable: migrator
    title: My Product Migrator
    description: Database migrator
    databases:
      sqlite: true
      postgres: true
      pglite: false
```

`databases.all: true` enables all current database runtime dependencies.

The database dependency mapping currently lives in `dart_edge_ci` because
`dart_edge_sql_migrator` does not yet expose container runtime presets. The
`docker.yaml` shape is intentionally stable so those presets can later be
delegated without changing product repos.

## Flutter Web App Image

```yaml
images:
  app:
    type: flutter_app
    package: app
    flutter_version: 3.44.0
    web:
      wasm: true
      base_href_env: BASE_HREF
    nginx:
      env:
        required:
          - API_URL
        optional:
          BASE_HREF: /
    title: My Product App
    description: Flutter web frontend
```

The Flutter template builds web release output, serves it with
`nginx:1.29-alpine`, generates an Nginx entrypoint that validates required env
vars, writes `/usr/share/nginx/html/.env`, writes
`/usr/share/nginx/html/env-url.js`, patches `<base href>`, and creates the
Nginx config at container startup.

Flutter bootstrapping assets, manifest icons, and font assets are cache-busted
using the image revision when available, or a content hash fallback.

For FVM projects, pin the same Flutter version in FVM and `docker.yaml`; the
package itself runs under normal Dart.

## OCI Labels And Build Args

Every generated Dockerfile supports:

```text
VERSION
REVISION
CREATED
SOURCE
```

and emits:

```text
org.opencontainers.image.title
org.opencontainers.image.description
org.opencontainers.image.version
org.opencontainers.image.revision
org.opencontainers.image.created
org.opencontainers.image.source
```

Image version is read from the configured package's `pubspec.yaml`.
Set top-level `vendor` in `docker.yaml` if you want
`org.opencontainers.image.vendor` emitted.

## Docker Bake

```sh
dart run dart_edge_ci docker bake
docker buildx bake -f .dart_tool/dart_edge_ci/docker/docker-bake.hcl
docker buildx bake -f .dart_tool/dart_edge_ci/docker/docker-bake.hcl --push
```

The generated bake file has one target per image and points Docker at the repo
root as the build context.

## Package Version Helper

Use `package-version` in CI when you need the package version and a tag-safe
variant:

```sh
dart run dart_edge_ci package-version packages/server
```

Output:

```text
version=1.2.3+45
version_tag=v1.2.3-45
```

The tag is prefixed with `v` and replaces build metadata `+` with `-`.

For GitHub Actions:

```yaml
- name: Read package version
  id: package
  run: dart run dart_edge_ci package-version --github-output packages/server
```

JSON output is also available:

```sh
dart run dart_edge_ci package-version --json packages/server
```

## Route And E2E Test Suites

Project repos can keep product-specific test scenarios in a standalone package
and let `dart_edge_ci` handle the repeated CI mechanics:

```sh
dart run dart_edge_ci test routes \
  --suite packages/my_test_suite \
  --base-url http://localhost:3000 \
  --compose-file environment/compose.yaml
```

The command starts the optional Docker Compose environment, waits for the health
URL, runs `dart test` inside the suite package, and tears the environment down
again. `--base-url` is passed to tests as `TEST_BASE_URL`. Extra `dart test`
arguments can be appended after `--`.

`test e2e` uses the same options and defaults to `test/e2e` inside the suite
package. `test env up` and `test env down` are available when CI or local
debugging needs to manage the compose stack separately.

## Server Benchmarks

`bench server` runs a lightweight HTTP throughput benchmark that is stable
enough for trend tracking without adding a separate load-testing runtime:

```sh
dart run dart_edge_ci bench server \
  --url http://localhost:3000/ \
  --compose-file environment/compose.yaml \
  --container my-server \
  --duration 60 \
  --warmup 10 \
  --concurrency 64 \
  --output build/reports/bench/server.json \
  --github-summary
```

The JSON report includes request count, error count, throughput, p50/p95/p99
latency, status codes, and optional Docker CPU/memory samples from
`docker stats`. Use `--max-p95-latency-ms` and `--min-throughput` only for
stable runners; otherwise publish the report as a non-blocking artifact and use
nightly runs for regression tracking.

## GitHub Actions

`dart_edge_ci` is distributed to GitHub Actions as precompiled AOT release
assets. The action downloads the matching binary for the runner platform, caches
it with `actions/cache`, adds it to `PATH`, and then optionally runs a
`dart_edge_ci` command, generates a Dockerfile, or reads package version
metadata and exposes the results as
action output.

```yaml
jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - id: dart-edge-ci
        uses: hipposphere/dart_edge/actions/setup_ci@v0.1.0
        with:
          docker-image: server
          package-version-path: packages/server

      - name: Build image
        run: |
          docker build \
            --file "${{ steps.dart-edge-ci.outputs.dockerfile }}" \
            --tag "ghcr.io/hipposphere/my-product-server:${{ steps.dart-edge-ci.outputs.version-tag }}" \
            "${{ steps.dart-edge-ci.outputs.context }}"
```

The action version selects the `dart_edge_ci` binary. It does not force a Dart
or Flutter version onto the consuming project. `docker-image` is the image name
under `images:` in `docker.yaml`. The `dockerfile`, `context`, `version`, and
`version-tag` outputs can be passed to any later publish/build action.

You can still run any command manually:

```yaml
- uses: hipposphere/dart_edge/actions/setup_ci@v0.1.0
  with:
    command: docker print-config
```

If the project needs dependency resolution before running the command, opt into
SDK setup explicitly:

```yaml
- uses: hipposphere/dart_edge/actions/setup_ci@v0.1.0
  with:
    setup-dart: "true"
    dart-version: 3.12.0
    pub-get: "true"
    docker-image: server
    package-version-path: packages/server
```

Flutter projects can opt into Flutter instead:

```yaml
- uses: hipposphere/dart_edge/actions/setup_ci@v0.1.0
  with:
    setup-flutter: "true"
    flutter-version: 3.44.0
    pub-get: "true"
    docker-image: app
    package-version-path: packages/app
```

For local actions or branch refs where the release tag cannot be inferred,
provide the binary version directly:

```yaml
- uses: hipposphere/dart_edge/actions/setup_ci@main
  with:
    version: 0.1.0
    command: docker print-config
```

## Releasing The GitHub Action Binary

Tag a release with `v<version>` where `<version>` matches
`packages/dart_edge_ci/pubspec.yaml`, or run the `dart_edge_ci` workflow
manually. The workflow uses `dart-lang/setup-dart` with the stable Dart SDK,
compiles `bin/dart_edge_ci.dart` with `dart compile exe`, and uploads one
release asset per runner platform:

```text
dart_edge_ci-<version>-linux-x64
dart_edge_ci-<version>-linux-arm64
dart_edge_ci-<version>-macos-arm64
dart_edge_ci-<version>-windows-x64.exe
```

## Migrating From Hand-Written Dockerfiles

1. Move repeated image settings into `docker.yaml`.
2. Run `dart run dart_edge_ci docker generate`.
3. Inspect `.dart_tool/dart_edge_ci/docker/<image>/Dockerfile`.
4. Compare the generated image locally with `dart run dart_edge_ci docker build <image>`.
5. Replace CI Dockerfile references with the generated bake file.

Use `docker.yaml` as the source of truth. Generated Dockerfiles stay under
`.dart_tool/dart_edge_ci/docker/` and should not be committed.
