#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat .prono4/build90/ios-source.part-* | base64 --decode > "$TMP/build90-ios-source.tar.gz"
tar -xzf "$TMP/build90-ios-source.tar.gz" -C "$ROOT"

grep -qx 'version: 2.8.19+99' pubspec.yaml

# ATT is committed in the canonical archive. This preflight only verifies it.
python3 scripts/PATCH_IOS_ATT_PREFLIGHT.py

echo "PRONO4 2.8.19 source restored and verified; no runtime source patch."
