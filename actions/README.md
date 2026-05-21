# GitHub Actions

This repository publishes two CI entry points for Dart Edge projects:

- `actions/setup_ci`: installs the precompiled `dart_edge_ci` helper and can
  optionally generate Dockerfiles, read package versions, set up Dart or
  Flutter, run `pub get`, or run a `dart_edge_ci` command.
- `.github/workflows/build-flutter-image.yml`: reusable workflow that builds and
  publishes a Flutter web Docker image to GitHub Container Registry.

## Set up dart_edge_ci

Use this action when a workflow needs the `dart_edge_ci` binary or generated
Docker metadata.

```yaml
steps:
  - uses: actions/checkout@v5

  - id: dart-edge-ci
    uses: hipposphere/dart_edge/actions/setup_ci@v0.1.0
    with:
      docker-image: app
      package-version-path: packages/app
```

The action exposes these useful outputs when the matching inputs are set:

- `dockerfile`: generated Dockerfile path
- `context`: Docker build context path
- `version`: package version from `pubspec.yaml`
- `version-tag`: tag-safe package version

Flutter projects can opt into Flutter setup and dependency resolution:

```yaml
- uses: hipposphere/dart_edge/actions/setup_ci@v0.1.0
  with:
    setup-flutter: "true"
    flutter-version: 3.44.0
    pub-get: "true"
    docker-image: app
    package-version-path: packages/app
```

For branch refs where the action version cannot be inferred from a release tag,
pin the helper binary explicitly:

```yaml
- uses: hipposphere/dart_edge/actions/setup_ci@main
  with:
    version: 0.1.0
    command: docker print-config
```

## Build Flutter Image

Use the reusable workflow when a repository wants to publish a Flutter web image
generated from its `docker.yaml`.

```yaml
name: Publish app image

on:
  push:
    branches:
      - main
    tags:
      - "v*"

jobs:
  app-image:
    uses: hipposphere/dart_edge/.github/workflows/build-flutter-image.yml@v0.1.0
    with:
      package_path: packages/app
      image: app
      image_name: my-app
      cache_scope: my-app
      platforms: linux/amd64
```

Required inputs:

- `package_path`: package whose `pubspec.yaml` provides the image version
- `image`: image key under `images:` in `docker.yaml`
- `image_name`: GHCR image name without registry or owner
- `cache_scope`: GitHub Actions cache scope for Docker layers

Optional inputs:

- `platforms`: Docker platforms, default `linux/amd64`

The workflow publishes:

- `ghcr.io/<owner>/<image_name>:<version-tag>`
- `ghcr.io/<owner>/<image_name>:latest`
- `ghcr.io/<owner>/<image_name>:sha-<commit-sha>`

Set the Flutter base image version in `docker.yaml` with `flutter_version` at
the root or image level.
