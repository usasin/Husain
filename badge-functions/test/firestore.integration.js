"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { refreshBadges, markDirty, STATE_PATH, PERIODS } = require("../badges");
if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8084") throw Error("Emulator-only integration test: refusing production access");
initializeApp({ projectId: "demo-prono4-badges" });
const db = getFirestore();
const handlers = require("../index");
const { ensureEuropaFixtures, refreshEuropaManifest } = require("../manual-fixtures");
const now = new Date("2026-10-15T05:00:00Z");
const date = Timestamp.fromDate(new Date("2026-10-10T12:00:00Z"));
const row = { id: "new", name: "Test player", points: 160, votes: 101, resolvedVotes: 87, correct: 50, avatar: "img:unchanged", teamId: "t", byCompetition: { cl: { points: 41, votes: 18 } }, custom: { preserve: true }, badge: "FOOTIX", knowledgeScore: 38, resolved: 30 };
async function seed() {
  const collections = ["rankingSnapshots", "fixtureManifests", "system", "users", "teams", "matches", "votes", "results"];
  for (const collection of collections) {
    const snap = await db.collection(collection).get();
    const batch = db.batch(); for (const doc of snap.docs) batch.delete(doc.ref); await batch.commit();
  }
  const batch = db.batch();
  batch.set(db.doc("users/new"), { name: "Test player", avatar: "img:original-photo", teamId: "t" });
  batch.set(db.doc("users/old"), { isArchived: true, migratedTo: "new", avatar: "img:old-photo" });
  batch.set(db.doc("users/other"), { name: "Other", avatar: "img:other-photo" });
  batch.set(db.doc("teams/t"), { memberIds: ["new"], icon: "img:team-original", points: 999 });
  for (let i = 0; i < 30; i++) {
    const id = `m${i}`;
    batch.set(db.doc(`matches/${id}`), { kickoffAt: date, competitionId: "manual-test" });
    const vote = { userId: "new", matchId: id, prediction: i < 16 ? "HOME" : "AWAY", updatedAt: date, ...(i === 0 ? { exactHome: 2, exactAway: 1 } : {}) };
    batch.set(db.doc(`votes/new__${id}`), vote);
    batch.set(db.doc(`votes/old__${id}`), vote);
    batch.set(db.doc(`results/${id}`), { status: "FINISHED", result: "HOME", homeScore: 2, awayScore: 1 });
  }
  for (const period of PERIODS) batch.set(db.doc(`rankingSnapshots/${period}`), { schemaVersion: 90, individuals: [row, { id: "other", points: 72, avatar: "img:other", custom: 1, badge: "FOOTIX", knowledgeScore: 50, resolved: 0 }], teams: [{ icon: "img:keep", points: 123 }], competitionRankingsVersion: 1, customRoot: "unchanged" });
  await batch.commit();
}
const snapshotData = async () => Promise.all(PERIODS.map(async p => (await db.doc(`rankingSnapshots/${p}`).get()).data()));
function proxyDb(override) { return new Proxy(db, { get(target, key) { if (key in override) return override[key]; const value = target[key]; return typeof value === "function" ? value.bind(target) : value; } }); }

