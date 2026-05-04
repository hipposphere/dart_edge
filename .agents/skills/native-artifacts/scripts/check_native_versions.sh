#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-origin/main}"

if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  echo "Base ref '$base_ref' is not available." >&2
  exit 2
fi

changed_files="$(
  {
    git diff --name-only "$base_ref"...HEAD
    git diff --name-only
    git diff --cached --name-only
  } | sort -u
)"

if [[ -z "$changed_files" ]]; then
  echo "No changed files relative to $base_ref."
  exit 0
fi

native_input_changed_for_package() {
  local package="$1"
  local file

  while IFS= read -r file; do
    case "$file" in
      "packages/$package/rust/"*) return 0 ;;
      ".cargo/config.toml") return 0 ;;
      "crates/"*/src/*) return 0 ;;
      "crates/"*/build.rs) return 0 ;;
    esac
  done <<< "$changed_files"

  return 1
}

cargo_version_from_file() {
  sed -nE 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$1" | head -1
}

cargo_version_from_ref() {
  local ref="$1"
  local manifest="$2"
  git show "$ref:$manifest" 2>/dev/null \
    | sed -nE 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
    | head -1
}

failed=0

for manifest in packages/*/rust/Cargo.toml; do
  package="$(basename "$(dirname "$(dirname "$manifest")")")"

  if ! native_input_changed_for_package "$package"; then
    continue
  fi

  current_version="$(cargo_version_from_file "$manifest")"
  previous_version="$(cargo_version_from_ref "$base_ref" "$manifest")"

  if [[ -z "$previous_version" ]]; then
    echo "OK: $package is new or has no previous Cargo version."
    continue
  fi

  if [[ "$current_version" == "$previous_version" ]]; then
    echo "ERROR: native inputs changed for $package but Cargo version stayed $current_version." >&2
    failed=1
  else
    echo "OK: $package Cargo version changed $previous_version -> $current_version."
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "Native Cargo version check passed."
