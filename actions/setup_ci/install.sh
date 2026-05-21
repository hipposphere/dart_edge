#!/usr/bin/env bash
set -euo pipefail

repository="${DART_EDGE_CI_REPOSITORY:-hipposphere/dart_edge}"
version="${DART_EDGE_CI_VERSION:-}"
action_ref="${DART_EDGE_CI_ACTION_REF:-}"

if [[ -z "$version" ]]; then
  if [[ "$action_ref" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    version="$action_ref"
  fi
fi

if [[ -z "$version" ]]; then
  echo "::error::Set the dart_edge_ci action input 'version' when the action ref is not a release tag."
  exit 1
fi

case "$version" in
  v*)
    tag="$version"
    release_version="${version#v}"
    ;;
  *)
    tag="v$version"
    release_version="$version"
    ;;
esac

case "${RUNNER_OS:-}" in
  Linux) os="linux" ;;
  macOS) os="macos" ;;
  Windows) os="windows" ;;
  *)
    echo "::error::Unsupported runner OS: ${RUNNER_OS:-unknown}"
    exit 1
    ;;
esac

case "${RUNNER_ARCH:-}" in
  X64) arch="x64" ;;
  ARM64) arch="arm64" ;;
  *)
    echo "::error::Unsupported runner architecture: ${RUNNER_ARCH:-unknown}"
    exit 1
    ;;
esac

asset="dart_edge_ci-$release_version-$os-$arch"
binary_name="dart_edge_ci"
if [[ "$os" == "windows" ]]; then
  asset="$asset.exe"
  binary_name="dart_edge_ci.exe"
fi

install_dir="$RUNNER_TEMP/dart_edge_ci/bin"
if [[ -x "$install_dir/$binary_name" ]]; then
  echo "Using cached $binary_name"
  echo "$install_dir" >> "$GITHUB_PATH"
  "$install_dir/$binary_name" --help >/dev/null
  exit 0
fi

api_url="https://api.github.com/repos/$repository/releases/tags/$tag"

curl_with_auth() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
  else
    curl -fsSL "$@"
  fi
}

echo "Installing $asset from $repository release $tag"
release_json="$(curl_with_auth \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api_url")"

asset_url="$(DART_EDGE_CI_ASSET="$asset" python3 -c '
import json
import os
import sys

release = json.load(sys.stdin)
name = os.environ["DART_EDGE_CI_ASSET"]
for asset in release.get("assets", []):
    if asset.get("name") == name:
        print(asset["browser_download_url"])
        break
else:
    sys.exit(1)
' <<<"$release_json")" || {
  echo "::error::Release asset not found: $asset"
  exit 1
}

mkdir -p "$install_dir"
curl_with_auth -o "$install_dir/$asset" "$asset_url"
chmod +x "$install_dir/$asset"

sha_asset="$asset.sha256"
sha_url="$(DART_EDGE_CI_ASSET="$sha_asset" python3 -c '
import json
import os
import sys

release = json.load(sys.stdin)
name = os.environ["DART_EDGE_CI_ASSET"]
for asset in release.get("assets", []):
    if asset.get("name") == name:
        print(asset["browser_download_url"])
        break
' <<<"$release_json")"

if [[ -n "$sha_url" ]]; then
  curl_with_auth -o "$install_dir/$sha_asset" "$sha_url"
  (
    cd "$install_dir"
    shasum -a 256 -c "$sha_asset"
  )
fi

if [[ "$asset" != "$binary_name" ]]; then
  ln -sf "$asset" "$install_dir/$binary_name"
fi

echo "$install_dir" >> "$GITHUB_PATH"
"$install_dir/$binary_name" --help >/dev/null
