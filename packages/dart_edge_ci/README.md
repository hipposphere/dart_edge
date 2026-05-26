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
dart run dart_edge_ci flutter build ios_app_store
dart run dart_edge_ci flutter build --all --dry-run
dart run dart_edge_ci flutter publish ios-app-store --target ios_app_store
dart run dart_edge_ci flutter artifact-paths android_play_store
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

## Flutter Release Builds

`dart_edge_ci flutter` provides reusable Flutter release build orchestration for
Hipposphere product workspaces. Projects define named build targets in
`flutter_release.yaml`; each target declares its platform so a product can have
multiple release targets for the same platform with different flavors, define
files, or publishing settings.

```yaml
package: app
flutter: flutter
build_mode: release
pub_get: true
dart_define_from_file: ../.local.env.json

targets:
  macos_release:
    platform: macos
    dart_define_from_file:
      - ../macos.env.json
    signing:
      enabled: true
      required_env:
        - MACOS_CERTIFICATE
        - MACOS_CERTIFICATE_PASSWORD

  windows_release:
    platform: windows
    signing:
      enabled: true
      required_env:
        - WINDOWS_SIGNING_CERTIFICATE
        - WINDOWS_SIGNING_CERTIFICATE_PASSWORD

  linux_release:
    platform: linux
    enabled: true

  web_release:
    platform: web
    build_args:
      - --wasm

  ios_app_store:
    platform: ios
    signing:
      enabled: true
      required_env:
        - IOS_DISTRIBUTION_CERTIFICATE_BASE64
        - IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
        - IOS_PROVISIONING_PROFILES_BASE64
    publish:
      app_store_connect:
        ipa: build/ios/ipa/*.ipa
        fastlane: bundle exec fastlane
        submit_for_review: false
        skip_metadata: true
        skip_screenshots: true
        api_key:
          key_id_env: APP_STORE_CONNECT_KEY_ID
          issuer_id_env: APP_STORE_CONNECT_ISSUER_ID
          private_key_env: APP_STORE_CONNECT_PRIVATE_KEY

  android_play_store:
    platform: android
    artifact: appbundle
    signing:
      enabled: true
      required_env:
        - ANDROID_UPLOAD_KEYSTORE_BASE64
        - ANDROID_UPLOAD_KEYSTORE_PASSWORD
```

Build one target:

```sh
dart run dart_edge_ci flutter build ios_app_store
```

Print the commands without executing them:

```sh
dart run dart_edge_ci flutter build --all --dry-run
```

Print default artifact upload paths for GitHub Actions:

```sh
dart run dart_edge_ci flutter artifact-paths ios_app_store
```

Upload a signed iOS IPA to App Store Connect:

```sh
dart run dart_edge_ci flutter signing ios --target ios_app_store
dart run dart_edge_ci flutter build ios_app_store
dart run dart_edge_ci flutter publish ios-app-store --target ios_app_store
```

The first release-build layer intentionally builds signed Flutter artifacts.
Packaging and publishing should be layered afterwards, for example DMG or PKG
on macOS, MSIX or installer EXE on Windows, Flatpak/AppImage/deb/rpm on Linux,
static hosting or container packaging for web, and store upload steps for iOS
and Android.

`dart_define_from_file` emits Flutter's native `--dart-define-from-file` build
arguments. It can be configured once at the top level for every platform, or per
target for additional files. A single string and a YAML list are both accepted.

`flutter signing ios` installs the base64-encoded iOS distribution certificate
and provisioning profiles from CI environment variables into a temporary
keychain and the standard Xcode provisioning profile directory. It expects
`IOS_DISTRIBUTION_CERTIFICATE_BASE64`,
`IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`,
`IOS_PROVISIONING_PROFILES_BASE64`, and `KEYCHAIN_PASSWORD`.

`flutter publish ios-app-store` resolves the configured IPA, writes a temporary
fastlane App Store Connect API key JSON under `.dart_tool/dart_edge_ci/`, runs
`fastlane deliver`, then deletes the temporary key file. Store submission is
disabled by default; set `submit_for_review: true` only for release workflows
that should immediately submit the uploaded build for review.

GitHub repositories can call the reusable iOS release workflow from dart_edge:

```yaml
jobs:
  release-ios:
    uses: hipposphere/dart_edge/.github/workflows/release-flutter-ios.yml@main
    with:
      target: ios_app_store
      publish: true
    secrets:
      APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
      APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
      APP_STORE_CONNECT_PRIVATE_KEY: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
      IOS_DISTRIBUTION_CERTIFICATE_BASE64: ${{ secrets.IOS_DISTRIBUTION_CERTIFICATE_BASE64 }}
      IOS_DISTRIBUTION_CERTIFICATE_PASSWORD: ${{ secrets.IOS_DISTRIBUTION_CERTIFICATE_PASSWORD }}
      IOS_PROVISIONING_PROFILES_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILES_BASE64 }}
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
