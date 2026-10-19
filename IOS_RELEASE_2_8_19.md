# PRONO4 iOS 2.8.19

This branch brings the tested current Flutter application to the existing App Store pipeline in `usasin/Husain`.

- App Store application: `6809793049`, bundle `com.digitalsolutionsai.prono4`, team `G6T4NT9XZ9`.
- Firebase iOS registration: `1:531137173785:ios:886307ce184d24e38b4d88`, same existing project `mundial2026-ibab-01`.
- Preserve the existing Codemagic integration, signing certificate/profile, production AdMob IDs and iPhone/iPad support. No new signing credential is created.
- Preserve the iOS permission screen and ATT-before-AdMob behavior from successful commit `ffb33d5b634885706695148033ab1baa7652c16a`. The screen is byte-identical to its archived source. Android keeps its existing route.
- Include current account linking/recovery, final-result handling, reward delivery, profile/badge UI and monthly ranking history. No user document, prediction, team or result is migrated by this branch.
- Only ATT 2.0.7, already used by iOS, is added to the current Android dependency lock; other locked package versions remain unchanged.

Local verification: 85 Flutter tests passed. Flutter analysis returned success with existing warnings/information (682 items); these are not claimed to be fixed. YAML and shell syntax checked.

Codemagic must still compile/sign and verify the IPA. Its checks cover the App Store bundle/version, both device families, the bundled Firebase registration, Google callback scheme, Apple sign-in entitlement and code signature before upload to App Store Connect. Build number is the next available TestFlight number, at least 99; the displayed build number follows it.

A successful local test run is not proof of an IPA build, TestFlight availability, App Store review or a real-device Google/Apple sign-in. Record those outcomes separately after they happen.
