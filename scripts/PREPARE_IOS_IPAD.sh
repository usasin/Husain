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
  # Flutter create rewrites pubspec.lock even with --no-pub. Generate only the
  # native host in an isolated directory, then retain the proven Podfile.
  ios_host_dir="$(mktemp -d)"
  flutter create --no-pub --platforms=ios --org com.digitalsolutionsai --project-name prono4 "$ios_host_dir"
  if [ -f ios/Podfile ]; then cp ios/Podfile "$ios_host_dir/Podfile.saved"; fi
  mkdir -p ios
  cp -R "$ios_host_dir/ios/." ios/
  if [ -f "$ios_host_dir/Podfile.saved" ]; then cp "$ios_host_dir/Podfile.saved" ios/Podfile; fi
fi
git diff --exit-code -- lib pubspec.yaml pubspec.lock
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
