#!/usr/bin/env python3
from pathlib import Path
import shutil

MAIN = Path("lib/main.dart")
PUBSPEC = Path("pubspec.yaml")
TEMPLATE = Path("scripts/templates/permissions_welcome_screen.dart")
SCREEN = Path("lib/screens/permissions_welcome_screen.dart")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)

def replace_section(
    text: str,
    start_marker: str,
    end_marker: str,
    replacement: str,
    label: str,
) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f"{label}: start marker not found")
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"{label}: end marker not found")
    return text[:start] + replacement + text[end:]

if not TEMPLATE.exists():
    raise SystemExit(f"Missing permissions template: {TEMPLATE}")

# Ensure the ATT package is part of the exact BUILD90 source restored by Codemagic.
pubspec = PUBSPEC.read_text(encoding="utf-8")
if "app_tracking_transparency:" not in pubspec:
    marker = "  google_mobile_ads:"
    pos = pubspec.find(marker)
    if pos < 0:
        raise SystemExit("pubspec: google_mobile_ads dependency not found")
    line_end = pubspec.find("\n", pos)
    if line_end < 0:
        raise SystemExit("pubspec: malformed google_mobile_ads dependency")
    pubspec = (
        pubspec[: line_end + 1]
        + "  app_tracking_transparency: ^2.0.7\n"
        + pubspec[line_end + 1 :]
    )
    PUBSPEC.write_text(pubspec, encoding="utf-8")

SCREEN.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(TEMPLATE, SCREEN)

main = MAIN.read_text(encoding="utf-8")

if "screens/permissions_welcome_screen.dart" not in main:
    main = replace_once(
        main,
        "import 'screens/onboarding_screen.dart';\n",
        "import 'screens/onboarding_screen.dart';\n"
        "import 'screens/permissions_welcome_screen.dart';\n",
        "main.dart permissions import",
    )

new_optional_services = """  Future<void> _initializeOptionalServices() async {
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

    // iOS: la page d'autorisations gère ATT, notifications puis AdMob.
    // Aucun SDK publicitaire n'est initialisé automatiquement avant ATT.
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

main = replace_section(
    main,
    "  Future<void> _initializeOptionalServices() async {",
    "\n  void _retry()",
    new_optional_services,
    "main.dart iOS service deferral",
)

root_start = "    if (prov.currentUser == null) {"
root_end = "    return const MainShell();"
start = main.find(root_start)
if start < 0:
    raise SystemExit("main.dart root gate: start marker not found")
end = main.find(root_end, start)
if end < 0:
    raise SystemExit("main.dart root gate: end marker not found")
end += len(root_end)

new_root = """    final Widget destination = prov.currentUser == null
        ? const OnboardingScreen()
        : const MainShell();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return PermissionsWelcomeGate(child: destination);
    }

    return destination;"""

main = main[:start] + new_root + main[end:]
MAIN.write_text(main, encoding="utf-8")

# Fail fast on structural requirements only. No fragile copy/text assertions.
main_check = MAIN.read_text(encoding="utf-8")
screen_check = SCREEN.read_text(encoding="utf-8")
pubspec_check = PUBSPEC.read_text(encoding="utf-8")

required = {
    "permissions gate": "PermissionsWelcomeGate" in main_check,
    "iOS AdMob deferral":
        "Aucun SDK publicitaire n'est initialisé automatiquement avant ATT"
        in main_check,
    "ATT dependency": "app_tracking_transparency:" in pubspec_check,
    "ATT import":
        "package:app_tracking_transparency/app_tracking_transparency.dart"
        in screen_check,
    "ATT request":
        "AppTrackingTransparency.requestTrackingAuthorization()" in screen_check,
    "active-state guard": "AppLifecycleState.resumed" in screen_check,
    "AdMob after ATT": "AdService.instance.initialize()" in screen_check,
}
missing = [name for name, ok in required.items() if not ok]
if missing:
    raise SystemExit(
        "iOS permissions preflight failed: " + ", ".join(missing)
    )

print(
    "✅ BUILD90 iOS source patched: permissions page → ATT → AdMob; "
    "notifications remain user-triggered."
)
