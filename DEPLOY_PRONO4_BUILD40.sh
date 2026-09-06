#!/usr/bin/env bash
set -euo pipefail

PROJECT="mundial2026-ibab-01"
REGION="europe-west1"
JOB="firebase-schedule-syncClubMatchesScheduled-europe-west1"

echo "[1/6] Projet Firebase: $PROJECT"
gcloud config set project "$PROJECT" >/dev/null

echo "[2/6] APIs nécessaires"
gcloud services enable \
  compute.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT" >/dev/null

echo "[3/6] Dépendances Functions Linux propres"
rm -rf functions/node_modules
npm ci --prefix functions --no-audit --no-fund

echo "[4/6] Déploiement règles Firestore + synchronisation PRONO4"
npx -y firebase-tools@15.29.0 deploy \
  --only firestore:rules,functions:syncClubMatchesNow,functions:syncClubMatchesScheduled \
  --project "$PROJECT"

echo "[5/6] Synchronisation immédiate: matchs + écussons + classements"
gcloud scheduler jobs run "$JOB" \
  --location="$REGION" \
  --project="$PROJECT"

echo "[6/6] Contrôle"
gcloud functions list --v2 --regions="$REGION" --project="$PROJECT" \
  --filter="name:syncClubMatches" \
  --format="table(name,state,updateTime)"

echo
echo "BUILD 40 déployé. La synchro complète peut prendre environ 2 à 3 minutes"
echo "car le Free Tier est volontairement limité à moins de 10 appels/minute."
echo "Les classements seront dans Firestore: competitionStandings/{competitionId}."
