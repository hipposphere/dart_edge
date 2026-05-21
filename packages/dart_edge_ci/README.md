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
      renderer: auto
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

## GitHub Actions

```yaml
jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: dart-lang/setup-dart@v1
      - uses: docker/setup-buildx-action@v3
      - run: dart pub get
      - run: dart run dart_edge_ci docker generate
      - run: docker buildx bake -f .dart_tool/dart_edge_ci/docker/docker-bake.hcl --push
```

## Migrating From Hand-Written Dockerfiles

1. Move repeated image settings into `docker.yaml`.
2. Run `dart run dart_edge_ci docker generate`.
3. Inspect `.dart_tool/dart_edge_ci/docker/<image>/Dockerfile`.
4. Compare the generated image locally with `dart run dart_edge_ci docker build <image>`.
5. Replace CI Dockerfile references with the generated bake file.

Use `docker.yaml` as the source of truth. Generated Dockerfiles stay under
`.dart_tool/dart_edge_ci/docker/` and should not be committed.
