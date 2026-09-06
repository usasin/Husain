"use strict";

const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

const API_BASE = "https://api.football-data.org/v4";

// Uniquement les compétitions essentielles voulues pour PRONO4.
// France, Angleterre, Espagne, Allemagne + Ligue des champions.
const COMPETITIONS = [
  { apiCode: "FL1", appId: "ligue-1", name: "Ligue 1", kind: "league" },
  { apiCode: "PL", appId: "premier-league", name: "Premier League", kind: "league" },
  { apiCode: "CL", appId: "champions-league", name: "Ligue des champions", kind: "europe" },
  { apiCode: "PD", appId: "la-liga", name: "LaLiga", kind: "league" },
  { apiCode: "BL1", appId: "bundesliga", name: "Bundesliga", kind: "league" },
];

// Anciennes compétitions que les versions précédentes ont pu écrire.
// On enlève seulement leurs MATCHS/CLASSEMENTS de l'affichage Firestore.
// On ne touche jamais aux votes/résultats historiques des utilisateurs.
const RETIRED_COMPETITION_IDS = [
  "serie-a",
  "primeira-liga",
  "eredivisie",
  "championship",
  "brasileirao",
  "europa-league",
  "conference-league",
  "coupe-de-france",
  "fa-cup",
  "efl-cup",
  "copa-del-rey",
  "dfb-pokal",
  "super-cups",
  "world-cup",
  "euro",
];

const KNOCKOUT_STAGES = new Set([
  "FINAL",
  "THIRD_PLACE",
  "SEMI_FINALS",
  "QUARTER_FINALS",
  "LAST_16",
  "LAST_32",
  "LAST_64",
  "ROUND_4",
  "ROUND_3",
  "ROUND_2",
  "ROUND_1",
  "PRELIMINARY_ROUND",
  "QUALIFICATION",
  "QUALIFICATION_ROUND_1",
  "QUALIFICATION_ROUND_2",
  "QUALIFICATION_ROUND_3",
  "PLAYOFF_ROUND_1",
  "PLAYOFF_ROUND_2",
  "PLAYOFFS",
]);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let lastApiCallAt = 0;

async function waitForFreeTierSlot() {
  // Free Tier = 10 appels/min. On garde une marge volontaire : 1 appel/6,5 s.
  const elapsed = Date.now() - lastApiCallAt;
  const wait = Math.max(0, 6500 - elapsed);
  if (wait > 0) await sleep(wait);
  lastApiCallAt = Date.now();
}

function currentSeasonStartYear(now = new Date()) {
  return now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
}

function slugCode(value) {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 4);
}

function teamCode(team) {
  const tla = slugCode(team?.tla);
  if (tla.length >= 2) return tla;
  const short = slugCode(team?.shortName);
  if (short.length >= 2) return short.slice(0, 3);
  const name = slugCode(team?.name);
  return (name || "TBD").slice(0, 3).padEnd(3, "X");
}

function humanStage(stage) {
  const value = String(stage ?? "").trim();
  if (!value) return "";
  const labels = {
    REGULAR_SEASON: "Saison régulière",
    GROUP_STAGE: "Phase de groupes",
    LEAGUE_STAGE: "Phase de ligue",
    PLAYOFFS: "Barrages",
    PLAYOFF_ROUND_1: "Barrages",
    PLAYOFF_ROUND_2: "Barrages",
    LAST_64: "1/32 de finale",
    LAST_32: "1/16 de finale",
    LAST_16: "1/8 de finale",
    QUARTER_FINALS: "Quarts de finale",
    SEMI_FINALS: "Demi-finales",
    FINAL: "Finale",
    THIRD_PLACE: "3e place",
  };
  return labels[value] || value.replaceAll("_", " ");
}

function allowsDrawFor(comp, stage) {
  if (comp.kind === "league") return true;
  return !KNOCKOUT_STAGES.has(String(stage ?? "").toUpperCase());
}

function outcome(home, away) {
  if (!Number.isFinite(home) || !Number.isFinite(away)) return null;
  if (home > away) return "HOME";
  if (away > home) return "AWAY";
  return "DRAW";
}

