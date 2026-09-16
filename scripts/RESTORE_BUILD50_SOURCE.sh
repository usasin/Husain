#!/usr/bin/env bash
set -euo pipefail

PART_DIR=".prono4/build50/raw"
ARCHIVE=".prono4/build50/prono4_build50_overlay.tar.xz"
EXPECTED_SHA256="3af97ce068b5ea77327ed03fc933d85841efd114133232b01f794647127ff85e"

cp lib/screens/profile_screen.dart /tmp/prono4_profile_build48.dart

cat "$PART_DIR"/b50s-* > "$ARCHIVE"
echo "$EXPECTED_SHA256  $ARCHIVE" | shasum -a 256 -c -
tar -xJf "$ARCHIVE" -C .

cp /tmp/prono4_profile_build48.dart lib/screens/profile_screen.dart

echo "PRONO4 BUILD50 overlay restored successfully"
