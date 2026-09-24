#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat .prono4/build90/ios-source.part-* | base64 --decode > "$TMP/build90-ios-source.tar.gz"
tar -xzf "$TMP/build90-ios-source.tar.gz" -C "$ROOT"

grep -qx 'version: 2.8.11+90' pubspec.yaml
echo "PRONO4 BUILD90 source restored."
