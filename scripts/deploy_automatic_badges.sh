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
)
firebase deploy --config firebase.badges.json --project "$PROJECT_ID" --only functions:prono4-badges
# Run the initial general repair immediately. The same job then handles all
# future results/recoveries automatically, without a mobile build.
gcloud scheduler jobs run firebase-schedule-refreshAutomaticBadgesScheduled-europe-west1 \
  --project "$PROJECT_ID" --location europe-west1
echo 'Déploiement terminé. Réparation générale lancée ; actualisation automatique toutes les 15 minutes après changement.'
echo 'Vérification : node badge-functions/repair.js --status'
