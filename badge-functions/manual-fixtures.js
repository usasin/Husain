"use strict";
const { createHash } = require("node:crypto");
const { Timestamp, FieldValue } = require("firebase-admin/firestore");
const seed = require("./europa-fixtures.json");
const COMPETITION = "europa-league";
const PREFIX = "manual_el_";
const STATE = "system/manualEuropaLeagueV1";
const yearFor = now => now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;

function manualManifestRow(match, result, year) {
  const kickoffAtMs = match.kickoffAt?.toMillis?.();
  if (match.competitionId !== COMPETITION || !Number.isFinite(kickoffAtMs) ||
      kickoffAtMs < Date.UTC(year, 6, 1) || kickoffAtMs >= Date.UTC(year + 1, 6, 1) ||
      String(match.status || "").toUpperCase() === "CANCELLED") return null;
  const homeScore = result?.homeScore;
  const awayScore = result?.awayScore;
  const status = String(result?.status || result?.liveStatus || "").toUpperCase();
  const final = (!status || ["FINISHED", "AWARDED"].includes(status)) &&
    Number.isInteger(homeScore) && Number.isInteger(awayScore) &&
    homeScore >= 0 && awayScore >= 0 && homeScore <= 99 && awayScore <= 99;
  return {
    id: match.id, competitionId: COMPETITION,
    homeCode: String(match.homeCode || ""), awayCode: String(match.awayCode || ""),
    homeName: String(match.homeName || match.homeCode || ""), awayName: String(match.awayName || match.awayCode || ""),
    homeCrestUrl: String(match.homeCrestUrl || ""), awayCrestUrl: String(match.awayCrestUrl || ""),
    kickoffAtMs, venue: String(match.venue || ""), stage: String(match.stage || ""),
    stageCode: String(match.stageCode || ""), matchday: Number.isInteger(match.matchday) ? match.matchday : null,
    label: String(match.label || match.stage || ""), allowsDraw: match.allowsDraw !== false,
    status: final ? "FINISHED" : String(match.status || "TIMED"),
    homeScore: final ? homeScore : null, awayScore: final ? awayScore : null,
    result: final ? (homeScore > awayScore ? "HOME" : homeScore < awayScore ? "AWAY" : "DRAW") : null,
  };
}

async function refreshEuropaManifest(db, now = new Date()) {
  const year = yearFor(now);
  return db.runTransaction(async tx => {
    const ref = db.doc(`fixtureManifests/${COMPETITION}`);
    const [matches, previous] = await Promise.all([
      tx.get(db.collection("matches").where("competitionId", "==", COMPETITION)), tx.get(ref),
    ]);
    const results = new Map();
    for (let i = 0; i < matches.docs.length; i += 100) {
      const docs = await tx.getAll(...matches.docs.slice(i, i + 100).map(match => db.doc(`results/${match.id}`)));
      for (const doc of docs) if (doc.exists) results.set(doc.id, doc.data());
    }
    const rows = matches.docs.map(doc => manualManifestRow({ ...doc.data(), id: doc.id }, results.get(doc.id), year))
      .filter(Boolean).sort((a, b) => a.kickoffAtMs - b.kickoffAtMs || a.id.localeCompare(b.id));
    const stable = { competitionId: COMPETITION, apiCode: "EL", season: year, source: "manual", rows };
    if (Buffer.byteLength(JSON.stringify(stable), "utf8") > 850000) throw Error("Europa League calendar exceeds the safe Firestore size; no data was truncated");
    const version = createHash("sha256").update(JSON.stringify(stable)).digest("hex");
    if (previous.data()?.version === version) return { changed: false, matches: rows.length };
    tx.set(ref, { ...stable, version, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return { changed: true, matches: rows.length };
  });
}

async function ensureEuropaFixtures(db, now = new Date()) {
  if (yearFor(now) !== seed.season) return { skipped: "different-season" };
  const stateRef = db.doc(STATE);
  const state = (await stateRef.get()).data();
  if (state?.seeded === true && state?.published === true) return { skipped: "ready" };
  const created = await db.runTransaction(async tx => {
    const refs = seed.matches.map(match => db.doc(`matches/${match.id}`));
    const [stateSnap, existing, ...snaps] = await Promise.all([
      tx.get(stateRef), tx.get(db.collection("matches").where("competitionId", "==", COMPETITION)),
      ...refs.map(ref => tx.get(ref)),
    ]);
    if (stateSnap.data()?.seeded === true) return 0;
    const missing = [];
    for (let i = 0; i < seed.matches.length; i++) {
      const match = seed.matches[i];
      if (snaps[i].exists) {
        if (snaps[i].data().competitionId !== COMPETITION) throw Error("Europa fixture ID already belongs to another competition; no data was overwritten");
        continue;
      }
      const duplicate = existing.docs.some(doc => {
        const value = doc.data();
        return value.homeCode === match.homeCode && value.awayCode === match.awayCode &&
          value.kickoffAt?.toMillis?.() === Date.parse(match.kickoffUtc);
      });
      if (!duplicate) missing.push([refs[i], match]);
    }
    for (const [ref, match] of missing) {
      const { kickoffUtc, ...fields } = match;
      tx.create(ref, { ...fields, matchId: match.id, competitionId: COMPETITION,
        kickoffAt: Timestamp.fromDate(new Date(kickoffUtc)), source: "manual",
        status: "TIMED", stage: "Phase de ligue", stageCode: "LEAGUE_STAGE", allowsDraw: true,
        updatedAt: FieldValue.serverTimestamp() });
    }
    tx.set(stateRef, { seeded: true, published: false, season: seed.season, seededAt: FieldValue.serverTimestamp() }, { merge: true });
    return missing.length;
  });
  const publication = await refreshEuropaManifest(db, now);
  await stateRef.set({ published: true }, { merge: true });
  return { created, ...publication };
}

module.exports = { COMPETITION, PREFIX, STATE, manualManifestRow, refreshEuropaManifest, ensureEuropaFixtures };
