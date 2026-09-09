#!/usr/bin/env bash
set -euo pipefail

IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.digitalsolutionsai.prono4}"
OUTPUT_DIR="${APP_STORE_SCREENSHOTS_DIR:-app_store_screenshots}"
SCREENSHOT="$OUTPUT_DIR/PRONO4_iPhone_01.png"

mkdir -p "$OUTPUT_DIR"

SIMULATOR_JSON="$(xcrun simctl list devices available -j)"
SIM_UDID="$(
  printf '%s' "$SIMULATOR_JSON" | jq -r '
    [
      .devices
      | to_entries[]
      | .value[]
      | select(.isAvailable == true)
      | select(
          .name == "iPhone 13 Pro Max" or
          .name == "iPhone 12 Pro Max" or
          .name == "iPhone 14 Plus"
        )
      | .udid
    ][0] // empty
  '
)"

if [ -z "$SIM_UDID" ]; then
  echo "Aucun simulateur iPhone compatible 1284×2778 n'est installé."
  printf '%s' "$SIMULATOR_JSON" | jq -r '.devices | to_entries[] | .value[] | select(.isAvailable == true) | .name'
  exit 1
fi

echo "Simulation App Store sur $SIM_UDID"
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b

flutter build ios --debug --simulator

xcrun simctl uninstall "$SIM_UDID" "$IOS_BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM_UDID" build/ios/iphonesimulator/Runner.app
xcrun simctl privacy "$SIM_UDID" grant notifications "$IOS_BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$SIM_UDID" "$IOS_BUNDLE_ID"

# Laisse l'écran d'accueil de l'application se charger entièrement.
sleep 18
xcrun simctl io "$SIM_UDID" screenshot "$SCREENSHOT"

WIDTH="$(sips -g pixelWidth "$SCREENSHOT" | awk '/pixelWidth/ {print $2}')"
HEIGHT="$(sips -g pixelHeight "$SCREENSHOT" | awk '/pixelHeight/ {print $2}')"
test "$WIDTH" = "1284"
test "$HEIGHT" = "2778"

echo "✅ Capture App Store créée : $SCREENSHOT ($WIDTH×$HEIGHT)"
