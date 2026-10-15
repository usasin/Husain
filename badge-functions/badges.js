"use strict";

const { randomUUID } = require("node:crypto");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

const VERSION = 1;
const STATE_PATH = "system/automaticBadgesV1";
const PERIODS = ["general", "week", "month", "gameSeason"];
const millis = value => value?.toMillis?.() ?? NaN;
const seasonYear = now => now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;

function finalResult(data) {
  if (!data) return null;
  const status = String(data.status || data.liveStatus || "").toUpperCase();
  // Historical manual results have no status. Live/provisional scores never
  // count as resolved predictions, even when an outcome is already present.
  if (status && !["FINISHED", "AWARDED"].includes(status)) return null;
  const result = String(data.result || "").toUpperCase();
  return ["HOME", "DRAW", "AWAY"].includes(result)
    ? { result, homeScore: data.homeScore, awayScore: data.awayScore } : null;
}

function automaticBadge(rows) {
  const recent = rows.slice().sort((a, b) => b.kickoffMs - a.kickoffMs || a.matchId.localeCompare(b.matchId)).slice(0, 30);
  const resolved = recent.length;
  if (resolved < 3) return { badge: "FOOTIX", knowledgeScore: 50, resolved };
  const correct = recent.filter(row => row.correct).length;
  const exact = recent.filter(row => row.exact).length;
  const knowledgeScore = Math.max(0, Math.min(100, Math.round(100 * (correct + .45 * exact + 2) / (resolved + 4))));
  const badge = knowledgeScore < 40 ? "FOOTIX" : knowledgeScore < 55 ? "AMATEUR"
    : knowledgeScore < 70 ? "CONNAISSEUR" : knowledgeScore < 85 ? "CONFIRMÉ" : "EXPERT";
  return { badge, knowledgeScore, resolved };
}

function identityDirectory(users, teams) {
  const byId = new Map(users.map(user => [user.id, user]));
  const active = new Set(users.filter(user => user.isArchived !== true && !user.migratedTo).map(user => user.id));
  const canonical = rawId => {
    let id = String(rawId || "");
    const seen = new Set();
    while (id && !seen.has(id)) {
      seen.add(id);
      const next = byId.get(id)?.migratedTo;
      if (!next) return active.has(id) ? id : "";
      id = String(next);
    }
    return ""; // Corrupt migration cycles must never merge unrelated players.
  };
  const inTeam = new Set(teams.flatMap(team => Array.isArray(team.memberIds) ? team.memberIds.map(canonical).filter(Boolean) : []));
  return { active, canonical, inTeam };
}

function calculateBadges({ users, teams, votes, matches, results }) {
  const directory = identityDirectory(users, teams);
  const matchById = new Map(matches.map(match => [match.id, match]));
  const resultById = new Map(results.map(result => [result.id, finalResult(result)]));
  const selected = new Map();
  for (const vote of votes) {
    const split = vote.id.indexOf("__");
    const docOwner = split > 0 ? vote.id.slice(0, split) : "";
    const matchId = split > 0 ? vote.id.slice(split + 2) : String(vote.matchId || "");
    const docUser = directory.canonical(docOwner);
    const fieldUser = directory.canonical(vote.userId);
    let owner = docUser || fieldUser;
    // Keep the existing BUILD90 identity rule if both profiles remain active
    // during recovery: current live team membership breaks the ambiguity.
    if (docUser && fieldUser && docUser !== fieldUser && !directory.inTeam.has(docUser) && directory.inTeam.has(fieldUser)) owner = fieldUser;
    const match = matchById.get(matchId);
    const result = resultById.get(matchId);
    if (!owner || !match || !Number.isFinite(millis(match.kickoffAt)) || !result) continue;
    const prediction = String(vote.prediction || "").toUpperCase();
    if (!["HOME", "DRAW", "AWAY"].includes(prediction)) continue;
    const priority = docOwner === owner ? 2 : 1;
    const key = `${owner}__${matchId}`;
    const previous = selected.get(key);
    // Migration often leaves both copied and original documents. One match
    // must count once; the destination document is authoritative.
    if (previous && (previous.priority > priority || (previous.priority === priority &&
      (previous.updatedMs > (millis(vote.updatedAt) || 0) ||
       (previous.updatedMs === (millis(vote.updatedAt) || 0) && previous.voteId.localeCompare(vote.id) <= 0))))) continue;
    selected.set(key, {
      owner, priority, voteId: vote.id, updatedMs: millis(vote.updatedAt) || 0,
      matchId, kickoffMs: millis(match.kickoffAt), correct: prediction === result.result,
      exact: typeof vote.exactHome === "number" && typeof vote.exactAway === "number" &&
        typeof result.homeScore === "number" && typeof result.awayScore === "number" &&
        vote.exactHome === result.homeScore && vote.exactAway === result.awayScore,
    });
  }
  const rows = new Map();
  for (const row of selected.values()) {
    if (!rows.has(row.owner)) rows.set(row.owner, []);
    rows.get(row.owner).push(row);
  }
  const badges = new Map([...directory.active].map(id => [id, automaticBadge(rows.get(id) || [])]));
  return { badges, canonical: directory.canonical, resolvedPredictions: selected.size };
}

function patchIndividuals(individuals, calculation) {
  let changed = 0;
  const rows = individuals.map(row => {
    const badge = calculation.badges.get(calculation.canonical(row.id));
    if (!badge || ["badge", "knowledgeScore", "resolved"].every(key => row[key] === badge[key])) return row;
    changed += 1;
    // No normalization, sorting, trimming, point/team recalculation or avatar
    // processing here. Every other field is preserved verbatim.
    return { ...row, ...badge };
  });
  return { rows, changed };
}

