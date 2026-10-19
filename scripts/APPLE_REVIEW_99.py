"""Inspect PRONO4's existing Apple build without exporting signing credentials."""
import json
import os
import pathlib
import re
import subprocess

APP_ID = "6809793049"
BUILD_ID = "9a536c98-de8d-4cc4-a7b7-91bf31318ef2"


def apple(*arguments):
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
            if "error:" in line.lower():
                print(line[:800])
        raise RuntimeError("Apple CLI failed for " + " ".join(arguments[:2])
                           + "; exit=" + str(result.returncode))
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
    main()
