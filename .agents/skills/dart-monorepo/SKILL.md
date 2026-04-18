---
name: dart-monorepo
description: Use when working on the Dart Edge repository layout, adding or moving packages under packages/, adjusting root workspace configuration, or changing repo-wide Dart workspace conventions and commands.
---

# Dart Monorepo

This repository uses a Pub workspace rooted at the repo root.

## Default workflow

1. Keep all first-party packages under `packages/`.
2. Update the root `pubspec.yaml` workspace only if the package discovery rule
   changes.
3. Every workspace package must have:
   - its own `pubspec.yaml`
   - `environment.sdk: ">=3.11.0 <4.0.0"`
   - `resolution: workspace`
4. Prefer changes that keep `dart_edge` as the default app-facing package.

## Language baseline

- Design repo APIs for Dart 3.11 and later.
- Prefer dot shorthands, patterns, records, and modern class modifiers when
  they improve clarity.
- Do not introduce syntax that requires a language version above the repo floor
  unless the repo baseline is intentionally raised.

## Guardrails

- Do not add stray `pubspec.yaml` files between the repo root and a workspace
  package.
- Do not introduce a second monorepo tool unless the user explicitly asks for
  it.
- Keep package boundaries clear: runtime and shared contracts in
  `dart_edge_runtime`, helpers in `dart_edge_helpers`, build-time API in
  `dart_edge_codegen`.

## Commands

- Resolve workspace: `dart pub get`
- List workspace packages: `dart pub workspace list`
- Analyze workspace: `dart analyze`
- Format workspace: `dart format .`
