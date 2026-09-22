#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="mundial2026-ibab-01"
npx --yes firebase-tools@latest deploy --project "$PROJECT_ID" --only firestore:rules
