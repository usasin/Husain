#!/usr/bin/env bash
set -euo pipefail

PART_DIR=".prono4/build50/raw"
ARCHIVE=".prono4/build50/prono4_build50_overlay.tar.xz"
EXPECTED_SHA256="3af97ce068b5ea77327ed03fc933d85841efd114133232b01f794647127ff85e"

BUILD55_PATCH_DIR=".prono4/build55/patch"
BUILD55_PATCH="/tmp/prono4_build55.patch"
BUILD55_PATCH_SHA256="29f44c875d6dbc739af81b73fdc2f28eed723ea4e3991a9d8c439d31162d502d"

cat "$PART_DIR"/b50s-* > "$ARCHIVE"
echo "$EXPECTED_SHA256  $ARCHIVE" | shasum -a 256 -c -
tar -xJf "$ARCHIVE" -C .

# Rejoue exactement les changements validés sur Android BUILD55
# par-dessus la source BUILD50 stable.
cat "$BUILD55_PATCH_DIR"/b55p-* > "$BUILD55_PATCH"
echo "$BUILD55_PATCH_SHA256  $BUILD55_PATCH" | shasum -a 256 -c -
patch -p1 --forward < "$BUILD55_PATCH"

# Conserve les correctifs iOS/App Review déjà ajoutés sur la branche :
# contrôles visibles Bloquer/Signaler + ATT avant initialisation AdMob.
python3 scripts/PATCH_CHAT_BUILD51.py
python3 scripts/PATCH_ATT_BUILD52.py

# Vérifications BUILD55 + conformité iOS.
grep -q "version: 2.5.3+55" pubspec.yaml
grep -q "Application du thème" lib/widgets/theme_settings_card.dart
grep -q "Choose light or dark" lib/widgets/theme_settings_card.dart
! grep -q "ThemeMode.system" lib/widgets/theme_settings_card.dart
grep -q "Theme.of(context).brightness" lib/widgets/wc26_background.dart
grep -q "CONFIRMÉ" lib/widgets/reputation_badge.dart
grep -q "getAutoReputationBadge" lib/screens/team_chat_screen.dart
grep -q "Sous chaque pseudo : Bloquer ou Signaler" lib/screens/team_chat_screen.dart
grep -q "Sous chaque pseudo : Bloquer ou Signaler" lib/screens/match_lounge_screen.dart
grep -q "contentReports" lib/screens/team_chat_screen.dart
grep -q "contentReports" lib/screens/match_lounge_screen.dart
grep -q "app_tracking_transparency: ^2.0.7" pubspec.yaml
grep -q "requestTrackingAuthorization()" lib/services/ad_service.dart
grep -q "await _requestTrackingAuthorizationIfNeeded();" lib/services/ad_service.dart

echo "PRONO4 BUILD55 source restored successfully (BUILD50 + BUILD55 UX/theme + chat moderation + ATT)"
