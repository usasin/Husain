#!/usr/bin/env python3
from pathlib import Path
import shutil

MAIN = Path("lib/main.dart")
ADS = Path("lib/services/ad_service.dart")
TEMPLATE = Path("scripts/templates/permissions_welcome_screen.dart")
SCREEN = Path("lib/screens/permissions_welcome_screen.dart")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)

if not TEMPLATE.exists():
    raise SystemExit(f"Missing permissions template: {TEMPLATE}")

SCREEN.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(TEMPLATE, SCREEN)

main = MAIN.read_text(encoding="utf-8")

if "screens/permissions_welcome_screen.dart" not in main:
    main = replace_once(
        main,
        "import 'screens/onboarding_screen.dart';\n",
        "import 'screens/onboarding_screen.dart';\nimport 'screens/permissions_welcome_screen.dart';\n",
        "main.dart permissions import",
    )

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
    try {
      await NotificationService.instance.initialize();
    } catch (error) {
      debugPrint('Notification init non bloquante: $error');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (error) {
      debugPrint('Background messaging init non bloquant: $error');
    }

    // iOS: ATT et Notifications sont déclenchés depuis la page dédiée,
    // sur une action utilisateur. Aucun SDK publicitaire n'est initialisé
    // avant que le choix ATT soit résolu.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }

    try {
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

main = replace_once(
    main,
    old_main,
    new_main,
    "main.dart deferred iOS permissions",
)

old_root = """    if (prov.currentUser == null) {
      return const OnboardingScreen();
    }

    return const MainShell();
"""

new_root = """    final Widget destination = prov.currentUser == null
        ? const OnboardingScreen()
        : const MainShell();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return PermissionsWelcomeGate(child: destination);
    }

    return destination;
"""

main = replace_once(
    main,
    old_root,
    new_root,
    "main.dart permissions gate",
)
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

    for (var attempt = 0; attempt < 40; attempt++) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> requestTrackingAuthorization() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;

    try {
      final isActive = await _waitUntilIosAppIsActive();
      if (!isActive) {
        debugPrint('ATT not shown: iOS app is not active.');
        return false;
      }

      var status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('ATT authorization result: $status');
      } else {
        debugPrint('ATT authorization already resolved: $status');
      }

      return status != TrackingStatus.notDetermined;
    } catch (e) {
      debugPrint('ATT authorization request error: $e');
      return false;
    }
  }
"""

ads = replace_once(
    ads,
    old_att,
    new_att,
    "ad_service.dart ATT user-triggered gate",
)

old_init = """  Future<bool> _initializeInternal() async {
    await _requestTrackingAuthorizationIfNeeded();

    final completer = Completer<bool>();
"""

new_init = """  Future<bool> _initializeInternal() async {
    final trackingResolved = await requestTrackingAuthorization();
    if (!trackingResolved &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('AdMob deferred: ATT choice is still unresolved.');
      _canRequestAds = false;
      return false;
    }

    final completer = Completer<bool>();
"""

ads = replace_once(
    ads,
    old_init,
    new_init,
    "ad_service.dart AdMob after ATT",
)
ADS.write_text(ads, encoding="utf-8")

main_check = MAIN.read_text(encoding="utf-8")
ads_check = ADS.read_text(encoding="utf-8")
screen_check = SCREEN.read_text(encoding="utf-8")

required = {
    "PermissionsWelcomeGate": "PermissionsWelcomeGate" in main_check,
    "iOS services deferred": "page dédiée" in main_check,
    "ATT request": "requestTrackingAuthorization()" in ads_check,
    "ATT active state": "AppLifecycleState.resumed" in ads_check,
    "AdMob waits ATT": "AdMob deferred: ATT choice is still unresolved." in ads_check,
    "permission screen": "Avant de jouer" in screen_check,
    "neutral decline copy": "fonctionne même si vous refusez le suivi" in screen_check,
}
missing = [name for name, ok in required.items() if not ok]
if missing:
    raise SystemExit("iOS permissions preflight failed: " + ", ".join(missing))

print("✅ iOS permissions page ready: user action → ATT → AdMob; notifications explicit.")
