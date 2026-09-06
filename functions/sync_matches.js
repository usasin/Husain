"use strict";

const admin = require("firebase-admin");
const { syncClubMatches, currentSeasonStartYear } = require("./club_matches_sync");

async function main() {
  const projectId =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    "mundial2026-ibab-01";

  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId });
  }

  const token = process.env.FOOTBALL_DATA_TOKEN;
  if (!token) {
    console.error("ERREUR: variable FOOTBALL_DATA_TOKEN absente.");
    console.error("Exemple: export FOOTBALL_DATA_TOKEN='ton_token'");
    process.exitCode = 2;
    return;
  }

  const season = Number(process.argv[2] || currentSeasonStartYear());
  const summary = await syncClubMatches({
    db: admin.firestore(),
    token,
    season,
    source: "cloud-shell",
  });

  console.log("\n=== SYNCHRONISATION TERMINÉE ===");
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error("\nSYNCHRONISATION ÉCHOUÉE:", error);
  process.exitCode = 1;
});
