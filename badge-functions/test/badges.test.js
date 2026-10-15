"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { automaticBadge, finalResult, calculateBadges, patchIndividuals } = require("../badges");
const ts = value => Timestamp.fromMillis(value);
function fixture({ count = 30, correct = 16, exact = 1, owner = "new" } = {}) {
  return {
    users: [{ id: "new" }], teams: [],
    matches: Array.from({ length: count }, (_, i) => ({ id: `m${String(i).padStart(2, "0")}`, kickoffAt: ts(10000 + i) })),
    votes: Array.from({ length: count }, (_, i) => ({ id: `${owner}__m${String(i).padStart(2, "0")}`, userId: owner, prediction: i < correct ? "HOME" : "AWAY", ...(i < exact ? { exactHome: 2, exactAway: 1 } : {}), updatedAt: ts(1000) })),
    results: Array.from({ length: count }, (_, i) => ({ id: `m${String(i).padStart(2, "0")}`, status: "FINISHED", result: "HOME", homeScore: 2, awayScore: 1 })),
  };
}
test("30 final predictions, 16 correct and one exact => Amateur 54", () => {
  assert.deepEqual(calculateBadges(fixture()).badges.get("new"), { badge: "AMATEUR", knowledgeScore: 54, resolved: 30 });
});
test("new final results replace a stale Footix badge for every player and period", () => {
  const f = fixture(); f.users.push({ id: "other" });
  f.votes.push(...f.votes.map(v => ({ ...v, id: v.id.replace("new__", "other__"), userId: "other" })));
  const calculation = calculateBadges(f);
  for (let i = 0; i < 4; i++) {
    const changed = patchIndividuals(f.users.map(u => ({ id: u.id, badge: "FOOTIX", knowledgeScore: 38, resolved: 30 })), calculation);
    assert.equal(changed.changed, 2);
    assert.ok(changed.rows.every(r => r.badge === "AMATEUR" && r.knowledgeScore === 54));
  }
});
test("recovery chains merge original and copied votes once per match", () => {
  const f = fixture(); f.users.push({ id: "old", isArchived: true, migratedTo: "middle" }, { id: "middle", isArchived: true, migratedTo: "new" });
  f.votes.push(...f.votes.map(v => ({ ...v, id: v.id.replace("new__", "old__"), userId: "middle" })));
  const calculation = calculateBadges(f);
  assert.equal(calculation.resolvedPredictions, 30);
  assert.equal(calculation.badges.size, 1);
  assert.equal(calculation.badges.get("new").knowledgeScore, 54);
});
test("canonical destination vote wins over stale duplicate after switching", () => {
  const f = fixture(); f.users.push({ id: "old", isArchived: true, migratedTo: "new" });
  f.votes.push(...f.votes.map(v => ({ ...v, id: v.id.replace("new__", "old__"), prediction: "DRAW", updatedAt: ts(50000) })));
  assert.equal(calculateBadges(f).badges.get("new").knowledgeScore, 54);
});
test("deleted/archived old UID falls back to active userId", () => {
  const f = fixture({ owner: "old" }); f.votes.forEach(v => { v.userId = "new"; });
  assert.equal(calculateBadges(f).badges.get("new").knowledgeScore, 54);
});
test("two active legacy profiles use live team membership, matching BUILD90", () => {
  const f = fixture({ owner: "old" }); f.users.push({ id: "old" });
  f.teams = [{ memberIds: ["new"] }]; f.votes.forEach(v => { v.userId = "new"; });
  assert.equal(calculateBadges(f).badges.get("new").knowledgeScore, 54);
  assert.equal(calculateBadges(f).badges.get("old").resolved, 0);
});
test("unrelated accounts are never merged merely because a field names another UID", () => {
  const f = fixture({ owner: "old" }); f.users.push({ id: "old" }); f.votes.forEach(v => { v.userId = "new"; });
  assert.equal(calculateBadges(f).badges.get("old").resolved, 30);
  assert.equal(calculateBadges(f).badges.get("new").resolved, 0);
});
test("a migration cycle produces no cross-account history", () => {
  const f = fixture({ owner: "old" }); f.users.push({ id: "old", migratedTo: "middle" }, { id: "middle", migratedTo: "old" });
  assert.equal(calculateBadges(f).resolvedPredictions, 0);
});
test("live scores are excluded and legacy manual final results remain supported", () => {
  assert.equal(finalResult({ status: "IN_PLAY", result: "HOME" }), null);
  assert.equal(finalResult({ status: "CANCELLED", result: "HOME" }), null);
  assert.equal(finalResult({ result: "DRAW" }).result, "DRAW");
  const f = fixture(); f.results[0].status = "IN_PLAY";
  assert.equal(calculateBadges(f).badges.get("new").resolved, 29);
});
test("corrections/retracted results are calculated from current source data", () => {
  const f = fixture(); f.results[0].result = "AWAY"; f.results[0].homeScore = 1; f.results[0].awayScore = 2;
  assert.equal(calculateBadges(f).badges.get("new").knowledgeScore, 50);
  f.results.pop();
  assert.equal(calculateBadges(f).badges.get("new").resolved, 29);
});
test("only the latest 30 count, with a stable tie break", () => {
  const f = fixture({ count: 35, correct: 5, exact: 0 });
  assert.equal(calculateBadges(f).badges.get("new").knowledgeScore, 6);
  const tied = [{ matchId: "b", kickoffMs: 1, correct: true }, { matchId: "a", kickoffMs: 1, correct: false }];
  assert.deepEqual(automaticBadge(tied), automaticBadge(tied.slice().reverse()));
});
test("fewer than three completed predictions keep the existing provisional level", () => {
  assert.deepEqual(calculateBadges(fixture({ count: 2 })).badges.get("new"), { badge: "FOOTIX", knowledgeScore: 50, resolved: 2 });
});
test("badges repair preserves all points, avatars, teams, league scores and unknown fields verbatim", () => {
  const row = { id: "new", points: 160, votes: 101, resolvedVotes: 87, correct: 50, avatar: "img:original", teamId: "team", byCompetition: { cl: { points: 41, votes: 18 } }, custom: { preserved: true }, badge: "FOOTIX", knowledgeScore: 38, resolved: 30 };
  const result = patchIndividuals([row], calculateBadges(fixture()));
  const { badge, knowledgeScore, resolved, ...actual } = result.rows[0];
  const { badge: b, knowledgeScore: k, resolved: r, ...before } = row;
  assert.deepEqual(actual, before);
  assert.equal(row.badge, "FOOTIX", "input must not be mutated");
  assert.equal(patchIndividuals(result.rows, calculateBadges(fixture())).changed, 0, "retry is idempotent");
});
