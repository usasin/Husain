#!/usr/bin/env bash
set -euo pipefail
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.digitalsolutionsai.prono4}"
ADMOB_IOS_APP_ID="${ADMOB_IOS_APP_ID:-ca-app-pub-1360261396564293~2163448650}"
IOS_FIREBASE_PLIST_BASE64="${PRONO4_IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64:-${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}}"

echo "[1/6] Host iOS/iPad"
if [ ! -d ios/Runner.xcodeproj ]; then
  flutter create --platforms=ios --org com.digitalsolutionsai .
fi

echo "[2/6] Bundle id: $IOS_BUNDLE_ID"
PBX="ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$PBX" ]; then
  # Remplace le bundle créé par Flutter, sans toucher aux Pods.
  sed -i.bak -E "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/PRODUCT_BUNDLE_IDENTIFIER = ${IOS_BUNDLE_ID};/g" "$PBX" || true
  sed -i.bak -E 's/TARGETED_DEVICE_FAMILY = "?1"?;/TARGETED_DEVICE_FAMILY = "1,2";/g' "$PBX" || true
  rm -f "$PBX.bak"
fi

echo "[3/6] Nom PRONO4 + configuration iPhone/iPad"
PLIST="ios/Runner/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName PRONO4" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string PRONO4" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :GADApplicationIdentifier $ADMOB_IOS_APP_ID" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :GADApplicationIdentifier string $ADMOB_IOS_APP_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :ITSAppUsesNonExemptEncryption" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :NSCameraUsageDescription 'PRONO4 utilise la caméra uniquement lorsque vous choisissez une photo de profil.'" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'PRONO4 utilise la caméra uniquement lorsque vous choisissez une photo de profil.'" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :NSPhotoLibraryUsageDescription 'PRONO4 accède à vos photos uniquement lorsque vous choisissez une photo de profil.'" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'PRONO4 accède à vos photos uniquement lorsque vous choisissez une photo de profil.'" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :NSUserTrackingUsageDescription 'Votre autorisation permet à PRONO4 de proposer des publicités plus pertinentes.'" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :NSUserTrackingUsageDescription string 'Votre autorisation permet à PRONO4 de proposer des publicités plus pertinentes.'" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :UISupportedInterfaceOrientations~ipad" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations~ipad array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations~ipad:0 string UIInterfaceOrientationPortrait" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations~ipad:1 string UIInterfaceOrientationPortraitUpsideDown" "$PLIST"

echo "[4/6] Firebase iOS"
if [ -n "$IOS_FIREBASE_PLIST_BASE64" ]; then
  echo "$IOS_FIREBASE_PLIST_BASE64" | base64 --decode > ios/Runner/GoogleService-Info.plist
fi
if [ ! -f ios/Runner/GoogleService-Info.plist ]; then
  echo "GoogleService-Info.plist absent. Fournis GOOGLE_SERVICE_INFO_PLIST_BASE64 dans Codemagic."
  exit 1
fi

echo "[5/6] Dépendances + icône + splash"
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create

echo "[6/6] Pods"
cd ios
pod install --repo-update
cd ..
plutil -lint ios/Runner/Info.plist
echo "✅ PRONO4 iPhone/iPad prêt côté source."
