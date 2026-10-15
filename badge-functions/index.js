"use strict";
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { finalResult, markDirty, refreshBadges } = require("./badges");
const { COMPETITION, PREFIX, refreshEuropaManifest, ensureEuropaFixtures } = require("./manual-fixtures");
if (!getApps().length) initializeApp();
const db = getFirestore();
const triggerOptions = document => ({ document, region: "europe-west1", memory: "256MiB", timeoutSeconds: 60, maxInstances: 2, retry: true });
const data = snap => snap?.exists ? snap.data() : null;
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const fields = (value, keys) => value ? keys.map(key => value[key] ?? null) : null;

exports.markAutomaticBadgesOnResult = onDocumentWritten(triggerOptions("results/{matchId}"), async event => {
  if (!same(finalResult(data(event.data?.before)), finalResult(data(event.data?.after)))) await markDirty(db);
});
exports.markAutomaticBadgesOnVote = onDocumentWritten(triggerOptions("votes/{voteId}"), async event => {
  const keys = ["userId", "matchId", "prediction", "exactHome", "exactAway"];
  if (!same(fields(data(event.data?.before), keys), fields(data(event.data?.after), keys))) await markDirty(db);
});
exports.markAutomaticBadgesOnProfile = onDocumentWritten(triggerOptions("users/{uid}"), async event => {
  const keys = ["isArchived", "migratedTo", "teamId"];
  if (!same(fields(data(event.data?.before), keys), fields(data(event.data?.after), keys))) await markDirty(db);
});
exports.markAutomaticBadgesOnTeam = onDocumentWritten(triggerOptions("teams/{teamId}"), async event => {
  const members = value => value ? (Array.isArray(value.memberIds) ? value.memberIds.map(String).sort() : []) : null;
  if (!same(members(data(event.data?.before)), members(data(event.data?.after)))) await markDirty(db);
});
exports.markAutomaticBadgesOnMatch = onDocumentWritten(triggerOptions("matches/{matchId}"), async event => {
  const kickoff = value => value?.kickoffAt?.toMillis?.() ?? null;
  if (kickoff(data(event.data?.before)) !== kickoff(data(event.data?.after))) await markDirty(db);
});
exports.markAutomaticBadgesOnRankingRebuild = onDocumentWritten(triggerOptions("rankingSnapshots/general"), async event => {
  const generation = value => value ? [value.schemaVersion, value.generatedAt?.toMillis?.() ?? null,
    (Array.isArray(value.individuals) ? value.individuals.map(row => String(row.id || "")).sort() : [])] : null;
  // Normal point changes and our own badge repair do not create a loop.
  if (!same(generation(data(event.data?.before)), generation(data(event.data?.after)))) await markDirty(db);
});
exports.publishEuropaLeagueMatch = onDocumentWritten(triggerOptions("matches/{matchId}"), async event => {
  const before = data(event.data?.before);
  const after = data(event.data?.after);
  if (before?.competitionId === COMPETITION || after?.competitionId === COMPETITION) await refreshEuropaManifest(db);
});
exports.publishEuropaLeagueResult = onDocumentWritten(triggerOptions("results/{matchId}"), async event => {
  const before = data(event.data?.before);
  const after = data(event.data?.after);
  if (event.params.matchId.startsWith(PREFIX) || before?.competitionId === COMPETITION || after?.competitionId === COMPETITION) await refreshEuropaManifest(db);
});
exports.refreshAutomaticBadgesScheduled = onSchedule({
  schedule: "every 15 minutes", timeZone: "Europe/Paris", region: "europe-west1",
  memory: "1GiB", timeoutSeconds: 300, maxInstances: 1, concurrency: 1,
  retryCount: 3, minBackoffSeconds: 30, maxBackoffSeconds: 300,
}, async () => {
  try { logger.info("Europa League manual calendar", await ensureEuropaFixtures(db)); }
  catch (error) { logger.error("Europa League initialization deferred", error); }
  const result = await refreshBadges(db);
  logger.info("Automatic badges refreshed", result);
});
