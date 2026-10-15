#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_ID="mundial2026-ibab-01"
(
  cd badge-functions
  npm ci --ignore-scripts --no-audit --no-fund
  npm test
  node --check index.js
  node --check repair.js
  node --check manual-fixtures.js
)
firebase deploy --config firebase.badges.json --project "$PROJECT_ID" --only functions:prono4-badges
# Initialize the manual Europa calendar and run the general badge repair.
# The same job then handles future results/recoveries automatically.
gcloud scheduler jobs run firebase-schedule-refreshAutomaticBadgesScheduled-europe-west1 \
  --project "$PROJECT_ID" --location europe-west1
echo 'Déploiement terminé. Calendrier Ligue Europa et réparation générale lancés ; badges actualisés toutes les 15 minutes après changement.'
echo 'Vérification : node badge-functions/repair.js --status'
