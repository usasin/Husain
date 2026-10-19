#!/usr/bin/env bash
set -euo pipefail
swift --version
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.digitalsolutionsai.prono4}"
export IOS_BUNDLE_ID
export ADMOB_IOS_APP_ID="${ADMOB_IOS_APP_ID:-ca-app-pub-1360261396564293~2163448650}"
IOS_FIREBASE_PLIST_BASE64="${PRONO4_IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64:-${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}}"

# Preserve the CocoaPods setup used by the successful App Store builds.
flutter config --no-enable-swift-package-manager
if [ ! -d ios/Runner.xcodeproj ]; then
  flutter create --no-pub --platforms=ios --org com.digitalsolutionsai .
fi
if [ -n "$IOS_FIREBASE_PLIST_BASE64" ]; then
  printf '%s' "$IOS_FIREBASE_PLIST_BASE64" | base64 --decode > ios/Runner/GoogleService-Info.plist
fi
test -f ios/Runner/GoogleService-Info.plist
plutil -lint ios/Runner/GoogleService-Info.plist

swift run --package-path scripts/ios_setup prono4_ios_setup
flutter pub get --enforce-lockfile
dart run flutter_launcher_icons
dart run flutter_native_splash:create
cd ios
pod install --repo-update
cd ..
plutil -lint ios/Runner/Info.plist
plutil -lint ios/Runner/Runner.entitlements
