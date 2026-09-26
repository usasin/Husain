#!/usr/bin/env python3
from pathlib import Path

MAIN = Path("lib/main.dart")
ADS = Path("lib/services/ad_service.dart")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)

main = MAIN.read_text(encoding="utf-8")
old_main = """  Future<void> _initializeOptionalServices() async {
    try {
      await NotificationService.instance.initialize();
    } catch (error) {
      debugPrint('Notification init non bloquante: $error');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await MessagingService.instance.initialize();
    } catch (error) {
      debugPrint('Messaging init non bloquant: $error');
    }

    try {
      await AdService.instance.initialize();
    } catch (error) {
      debugPrint('AdMob init non bloquante: $error');
    }
  }
"""
new_main = """  Future<void> _initializeOptionalServices() async {
    // iOS: ATT doit être résolu AVANT toute autre permission système et
    // avant l'initialisation UMP/AdMob. Cela évite que la popup Notifications
    // masque/annule la demande ATT pendant la phase de review Apple.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await AdService.instance.initialize();
      } catch (error) {
        debugPrint('AdMob/ATT init non bloquante: $error');
      }
    }

    try {
      await NotificationService.instance.initialize();
    } catch (error) {
      debugPrint('Notification init non bloquante: $error');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await MessagingService.instance.initialize();
    } catch (error) {
      debugPrint('Messaging init non bloquant: $error');
    }

    // Android conserve l'ordre historique. Sur iOS, AdMob/ATT est déjà
    // initialisé ci-dessus avant les notifications.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      try {
        await AdService.instance.initialize();
      } catch (error) {
        debugPrint('AdMob init non bloquante: $error');
      }
    }
  }
"""
main = replace_once(main, old_main, new_main, "main.dart optional-services order")
MAIN.write_text(main, encoding="utf-8")

ads = ADS.read_text(encoding="utf-8")
if "package:flutter/widgets.dart" not in ads:
    ads = replace_once(
        ads,
        "import 'package:flutter/foundation.dart';\n",
        "import 'package:flutter/foundation.dart';\nimport 'package:flutter/widgets.dart';\n",
        "ad_service.dart widgets import",
    )

old_att = """  Future<void> _requestTrackingAuthorizationIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      // The Flutter UI is already visible when AdService starts. Waiting a
      // moment avoids presenting ATT during the first transition frame.
      // ATT is always resolved before UMP or Google Mobile Ads is initialized.
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('ATT authorization result: $result');
      } else {
        debugPrint('ATT authorization already resolved: $status');
      }
    } catch (e) {
      // Ads are optional; an ATT API failure must not block PRONO4 itself.
      debugPrint('ATT authorization request error: $e');
    }
  }
"""
new_att = """  Future<bool> _waitUntilIosAppIsActive() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;

    // requestTrackingAuthorization() must be presented while the app is active.
    // Poll briefly because a cold launch can still be transitioning to resumed.
    for (var attempt = 0; attempt < 40; attempt++) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        // Keep the documented launch delay, but only after the app is active.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        return WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> _requestTrackingAuthorizationIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      // ATT is resolved before UMP / Google Mobile Ads and before the
      // notification permission request triggered later by main.dart.
      final isActive = await _waitUntilIosAppIsActive();
      if (!isActive) {
        debugPrint('ATT skipped: iOS app did not become active in time.');
        return;
      }

      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('ATT authorization result: $result');
      } else {
        debugPrint('ATT authorization already resolved: $status');
      }
    } catch (e) {
      // Ads are optional; an ATT API failure must not block PRONO4 itself.
      debugPrint('ATT authorization request error: $e');
    }
  }
"""
ads = replace_once(ads, old_att, new_att, "ad_service.dart ATT gate")
ADS.write_text(ads, encoding="utf-8")

# Fail fast before CocoaPods/Xcode if the safety invariants are not present.
main_check = MAIN.read_text(encoding="utf-8")
ads_check = ADS.read_text(encoding="utf-8")
ios_block = main_check.index("if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)")
ad_pos = main_check.index("await AdService.instance.initialize();", ios_block)
notif_pos = main_check.index("await NotificationService.instance.initialize();", ios_block)
if ad_pos >= notif_pos:
    raise SystemExit("ATT order verification failed: notifications still precede AdService on iOS")
if "AppTrackingTransparency.requestTrackingAuthorization()" not in ads_check:
    raise SystemExit("ATT verification failed: requestTrackingAuthorization missing")
if "WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed" not in ads_check:
    raise SystemExit("ATT verification failed: active/resumed gate missing")

print("✅ iOS ATT preflight patched: ACTIVE → ATT → UMP/AdMob → Notifications.")
