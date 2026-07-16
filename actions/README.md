# GitHub Actions

This repository publishes reusable CI entry points for Dart Edge projects:

- `actions/setup_ci`: installs the precompiled `dart_edge_ci` helper and can
  optionally generate Dockerfiles, read package versions, set up Dart or
  Flutter, run `pub get`, or run a `dart_edge_ci` command.
- `actions/build_docker_image`: builds a single-platform, loadable Docker image
  archive and exposes its local path to later steps in the same job.
- `actions/deploy_docker`: uploads deployment files and an optional local Docker
  image archive over SSH, then runs the configured remote Compose command.
- `.github/workflows/build-flutter-image.yml`: reusable workflow that builds and
  publishes a Flutter web Docker image to GitHub Container Registry.
- `.github/workflows/deploy-docker.yml`: reusable workflow that copies Compose
  configuration and optionally a built image to an SSH deployment target.

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
      output: ghcr
      environment: release
```

Required inputs:

- `package_path`: package whose `pubspec.yaml` provides the image version
- `image`: image key under `images:` in `docker.yaml`
- `image_name`: GHCR image name without registry or owner
- `cache_scope`: GitHub Actions cache scope for Docker layers

Optional inputs:

- `platforms`: Docker platforms, default `linux/amd64`
- `environment`: GitHub environment that supplies variables and secrets,
  disabled by default
- `ssh_host`, `ssh_port`, and `ssh_username`: explicit SSH values for
  `ssh-upload`; when omitted, the workflow reads `SSH_HOST`, `SSH_PORT`, and
  `SSH_USERNAME` from the selected environment

The workflow publishes:

- `ghcr.io/<owner>/<image_name>:<version-tag>`
- `ghcr.io/<owner>/<image_name>:latest`
- `ghcr.io/<owner>/<image_name>:sha-<commit-sha>`

Set the Flutter base image version in `docker.yaml` with `flutter_version` at
the root or image level.

## Deploy Docker

Use the composite build and deploy actions when deployment credentials belong
to an environment in the calling repository. Because both actions run as steps
in a normal job, the job can bind that environment and keep the image archive
on one runner:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: web-deploy
    permissions:
      actions: read
      contents: read
      packages: read
    steps:
      - uses: actions/checkout@v5

      - id: build
        uses: hipposphere/dart_edge/actions/build_docker_image@main
        with:
          package_path: app
          image: app
          image_name: my-app
          cache_scope: my-app

      - uses: hipposphere/dart_edge/actions/deploy_docker@main
        with:
          source: app/compose.yaml
          target: /opt/my-app
          ssh_host: ${{ vars.SSH_HOST }}
          ssh_port: ${{ vars.SSH_PORT || '22' }}
          ssh_username: ${{ vars.SSH_USERNAME }}
          ssh_key: ${{ secrets.SSH_KEY }}
          image_archive: ${{ steps.build.outputs.archive_path }}
```

The composite action accepts `ssh_password` as an alternative to `ssh_key`, and
`env_file` for secret environment-file contents. Secret values must always be
passed from the calling job; composite actions do not acquire secrets
implicitly.

## Reusable deployment workflow

The reusable workflow remains available for callers that pass repository or
organization configuration explicitly:

```yaml
jobs:
  deploy:
    uses: hipposphere/dart_edge/.github/workflows/deploy-docker.yml@main
    with:
      source: app/compose.yaml
      target: /opt/my-app
      ssh_host: ${{ vars.SSH_HOST }}
      ssh_port: ${{ vars.SSH_PORT || '22' }}
      ssh_username: ${{ vars.SSH_USERNAME }}
    secrets:
      SSH_KEY: ${{ secrets.SSH_KEY }}
```

Use the composite action instead when the values are environment-scoped in the
calling repository. GitHub does not let a job both bind an environment and call
a reusable workflow directly.
