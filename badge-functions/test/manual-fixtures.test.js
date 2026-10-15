"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { manualManifestRow } = require("../manual-fixtures");
const match = { id: "manual_el_test", competitionId: "europa-league", homeCode: "MAR", awayCode: "OLY", kickoffAt: Timestamp.fromDate(new Date("2026-10-15T19:00:00Z")), allowsDraw: true };
test("a manually entered fixture never invents a score or disables the draw", () => {
  const row = manualManifestRow(match, null, 2026);
  assert.equal(row.result, null); assert.equal(row.homeScore, null); assert.equal(row.allowsDraw, true);
});
test("manual final draws including 0-0 are published, provisional scores are excluded", () => {
  assert.equal(manualManifestRow(match, { status: "FINISHED", homeScore: 0, awayScore: 0 }, 2026).result, "DRAW");
  assert.equal(manualManifestRow(match, { status: "IN_PLAY", homeScore: 2, awayScore: 1 }, 2026).result, null);
  assert.equal(manualManifestRow(match, { status: "FINISHED", homeScore: -1, awayScore: 0 }, 2026).result, null);
});
test("cancelled, previous-season and unrelated competition fixtures are excluded", () => {
  assert.equal(manualManifestRow({ ...match, status: "CANCELLED" }, null, 2026), null);
  assert.equal(manualManifestRow(match, null, 2027), null);
  assert.equal(manualManifestRow({ ...match, competitionId: "champions-league" }, null, 2026), null);
});
