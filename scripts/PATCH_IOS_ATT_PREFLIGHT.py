#!/usr/bin/env python3
"""Read-only validation of the canonical source restored by Codemagic."""
from pathlib import Path
import json
import hashlib

main = Path("lib/main.dart").read_text(encoding="utf-8")
screen = Path("lib/screens/permissions_welcome_screen.dart").read_text(encoding="utf-8")
pubspec = Path("pubspec.yaml").read_text(encoding="utf-8")
required = {
    "version": "version: 2.8.19+99" in pubspec.splitlines(),
    "permissions gate": "PermissionsWelcomeGate" in main,
    "iOS AdMob deferral": "Aucun SDK publicitaire n'est initialisé automatiquement avant ATT" in main,
    "ATT dependency": "app_tracking_transparency:" in pubspec,
    "ATT request": "AppTrackingTransparency.requestTrackingAuthorization()" in screen,
    "active-state guard": "AppLifecycleState.resumed" in screen,
    "AdMob after ATT": "AdService.instance.initialize()" in screen,
    "Google dependency": "google_sign_in: 6.3.0" in pubspec,
}
manifest = json.loads(Path(".prono4/build90/source-manifest.json").read_text())
for name, expected in manifest["sha256"].items():
    path = Path(name)
    required[name] = path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == expected
missing = [name for name, ok in required.items() if not ok]
if missing:
    raise SystemExit("Restored iOS source validation failed: " + ", ".join(missing))
print("Canonical PRONO4 2.8.19 source verified, ATT preserved. No source modified.")