test("general repair persists all four badges while every other snapshot/profile/team field stays identical", async () => {
  await seed(); const before = await snapshotData();
  const profilesBefore = (await db.collection("users").get()).docs.map(d => d.data());
  const teamBefore = (await db.doc("teams/t").get()).data();
  const summary = await refreshBadges(db, { now });
  assert.equal(summary.users, 2);
  assert.deepEqual(summary.changedRows, { general: 1, week: 1, month: 1, gameSeason: 1 });
  const after = await snapshotData();
  for (let i = 0; i < 4; i++) {
    assert.deepEqual(after[i], { ...before[i], individuals: [{ ...row, badge: "AMATEUR", knowledgeScore: 54, resolved: 30 }, before[i].individuals[1]] });
  }
  assert.deepEqual((await db.collection("users").get()).docs.map(d => d.data()), profilesBefore);
  assert.deepEqual((await db.doc("teams/t").get()).data(), teamBefore);
  const state = (await db.doc(STATE_PATH).get()).data();
  assert.equal(state.dirty, false); assert.equal(state.resolvedPredictions, 30); assert.equal(state.leaseOwner, undefined);
  const lightDb = proxyDb({ collection() { throw Error("An unchanged tick must never rescan collections"); } });
  assert.deepEqual(await refreshBadges(lightDb, { now }), { skipped: "unchanged" });
});
test("a corrected result dirties and updates all badges again without an app build", async () => {
  await seed(); await refreshBadges(db, { now });
  await db.doc("results/m0").update({ result: "AWAY", homeScore: 1, awayScore: 2 }); await markDirty(db);
  await refreshBadges(db, { now });
  for (const data of await snapshotData()) { assert.equal(data.individuals[0].knowledgeScore, 50); assert.equal(data.individuals[0].points, 160); }
});
test("a source change during calculation postpones the repair rather than publishing stale values", async () => {
  await seed(); const before = await snapshotData(); let once = false;
  const racingDb = proxyDb({ async getAll(...refs) { const snaps = await db.getAll(...refs); if (!once) { once = true; await markDirty(db); } return snaps; } });
  assert.deepEqual(await refreshBadges(racingDb, { now }), { skipped: "source-changed" });
  assert.deepEqual(await snapshotData(), before);
  assert.equal((await db.doc(STATE_PATH).get()).data().dirty, true);
  assert.equal((await refreshBadges(db, { now })).users, 2);
});
test("point changes made during the calculation are read fresh and preserved", async () => {
  await seed(); let once = false;
  const racingDb = proxyDb({ async getAll(...refs) { const snaps = await db.getAll(...refs); if (!once) { once = true; await db.doc("rankingSnapshots/general").update({ individuals: [{ ...row, points: 999, avatar: "img:new-avatar" }] }); } return snaps; } });
  await refreshBadges(racingDb, { now });
  const data = (await db.doc("rankingSnapshots/general").get()).data();
  assert.equal(data.individuals[0].badge, "AMATEUR"); assert.equal(data.individuals[0].points, 999); assert.equal(data.individuals[0].avatar, "img:new-avatar");
});
test("missing rankings leave the repair pending and do not partially write other periods", async () => {
  await seed(); await db.doc("rankingSnapshots/gameSeason").delete(); const before = await snapshotData();
  assert.deepEqual(await refreshBadges(db, { now }), { skipped: "rankings-not-ready" });
  assert.deepEqual(await snapshotData(), before); assert.equal((await db.doc(STATE_PATH).get()).data().dirty, true);
});
test("read failures release the lease and keep repair pending for retry", async () => {
  await seed(); const before = await snapshotData();
  const brokenDb = proxyDb({ async getAll() { throw Error("temporary read failure"); } });
  await assert.rejects(refreshBadges(brokenDb, { now }), /temporary read failure/);
  assert.deepEqual(await snapshotData(), before);
  const state = (await db.doc(STATE_PATH).get()).data(); assert.equal(state.dirty, true); assert.equal(state.leaseOwner, undefined);
});
test("actual result trigger detects live-to-final with an unchanged score, and ignores timestamp-only refreshes", async () => {
  await seed(); await refreshBadges(db, { now });
  const snap = value => ({ exists: value !== null, data: () => value });
  const event = (before, after) => ({ data: { before: snap(before), after: snap(after) }, params: { matchId: "m0" } });
  const final = { status: "FINISHED", result: "HOME", homeScore: 2, awayScore: 1 };
  await handlers.markAutomaticBadgesOnResult.run(event(final, { ...final, lastApiSyncAt: Timestamp.now() }));
  assert.equal((await db.doc(STATE_PATH).get()).data().dirty, false);
  await handlers.markAutomaticBadgesOnResult.run(event({ ...final, status: "IN_PLAY" }, final));
  assert.equal((await db.doc(STATE_PATH).get()).data().dirty, true);
});
test("actual migration triggers schedule repair, while avatars and badge-only writes never create a loop", async () => {
  await seed(); await refreshBadges(db, { now });
  const event = (before, after) => ({ data: { before: { exists: true, data: () => before }, after: { exists: true, data: () => after } }, params: {} });
  await handlers.markAutomaticBadgesOnProfile.run(event({ teamId: "t", avatar: "img:old" }, { teamId: "t", avatar: "img:new" }));
  await handlers.markAutomaticBadgesOnRankingRebuild.run(event({ schemaVersion: 90, individuals: [row] }, { schemaVersion: 90, individuals: [{ ...row, badge: "AMATEUR" }] }));
  assert.equal((await db.doc(STATE_PATH).get()).data().dirty, false);
  await handlers.markAutomaticBadgesOnRankingRebuild.run(event({ schemaVersion: 90, individuals: [row] }, { schemaVersion: 90, individuals: [row, { id: "late-profile" }] }));
  assert.equal((await db.doc(STATE_PATH).get()).data().dirty, true);
  await refreshBadges(db, { now });
  await handlers.markAutomaticBadgesOnProfile.run(event({ teamId: "t" }, { teamId: null, isArchived: true, migratedTo: "new" }));
  assert.equal((await db.doc(STATE_PATH).get()).data().dirty, true);
});
test("Europa initialization creates eight OM fixtures, no scores, and never overwrites later admin edits", async () => {
  await seed(); const rankingBefore = await snapshotData();
  const result = await ensureEuropaFixtures(db, now); assert.equal(result.created, 8);
  const calendar = (await db.doc("fixtureManifests/europa-league").get()).data();
  assert.equal(calendar.rows.length, 8); assert.ok(calendar.rows.every(row => row.result === null && row.allowsDraw));
  const ref = db.doc("matches/manual_el_2026_om_2");
  await ref.update({ venue: "Admin edit", kickoffAt: Timestamp.fromDate(new Date("2026-10-15T20:00:00Z")) });
  const edited = (await ref.get()).data();
  assert.deepEqual(await ensureEuropaFixtures(db, now), { skipped: "ready" });
  assert.deepEqual((await ref.get()).data(), edited);
  assert.deepEqual(await snapshotData(), rankingBefore);
  assert.equal((await db.collection("results").get()).size, 30, "the eight fixtures must not create results");
});
test("a manual final result reaches the shared calendar, without changing other leagues, rankings or photos", async () => {
  await seed(); await ensureEuropaFixtures(db, now);
  await db.doc("fixtureManifests/champions-league").set({ version: "existing", rows: [{ id: "existing-match", homeCrestUrl: "original-image" }] });
  await db.doc("system/fixtureManifestMeta").set({ versions: { "champions-league": "existing" } });
  const rankingBefore = await snapshotData();
  const before = (await db.doc("fixtureManifests/europa-league").get()).data();
  const result = { competitionId: "europa-league", status: "FINISHED", homeScore: 3, awayScore: 1, result: "HOME", source: "manual" };
  await db.doc("results/manual_el_2026_om_2").set(result);
  await handlers.publishEuropaLeagueResult.run({ params: { matchId: "manual_el_2026_om_2" }, data: { before: { exists: false }, after: { exists: true, data: () => result } } });
  const after = (await db.doc("fixtureManifests/europa-league").get()).data();
  assert.notEqual(after.version, before.version);
  assert.equal(after.rows.find(row => row.id === "manual_el_2026_om_2").homeScore, 3);
  assert.deepEqual(await refreshEuropaManifest(db, now), { changed: false, matches: 8 });
  assert.deepEqual((await db.doc("fixtureManifests/champions-league").get()).data(), { version: "existing", rows: [{ id: "existing-match", homeCrestUrl: "original-image" }] });
  assert.deepEqual((await db.doc("system/fixtureManifestMeta").get()).data(), { versions: { "champions-league": "existing" } });
  assert.deepEqual(await snapshotData(), rankingBefore);
  assert.equal((await db.doc("users/new").get()).data().avatar, "img:original-photo");
});
test("new or cancelled manual fixtures are published to every client through the same calendar", async () => {
  await seed(); await ensureEuropaFixtures(db, now);
  const fixture = { competitionId: "europa-league", homeName: "Lyon", awayName: "Celtic", homeCode: "LYO", awayCode: "CELT", kickoffAt: date };
  const event = (before, after) => ({ params: { matchId: "manual_el_extra" }, data: { before: { exists: !!before, data: () => before }, after: { exists: !!after, data: () => after } } });
  await db.doc("matches/manual_el_extra").set(fixture);
  await handlers.publishEuropaLeagueMatch.run(event(null, fixture));
  assert.equal((await db.doc("fixtureManifests/europa-league").get()).data().rows.length, 9);
  await db.doc("matches/manual_el_extra").update({ status: "CANCELLED" });
  await handlers.publishEuropaLeagueMatch.run(event(fixture, { ...fixture, status: "CANCELLED" }));
  assert.equal((await db.doc("fixtureManifests/europa-league").get()).data().rows.length, 8);
});
test("API result updates do not invoke the Europa calendar publisher", async () => {
  await seed();
  await handlers.publishEuropaLeagueResult.run({ params: { matchId: "fd_123" }, data: { before: { exists: false }, after: { exists: true, data: () => ({ status: "FINISHED", homeScore: 1, awayScore: 0 }) } } });
  assert.equal((await db.doc("fixtureManifests/europa-league").get()).exists, false);
});
test.after(async () => db.terminate());
