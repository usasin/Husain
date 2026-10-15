#!/usr/bin/env python3
"""Prepare Codemagic signing only for PRONO4's existing Google Play upload key."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
UPLOAD_SHA256 = "70D9ED8FBAA44F08768FBBF4D7D8418C402CD3D000AAC38398FFCE880DBBFA84"


def command(arguments):
    try:
        result = subprocess.run(arguments, capture_output=True, check=False)
    except FileNotFoundError:
        raise SystemExit("Outil de signature absent : installer un JDK complet avec keytool et jarsigner.") from None
    if result.returncode:
        raise SystemExit("Vérification de signature impossible ; contrôler la clé et sa configuration privée.")
    return result.stdout


def check_certificate(der):
    if hashlib.sha256(der).hexdigest().upper() != UPLOAD_SHA256:
        raise SystemExit("Le certificat ne correspond pas à la clé d'importation PRONO4 dans Google Play. Compilation arrêtée.")


def properties_value(value):
    output = []
    for char in value:
        if char in "\\ =:#!":
            output.append("\\" + char)
        elif 32 <= ord(char) <= 126:
            output.append(char)
        else:
            encoded = char.encode("utf-16-be")
            output.extend("\\u" + encoded[index:index + 2].hex() for index in range(0, len(encoded), 2))
    return "".join(output)


def prepare():
    names = ["CM_KEYSTORE_PATH", "CM_KEYSTORE_PASSWORD", "CM_KEY_ALIAS", "CM_KEY_PASSWORD"]
    if any(not os.environ.get(name) for name in names):
        raise SystemExit("Clé Android manquante : configurer prono4_android_upload dans Codemagic avant de lancer le build.")
    keystore = Path(os.environ["CM_KEYSTORE_PATH"]).resolve()
    if not keystore.is_file():
        raise SystemExit("Le fichier de clé Android configuré est introuvable.")
    firebase = json.loads((ROOT / "android/app/google-services.json").read_text())
    packages = {client.get("client_info", {}).get("android_client_info", {}).get("package_name")
                for client in firebase.get("client", [])}
    if firebase.get("project_info", {}).get("project_id") != "mundial2026-ibab-01" or "com.mundial.app" not in packages:
        raise SystemExit("La configuration Firebase ne correspond pas à PRONO4 Android.")
    if 'applicationId "com.mundial.app"' not in (ROOT / "android/app/build.gradle").read_text():
        raise SystemExit("Identifiant Android PRONO4 inattendu.")
    certificate = command(["keytool", "-exportcert", "-keystore", str(keystore),
                           "-alias", os.environ["CM_KEY_ALIAS"],
                           "-storepass:env", "CM_KEYSTORE_PASSWORD"])
    check_certificate(certificate)
    values = {"storeFile": str(keystore), "storePassword": os.environ["CM_KEYSTORE_PASSWORD"],
              "keyAlias": os.environ["CM_KEY_ALIAS"], "keyPassword": os.environ["CM_KEY_PASSWORD"]}
    destination = ROOT / "android/key.properties"
    if destination.exists():
        raise SystemExit("android/key.properties existe déjà ; aucun fichier privé n'a été écrasé.")
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="ascii") as target:
        target.write("".join(key + "=" + properties_value(value) + "\n" for key, value in values.items()))
    print("Certificat d'importation Google Play vérifié. Signature Android configurée sans affichage de secrets.")


def verify_bundle(bundle):
    path = Path(bundle)
    if not path.is_file():
        raise SystemExit("App bundle Android introuvable.")
    verification = command(["jarsigner", "-J-Duser.language=en", "-J-Duser.country=US", "-verify", str(path)])
    if b"jar verified." not in verification.lower():
        raise SystemExit("La signature de l'app bundle Android n'est pas valide.")
    certificates = command(["keytool", "-printcert", "-jarfile", str(path), "-rfc"])
    match = re.search(rb"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----", certificates, re.S)
    if not match:
        raise SystemExit("Certificat de signature absent de l'app bundle.")
    check_certificate(base64.b64decode(match.group(1)))
    print("App bundle signé avec le certificat d'importation PRONO4 attendu par Google Play.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-bundle")
    arguments = parser.parse_args()
    if arguments.verify_bundle:
        verify_bundle(arguments.verify_bundle)
    else:
        prepare()
