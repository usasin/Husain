"""Inspect PRONO4's existing Apple build without exporting signing credentials."""
import json
import os
import pathlib
import re
import subprocess
import sys
import time

APP_ID = "6809793049"
BUILD_ID = "9a536c98-de8d-4cc4-a7b7-91bf31318ef2"
VERSION_ID = "b17857c6-e820-41f8-af1d-fab6ae1666cf"
OLD_REVIEW_ID = "4c02302f-5ee2-404f-8401-ff537374d139"
TARGET_VERSION = "2.8.19"
NOTES = {
    "fr": "Amélioration de l’association des comptes Google et Apple, de la cohérence des scores et des classements. Historique des classements mensuels, profil plus clair et améliorations des animations de résultats.",
    "en": "Improved Google and Apple account linking, score and ranking consistency. Monthly ranking history, a clearer profile and improvements to result animations.",
}


def apple(*arguments, allow_empty=False):
    result = subprocess.run(
        ["app-store-connect", *arguments, "--json", "--no-color"],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode:
        diagnostic = result.stderr
        for name, value in os.environ.items():
            if value and len(value) > 3 and any(word in name.upper() for word in
                                             ("KEY", "TOKEN", "SECRET", "PASSWORD", "ISSUER")):
                diagnostic = diagnostic.replace(value, "HIDDEN")
        diagnostic = re.sub(r"-----BEGIN.*?-----END[^-]+-----", "HIDDEN", diagnostic, flags=re.S)
        # Only parser error lines; never dump environment values or raw output.
        for line in diagnostic.splitlines():
            if any(word in line.lower() for word in ("error", "invalid", "forbidden", "not allowed", "required")):
                print(line[:800])
        raise RuntimeError("Apple CLI failed for " + " ".join(arguments[:2])
                           + "; exit=" + str(result.returncode))
    if allow_empty and not result.stdout.strip():
        return None
    try:
        return json.loads(result.stdout)
    except ValueError:
        raise RuntimeError("Apple CLI returned unreadable JSON") from None


def resources(value):
    if isinstance(value, dict) and "data" in value:
        value = value["data"]
    return value if isinstance(value, list) else [value]


def summarize(value, fields):
    entries = []
    for resource in resources(value):
        attrs = resource.get("attributes", resource)
        entry = {"id": resource.get("id")}
        entry.update({key: attrs.get(key) for key in fields if key in attrs})
        entries.append(entry)
    return entries


def one(value):
    entries = resources(value)
    if len(entries) != 1:
        raise RuntimeError("Expected exactly one Apple resource")
    return entries[0]


def attributes(value):
    return value.get("attributes", value)


def api_read(path):
    """Read a fixed Apple relationship; the short-lived token never leaves Apple."""
    import jwt
    import requests
    key = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
    if key.startswith("@file:"):
        key = pathlib.Path(key[6:]).read_text()
    now = int(time.time())
    token = jwt.encode({"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"],
                        "iat": now, "exp": now + 180, "aud": "appstoreconnect-v1"},
                       key, algorithm="ES256",
                       headers={"kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"]})
    if not path.startswith("/v1/") or ".." in path:
        raise RuntimeError("Invalid Apple API path")
    response = requests.get("https://api.appstoreconnect.apple.com" + path,
                            headers={"Authorization": "Bearer " + token}, timeout=45)
    if response.status_code != 200:
        raise RuntimeError("Apple relationship check failed: HTTP " + str(response.status_code))
    return response.json()


def validate_plan(version, build, localizations):
    version_attrs = attributes(version)
    build_attrs = attributes(build)
    if version.get("id") != VERSION_ID or version_attrs.get("versionString") not in ("2.8.14", TARGET_VERSION):
        raise RuntimeError("Unexpected App Store version; no changes made")
    if build.get("id") != BUILD_ID or build_attrs.get("version") != "99":
        raise RuntimeError("Unexpected Apple build; no changes made")
    if build_attrs.get("processingState") != "VALID" or build_attrs.get("expired"):
        raise RuntimeError("Apple build is not valid for submission")
    if not localizations or not any(attributes(item).get("locale") == "fr-FR" for item in localizations):
        raise RuntimeError("Missing French App Store localization")
    for item in localizations:
        data = attributes(item)
        if not data.get("description") or not data.get("supportUrl"):
            raise RuntimeError("Incomplete existing App Store metadata")
        if data.get("locale", "").split("-")[0] not in NOTES:
            raise RuntimeError("Release notes need translation before modifying Apple")


def checkpoint(report):
    directory = pathlib.Path("apple-review")
    directory.mkdir(exist_ok=True)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    (directory / "submission-99.json").write_text(text, encoding="utf-8")
    print(text, flush=True)