async function loadCalculation(db, now = new Date()) {
  const year = seasonYear(now);
  const [matchesSnap, votesSnap, usersSnap, teamsSnap] = await Promise.all([
    db.collection("matches").where("kickoffAt", ">=", Timestamp.fromDate(new Date(Date.UTC(year, 6, 1))))
      .where("kickoffAt", "<", Timestamp.fromDate(new Date(Date.UTC(year + 1, 6, 1)))).get(),
    db.collection("votes").where("updatedAt", ">=", Timestamp.fromDate(new Date(Date.UTC(year, 6, 1)))).get(),
    db.collection("users").get(), db.collection("teams").get(),
  ]);
  const objects = snap => snap.docs.map(doc => ({ ...doc.data(), id: doc.id }));
  const matches = objects(matchesSnap);
  const votes = objects(votesSnap);
  const wanted = new Set(votes.map(vote => {
    const split = vote.id.indexOf("__");
    return split > 0 ? vote.id.slice(split + 2) : String(vote.matchId || "");
  }));
  const ids = matches.filter(match => wanted.has(match.id)).map(match => match.id);
  const results = [];
  for (let offset = 0; offset < ids.length; offset += 100) {
    const snaps = await db.getAll(...ids.slice(offset, offset + 100).map(id => db.collection("results").doc(id)));
    for (const snap of snaps) if (snap.exists) results.push({ ...snap.data(), id: snap.id });
  }
  return calculateBadges({ matches, votes, users: objects(usersSnap), teams: objects(teamsSnap), results });
}

async function markDirty(db) {
  await db.doc(STATE_PATH).set({ dirty: true, revision: FieldValue.increment(1), changedAt: FieldValue.serverTimestamp() }, { merge: true });
}

async function refreshBadges(db, { force = false, now = new Date() } = {}) {
  const stateRef = db.doc(STATE_PATH);
  const owner = randomUUID();
  const year = seasonYear(now);
  const lease = await db.runTransaction(async tx => {
    const snap = await tx.get(stateRef);
    const state = snap.data() || {};
    if (millis(state.leaseUntil) > now.getTime()) return { skip: "busy" };
    if (!force && state.version === VERSION && state.season === year && state.dirty === false) return { skip: "unchanged" };
    tx.set(stateRef, { leaseOwner: owner, leaseUntil: Timestamp.fromMillis(now.getTime() + 330000) }, { merge: true });
    return { revision: Number(state.revision || 0) };
  });
  if (lease.skip) return { skipped: lease.skip };
  try {
    const calculation = await loadCalculation(db, now);
    const summary = await db.runTransaction(async tx => {
      const refs = PERIODS.map(period => db.collection("rankingSnapshots").doc(period));
      // All reads precede all writes; concurrent point/directory updates cause
      // Firestore to retry against fresh arrays instead of losing those edits.
      const [stateSnap, ...snaps] = await Promise.all([tx.get(stateRef), ...refs.map(ref => tx.get(ref))]);
      const state = stateSnap.data() || {};
      if (state.leaseOwner !== owner) return { skipped: "lease-lost" };
      if (Number(state.revision || 0) !== lease.revision) {
        tx.set(stateRef, { dirty: true, leaseOwner: FieldValue.delete(), leaseUntil: FieldValue.delete() }, { merge: true });
        return { skipped: "source-changed" };
      }
      const changes = {};
      for (let i = 0; i < snaps.length; i += 1) {
        const data = snaps[i].data();
        if (!data || data.schemaVersion !== 90 || !Array.isArray(data.individuals)) {
          // Leave the repair pending until the existing ranking bootstrap is
          // ready; never claim success on absent/incompatible snapshots.
          tx.set(stateRef, { dirty: true, leaseOwner: FieldValue.delete(), leaseUntil: FieldValue.delete() }, { merge: true });
          return { skipped: "rankings-not-ready" };
        }
        changes[PERIODS[i]] = patchIndividuals(data.individuals, calculation);
      }
      for (let i = 0; i < refs.length; i += 1) {
        const change = changes[PERIODS[i]];
        if (change.changed) tx.update(refs[i], { individuals: change.rows });
      }
      const counts = Object.fromEntries(PERIODS.map(period => [period, changes[period].changed]));
      tx.set(stateRef, {
        version: VERSION, season: year, dirty: false, processedRevision: lease.revision,
        repairedAt: FieldValue.serverTimestamp(), users: calculation.badges.size,
        changedRows: counts, resolvedPredictions: calculation.resolvedPredictions,
        leaseOwner: FieldValue.delete(), leaseUntil: FieldValue.delete(),
      }, { merge: true });
      return { users: calculation.badges.size, changedRows: counts };
    });
    return summary;
  } catch (error) {
    await db.runTransaction(async tx => {
      const state = (await tx.get(stateRef)).data() || {};
      if (state.leaseOwner === owner) tx.set(stateRef, { dirty: true, leaseOwner: FieldValue.delete(), leaseUntil: FieldValue.delete() }, { merge: true });
    });
    throw error;
  }
}

module.exports = { VERSION, STATE_PATH, PERIODS, automaticBadge, finalResult, calculateBadges, patchIndividuals, loadCalculation, markDirty, refreshBadges };
