#!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#jq nixpkgs#gnutar nixpkgs#nix nixpkgs#nodejs -c bash
# shellcheck shell=bash
set -euo pipefail

repo_root=$(pwd)
version_file=VERSION.json
archive_base_url=https://github.com/badlogic/pi-mono/archive/refs/tags

current_rev=$(jq -r '.rev' "$version_file")
archive_url="${archive_base_url}/${current_rev}.tar.gz"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Fetching upstream ${current_rev}..."
archive_path=$(nix store prefetch-file --json "$archive_url" | jq -r .storePath)

tar -xzf "$archive_path" --strip-components=1 -C "$tmpdir"

echo "Generating model definitions..."
pushd "$tmpdir" >/dev/null
export NPM_CONFIG_YES=true
npm ci --ignore-scripts
npm run generate-models --workspace=packages/ai
popd >/dev/null

generated="$tmpdir/packages/ai/src/models.generated.ts"
existing="$repo_root/models.generated.ts"

if cmp -s "$generated" "$existing"; then
  echo "models.generated.ts is already up to date"
  exit 0
fi

cp "$generated" "$existing"
echo "Updated models.generated.ts"
