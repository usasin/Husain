"use strict";
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { STATE_PATH, PERIODS, loadCalculation, patchIndividuals, refreshBadges } = require("./badges");
const mode = process.argv[2];
if (!["--preview", "--apply", "--status"].includes(mode)) throw Error("Usage: node badge-functions/repair.js --preview|--apply|--status");
const projectId = process.env.FIRESTORE_EMULATOR_HOST ? "demo-prono4-badges" : "mundial2026-ibab-01";
initializeApp({ projectId });
const db = getFirestore();
(async () => {
  if (mode === "--status") {
    const state = (await db.doc(STATE_PATH).get()).data() || {};
    console.log(JSON.stringify({ version: state.version, dirty: state.dirty, users: state.users, changedRows: state.changedRows, repairedAt: state.repairedAt?.toDate?.().toISOString() }, null, 2));
  } else if (mode === "--apply") {
    console.log(JSON.stringify(await refreshBadges(db, { force: true }), null, 2));
  } else {
    const calculation = await loadCalculation(db);
    const snaps = await db.getAll(...PERIODS.map(id => db.collection("rankingSnapshots").doc(id)));
    console.log(JSON.stringify({ preview: true, users: calculation.badges.size, changedRows: Object.fromEntries(snaps.map(snap => [snap.id, patchIndividuals(snap.data()?.individuals || [], calculation).changed])) }, null, 2));
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => db.terminate());
