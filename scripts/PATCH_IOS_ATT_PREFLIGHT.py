#!/usr/bin/env python3
from pathlib import Path
import shutil

MAIN = Path("lib/main.dart")
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

main = replace_section(
    main,
    "  Future<void> _initializeOptionalServices() async {",
    "\n  void _retry()",
    new_main,
    "main.dart deferred iOS permissions",
)

root_start = "    if (prov.currentUser == null) {"
root_end = "    return const MainShell();"
start = main.find(root_start)
if start < 0:
    raise SystemExit("main.dart permissions gate: start marker not found")
end = main.find(root_end, start)
if end < 0:
    raise SystemExit("main.dart permissions gate: end marker not found")
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

main_check = MAIN.read_text(encoding="utf-8")
screen_check = SCREEN.read_text(encoding="utf-8")

required = {
    "PermissionsWelcomeGate": "PermissionsWelcomeGate" in main_check,
    "iOS services deferred": "page dédiée" in main_check,
    "permission screen": "Avant de jouer" in screen_check,
    "user-triggered AdService": "await AdService.instance.initialize();" in screen_check,
    "ATT explanation": "fenêtre officielle" in screen_check,
    "neutral decline copy":
        "fonctionne même si vous refusez le suivi" in screen_check,
}
missing = [name for name, ok in required.items() if not ok]
if missing:
    raise SystemExit("iOS permissions preflight failed: " + ", ".join(missing))

print("✅ iOS permissions page ready: user action → ATT → AdMob; notifications explicit.")