def submit():
    report = {"appId": APP_ID, "versionId": VERSION_ID, "buildId": BUILD_ID,
              "version": TARGET_VERSION, "buildNumber": 99, "status": "preflight"}
    try:
        version = one(apple("app-store-versions", "get", VERSION_ID))
        build = one(apple("apps", "builds", APP_ID, "--build-id", BUILD_ID,
                          "--pre-release-version", TARGET_VERSION, "--platform", "IOS"))
        localizations = resources(apple("app-store-versions", "localizations", VERSION_ID))
        validate_plan(version, build, localizations)
        report["locales"] = [attributes(item)["locale"] for item in localizations]
        report["releaseType"] = attributes(version).get("releaseType")
        report["previousAttachedBuildId"] = one(api_read("/v1/appStoreVersions/" + VERSION_ID + "/build")).get("id")
        checkpoint(report)

        if attributes(version).get("versionString") == "2.8.14":
            reviews = resources(apple("apps", "list-review-submissions", APP_ID, "--platform", "IOS"))
            old = next((review for review in reviews if review.get("id") == OLD_REVIEW_ID), None)
            if old and attributes(old).get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW", "READY_FOR_REVIEW"):
                apple("review-submissions", "cancel", OLD_REVIEW_ID, allow_empty=True)
                report["oldReviewWithdrawalRequested"] = True
                checkpoint(report)
            for attempt in range(24):
                version = one(apple("app-store-versions", "get", VERSION_ID))
                if attributes(version).get("appStoreState") in ("DEVELOPER_REJECTED", "PREPARE_FOR_SUBMISSION", "REJECTED", "METADATA_REJECTED"):
                    break
                time.sleep(5)
            else:
                raise RuntimeError("Apple has not finished withdrawing the previous review")

        state = attributes(version).get("appStoreState")
        if state in ("WAITING_FOR_REVIEW", "IN_REVIEW") and attributes(version).get("versionString") == TARGET_VERSION:
            if one(api_read("/v1/appStoreVersions/" + VERSION_ID + "/build")).get("id") != BUILD_ID:
                raise RuntimeError("Existing review has a different build")
            report.update(status="submission-confirmed", appStoreState=state)
            checkpoint(report)
            return
        if state not in ("DEVELOPER_REJECTED", "PREPARE_FOR_SUBMISSION", "REJECTED", "METADATA_REJECTED"):
            raise RuntimeError("App Store version is not editable: " + str(state))

        apple("app-store-versions", "modify", VERSION_ID, "--version-string", TARGET_VERSION,
              "--build-id", BUILD_ID)
        report["versionUpdated"] = True
        checkpoint(report)
        for localization in localizations:
            locale = attributes(localization)["locale"]
            apple("app-store-version-localizations", "modify", localization["id"],
                  "--whats-new", NOTES[locale.split("-")[0]])
        attached = one(api_read("/v1/appStoreVersions/" + VERSION_ID + "/build"))
        if attached.get("id") != BUILD_ID:
            raise RuntimeError("Version is not attached to build 99")
        version = one(apple("app-store-versions", "get", VERSION_ID))
        if attributes(version).get("versionString") != TARGET_VERSION:
            raise RuntimeError("Wrong marketing version before review submission")

        reviews = resources(apple("apps", "list-review-submissions", APP_ID, "--platform", "IOS"))
        pending = [item for item in reviews if attributes(item).get("state") == "READY_FOR_REVIEW"]
        active = [item for item in reviews if attributes(item).get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW")]
        if active or len(pending) > 1:
            raise RuntimeError("Unexpected active Apple review; no additional cancellation")
        review = pending[0] if pending else one(apple("review-submissions", "create", APP_ID, "--platform", "IOS"))
        review_id = review["id"]
        report["reviewId"] = review_id
        checkpoint(report)
        items = resources(apple("review-submissions", "items", review_id))
        if not items:
            apple("review-submission-items", "create", review_id, "--version-id", VERSION_ID)
        else:
            for item in items:
                data = item.get("relationships", {}).get("appStoreVersion", {}).get("data", {})
                if data.get("id") != VERSION_ID:
                    raise RuntimeError("Review contains unexpected items")
        apple("review-submissions", "confirm", review_id, allow_empty=True)
        final_review = one(apple("review-submissions", "get", review_id))
        final_version = one(apple("app-store-versions", "get", VERSION_ID))
        review_state = attributes(final_review).get("state")
        version_state = attributes(final_version).get("appStoreState")
        report.update(reviewState=review_state, appStoreState=version_state)
        if review_state not in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
            raise RuntimeError("Submission has not entered the Apple review queue")
        report["status"] = "submission-confirmed"
        checkpoint(report)
    except Exception as error:
        report["status"] = "not-confirmed"
        report["error"] = str(error)
        checkpoint(report)
        raise


def main():
    report = {
        "appId": APP_ID,
        "expectedBuildId": BUILD_ID,
        "readOnly": True,
        "versions": summarize(apple("apps", "app-store-versions", APP_ID, "--platform", "IOS"),
                              ["versionString", "appStoreState", "appVersionState", "releaseType", "platform"]),
        "build": summarize(apple("builds", "get", BUILD_ID),
                           ["version", "processingState", "expired", "minOsVersion", "usesNonExemptEncryption"]),
        "submissions": summarize(apple("apps", "list-review-submissions", APP_ID, "--platform", "IOS"),
                                 ["state", "platform", "submittedDate"]),
    }
    directory = pathlib.Path("apple-review")
    directory.mkdir(exist_ok=True)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    (directory / "inspection-99.json").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    submit() if "--submit" in sys.argv else main()
