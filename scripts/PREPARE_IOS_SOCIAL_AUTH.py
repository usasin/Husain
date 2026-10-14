#!/usr/bin/env python3
"""Configure Google/Apple sign-in without replacing the Xcode project/signing."""
from pathlib import Path
import os
import plistlib
import subprocess


def configure_google(info, firebase):
    client = firebase.get("CLIENT_ID", "")
    reversed_client = firebase.get("REVERSED_CLIENT_ID", "")
    if not client.endswith(".apps.googleusercontent.com"):
        raise ValueError("Firebase iOS CLIENT_ID missing: verify Google provider for this bundle.")
    expected_scheme = "com.googleusercontent.apps." + client.removesuffix(".apps.googleusercontent.com")
    if reversed_client != expected_scheme:
        raise ValueError("Firebase iOS REVERSED_CLIENT_ID missing or inconsistent.")
    info["GIDClientID"] = client
    info["GIDServerClientID"] = "531137173785-tltuheu808j5t8j5qd51a1a79qak2upl.apps.googleusercontent.com"
    url_types = info.setdefault("CFBundleURLTypes", [])
    if not any(reversed_client in item.get("CFBundleURLSchemes", []) for item in url_types):
        url_types.append({"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [reversed_client]})
    return info


def verify_apple_profile(bundle):
    directory = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    for path in directory.glob("*.mobileprovision"):
        result = subprocess.run(["security", "cms", "-D", "-i", str(path)], capture_output=True)
        if result.returncode:
            continue
        profile = plistlib.loads(result.stdout)
        entitlements = profile.get("Entitlements", {})
        if entitlements.get("application-identifier", "").endswith("." + bundle):
            if "Default" in entitlements.get("com.apple.developer.applesignin", []):
                return
    raise ValueError("Existing PRONO4 provisioning profile must support Sign in with Apple. No profile changed; stop before Xcode.")


def main():
    bundle = os.environ.get("IOS_BUNDLE_ID", "com.digitalsolutionsai.prono4")
    firebase_path = Path("ios/Runner/GoogleService-Info.plist")
    firebase = plistlib.loads(firebase_path.read_bytes())
    if firebase.get("BUNDLE_ID") != bundle:
        raise ValueError("Firebase plist does not match the existing PRONO4 iOS bundle.")
    verify_apple_profile(bundle)
    info_path = Path("ios/Runner/Info.plist")
    info = configure_google(plistlib.loads(info_path.read_bytes()), firebase)
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    entitlement_path = Path("ios/Runner/Runner.entitlements")
    entitlements = plistlib.loads(entitlement_path.read_bytes()) if entitlement_path.exists() else {}
    entitlements["com.apple.developer.applesignin"] = ["Default"]
    entitlement_path.write_bytes(plistlib.dumps(entitlements, sort_keys=False))
    # Xcconfig sets a build setting; the existing .pbxproj stays untouched.
    setting = "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements"
    for mode in ("Debug", "Release"):
        config = Path(f"ios/Flutter/{mode}.xcconfig")
        text = config.read_text()
        existing = [line for line in text.splitlines() if line.strip().startswith("CODE_SIGN_ENTITLEMENTS")]
        if existing and any(line.strip() != setting for line in existing):
            raise ValueError(f"Unexpected existing entitlement setting in {config}; inspect before changing.")
        if not existing:
            config.write_text(text.rstrip() + "\n" + setting + "\n")
    print("Google URL scheme configured from validated Firebase plist; existing Apple profile verified.")


if __name__ == "__main__":
    main()