function matchDocument(apiMatch, comp) {
  const kickoff = new Date(apiMatch.utcDate);
  if (Number.isNaN(kickoff.getTime())) return null;

  const homeName = String(apiMatch.homeTeam?.name || apiMatch.homeTeam?.shortName || "Domicile").trim();
  const awayName = String(apiMatch.awayTeam?.name || apiMatch.awayTeam?.shortName || "Extérieur").trim();
  const homeCode = teamCode(apiMatch.homeTeam);
  const awayCode = teamCode(apiMatch.awayTeam);
  const externalId = String(apiMatch.id ?? "").trim();
  if (!externalId || !homeCode || !awayCode) return null;

  const docId = `fd_${externalId}`;
  return {
    id: docId,
    data: {
      matchId: docId,
      externalMatchId: externalId,
      source: "football-data.org",
      apiCompetitionCode: comp.apiCode,
      competitionId: comp.appId,
      homeCode,
      awayCode,
      homeName,
      awayName,
      homeCrestUrl: String(apiMatch.homeTeam?.crest || "").trim(),
      awayCrestUrl: String(apiMatch.awayTeam?.crest || "").trim(),
      homeExternalId: apiMatch.homeTeam?.id ?? null,
      awayExternalId: apiMatch.awayTeam?.id ?? null,
      kickoffAt: admin.firestore.Timestamp.fromDate(kickoff),
      venue: String(apiMatch.venue ?? "").trim(),
      stage: humanStage(apiMatch.stage),
      stageCode: String(apiMatch.stage ?? "").trim(),
      matchday: Number.isFinite(apiMatch.matchday) ? Number(apiMatch.matchday) : null,
      status: String(apiMatch.status ?? "").trim(),
      allowsDraw: allowsDrawFor(comp, apiMatch.stage),
      lastApiSyncAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

function resultDocument(apiMatch, matchId) {
  const status = String(apiMatch.status ?? "").trim().toUpperCase();
  const score = apiMatch.score?.fullTime || {};
  const home = Number.isFinite(score.home) ? Number(score.home) : null;
  const away = Number.isFinite(score.away) ? Number(score.away) : null;
  const result = home != null && away != null ? outcome(home, away) : null;

  const data = {
    matchId,
    status,
    liveStatus: status,
    source: "football-data.org",
    lastApiSyncAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (home != null && away != null) {
    data.homeScore = home;
    data.awayScore = away;
    data.result = result;
  }

  return data;
}

async function apiGet(token, path) {
  await waitForFreeTierSlot();
  const url = `${API_BASE}${path}`;
  let response = await fetch(url, {
    headers: {
      "X-Auth-Token": token,
      Accept: "application/json",
      "User-Agent": "PRONO4/2026.2 FirebaseSync",
    },
  });

  if (response.status === 429) {
    const seconds = Number(response.headers.get("x-requestcounter-reset")) || 60;
    await sleep(Math.max(5, seconds + 1) * 1000);
    lastApiCallAt = 0;
    await waitForFreeTierSlot();
    response = await fetch(url, {
      headers: {
        "X-Auth-Token": token,
        Accept: "application/json",
        "User-Agent": "PRONO4/2026.2 FirebaseSync",
      },
    });
  }

  if (!response.ok) {
    const text = (await response.text()).slice(0, 500);
    const error = new Error(`HTTP ${response.status} ${text}`);
    error.httpStatus = response.status;
    throw error;
  }
  return response.json();
}

async function fetchCompetition(token, comp, season) {
  const json = await apiGet(
    token,
    `/competitions/${encodeURIComponent(comp.apiCode)}/matches?season=${encodeURIComponent(season)}`
  );
  return Array.isArray(json.matches) ? json.matches : [];
}

async function fetchStandings(token, comp, season) {
  const json = await apiGet(
    token,
    `/competitions/${encodeURIComponent(comp.apiCode)}/standings?season=${encodeURIComponent(season)}`
  );
  const standings = Array.isArray(json.standings) ? json.standings : [];
  const selected = standings.find((s) => String(s?.type || "").toUpperCase() === "TOTAL") || standings[0];
  const table = Array.isArray(selected?.table) ? selected.table : [];
  return {
    competition: json.competition || {},
    area: json.area || {},
    season: json.season || {},
    type: String(selected?.type || "TOTAL"),
    stage: String(selected?.stage || ""),
    group: String(selected?.group || ""),
    table,
  };
}

async function writeCompetition(db, comp, matches) {
  const writer = db.bulkWriter();
  let matchWrites = 0;
  let resultWrites = 0;
  let clubWrites = 0;
  const clubs = new Map();

  writer.onWriteError((error) => {
    logger.error("Firestore BulkWriter error", {
      code: error.code,
      message: error.message,
      documentRef: error.documentRef?.path,
      failedAttempts: error.failedAttempts,
    });
    return error.failedAttempts < 3;
  });

  for (const apiMatch of matches) {
    for (const team of [apiMatch.homeTeam, apiMatch.awayTeam]) {
      const externalClubId = String(team?.id ?? "").trim();
      if (!externalClubId) continue;
      clubs.set(externalClubId, {
        externalClubId,
        name: String(team?.name || team?.shortName || "").trim(),
        shortName: String(team?.shortName || team?.name || "").trim(),
        tla: String(team?.tla || "").trim(),
        crestUrl: String(team?.crest || "").trim(),
      });
    }

    const parsed = matchDocument(apiMatch, comp);
    if (!parsed) continue;

    if (String(apiMatch.status ?? "").toUpperCase() === "CANCELLED") {
      writer.delete(db.collection("matches").doc(parsed.id));
      matchWrites += 1;
      continue;
    }

    writer.set(db.collection("matches").doc(parsed.id), parsed.data, { merge: true });
    matchWrites += 1;

    const status = String(apiMatch.status ?? "").toUpperCase();
    if (["IN_PLAY", "PAUSED", "EXTRA_TIME", "PENALTY_SHOOTOUT", "FINISHED", "AWARDED"].includes(status)) {
      writer.set(
        db.collection("results").doc(parsed.id),
        resultDocument(apiMatch, parsed.id),
        { merge: true }
      );
      resultWrites += 1;
    }
  }

  for (const club of clubs.values()) {
    writer.set(
      db.collection("clubs").doc(`fd_${club.externalClubId}`),
      {
        ...club,
        source: "football-data.org",
        competitionIds: admin.firestore.FieldValue.arrayUnion(comp.appId),
        lastApiSyncAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    clubWrites += 1;
  }

  await writer.close();
  return { matchWrites, resultWrites, clubWrites };
}

function standingRow(row) {
  const team = row?.team || {};
  return {
    position: Number(row?.position || 0),
    teamId: team?.id ?? null,
    teamName: String(team?.name || team?.shortName || "Club").trim(),
    shortName: String(team?.shortName || team?.name || "Club").trim(),
    tla: String(team?.tla || "").trim(),
    crestUrl: String(team?.crest || "").trim(),
    played: Number(row?.playedGames || 0),
    won: Number(row?.won || 0),
    draw: Number(row?.draw || 0),
    lost: Number(row?.lost || 0),
    goalsFor: Number(row?.goalsFor || 0),
    goalsAgainst: Number(row?.goalsAgainst || 0),
    goalDifference: Number(row?.goalDifference || 0),
    points: Number(row?.points || 0),
    form: String(row?.form || "").trim(),
  };
}

async function writeStandings(db, comp, payload, season) {
  const rows = payload.table.map(standingRow).filter((r) => r.position > 0);
  await db.collection("competitionStandings").doc(comp.appId).set(
    {
      competitionId: comp.appId,
      apiCode: comp.apiCode,
      competitionName: String(payload.competition?.name || comp.name),
      emblemUrl: String(payload.competition?.emblem || "").trim(),
      areaName: String(payload.area?.name || comp.name).trim(),
      season,
      standingType: payload.type,
      stage: payload.stage,
      group: payload.group,
      rows,
      source: "football-data.org",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return rows.length;
}

async function cleanupRetiredCompetitions(db) {
  if (RETIRED_COMPETITION_IDS.length === 0) return 0;
  let removed = 0;
  // Firestore limite les requêtes IN : on nettoie par petits lots robustes.
  for (let i = 0; i < RETIRED_COMPETITION_IDS.length; i += 10) {
    const ids = RETIRED_COMPETITION_IDS.slice(i, i + 10);
    const snap = await db.collection("matches").where("competitionId", "in", ids).get();
    if (!snap.empty) {
      const writer = db.bulkWriter();
      for (const doc of snap.docs) writer.delete(doc.ref);
      await writer.close();
      removed += snap.size;
    }
  }
  // Même s'il n'y avait plus de matchs, supprimer les anciens classements.
  for (const id of RETIRED_COMPETITION_IDS) {
    await db.collection("competitionStandings").doc(id).delete().catch(() => null);
  }
  return removed;
}

async function syncClubMatches({ db, token, season, source = "manual" }) {
  if (!token || String(token).trim().length < 8) {
    throw new Error("FOOTBALL_DATA_TOKEN absent ou invalide.");
  }

  const targetSeason = Number.isFinite(Number(season))
    ? Number(season)
    : currentSeasonStartYear();

  const startedAt = Date.now();
  lastApiCallAt = 0;
  const summary = {
    season: targetSeason,
    source,
    syncedCompetitions: [],
    skippedCompetitions: [],
    standingsErrors: [],
    matchWrites: 0,
    resultWrites: 0,
    clubWrites: 0,
    standingsRows: 0,
    retiredMatchesRemoved: 0,
  };

  await db.collection("system").doc("clubMatchesSync").set(
    {
      state: "running",
      season: targetSeason,
      source,
      competitionCount: COMPETITIONS.length,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  try {
    summary.retiredMatchesRemoved = await cleanupRetiredCompetitions(db);
  } catch (error) {
    logger.warn("Nettoyage des anciennes compétitions ignoré", {
      error: String(error?.message || error),
    });
  }

  for (const comp of COMPETITIONS) {
    let importedMatches = 0;
    let importedStandings = 0;

    try {
      const matches = await fetchCompetition(String(token).trim(), comp, targetSeason);
      const writes = await writeCompetition(db, comp, matches);
      importedMatches = matches.length;
      summary.matchWrites += writes.matchWrites;
      summary.resultWrites += writes.resultWrites;
      summary.clubWrites += writes.clubWrites;
    } catch (error) {
      summary.skippedCompetitions.push({
        apiCode: comp.apiCode,
        appId: comp.appId,
        error: String(error?.message || error).slice(0, 300),
      });
      logger.warn("Calendrier ignoré pendant la synchronisation", {
        apiCode: comp.apiCode,
        appId: comp.appId,
        error: String(error?.message || error),
      });
    }

    try {
      const standings = await fetchStandings(String(token).trim(), comp, targetSeason);
      importedStandings = await writeStandings(db, comp, standings, targetSeason);
      summary.standingsRows += importedStandings;
    } catch (error) {
      summary.standingsErrors.push({
        apiCode: comp.apiCode,
        appId: comp.appId,
        error: String(error?.message || error).slice(0, 300),
      });
      logger.warn("Classement ignoré pendant la synchronisation", {
        apiCode: comp.apiCode,
        appId: comp.appId,
        error: String(error?.message || error),
      });
    }

    if (importedMatches > 0 || importedStandings > 0) {
      summary.syncedCompetitions.push({
        apiCode: comp.apiCode,
        appId: comp.appId,
        matches: importedMatches,
        standingRows: importedStandings,
      });
      logger.info("Compétition synchronisée", {
        apiCode: comp.apiCode,
        appId: comp.appId,
        matches: importedMatches,
        standingRows: importedStandings,
      });
    }
  }

  if (summary.syncedCompetitions.length === 0) {
    await db.collection("system").doc("clubMatchesSync").set(
      {
        state: "error",
        season: targetSeason,
        source,
        error: "Aucune compétition gratuite n'a pu être synchronisée.",
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    throw new Error("Aucune compétition gratuite n'a pu être synchronisée. Vérifie le token football-data.org.");
  }

  summary.durationMs = Date.now() - startedAt;
  await db.collection("system").doc("clubMatchesSync").set(
    {
      state: "ok",
      season: targetSeason,
      source,
      syncedCompetitionCount: summary.syncedCompetitions.length,
      skippedCompetitionCount: summary.skippedCompetitions.length,
      standingsErrorCount: summary.standingsErrors.length,
      matchWrites: summary.matchWrites,
      resultWrites: summary.resultWrites,
      clubWrites: summary.clubWrites,
      standingsRows: summary.standingsRows,
      retiredMatchesRemoved: summary.retiredMatchesRemoved,
      durationMs: summary.durationMs,
      lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return summary;
}

module.exports = {
  COMPETITIONS,
  currentSeasonStartYear,
  syncClubMatches,
};
