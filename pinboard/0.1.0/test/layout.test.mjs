// Unit tests for the pure layouts — the browser-free half of the code, kept
// apart in `src/layout.js` so both are testable under `node --test` with no
// browser or DOM shim.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { flowPositions, stackPositions } from "../src/layout.js";

test("cards that fit the board sit on one row", () => {
  const pos = flowPositions(["a", "b"], { cardWidth: 320, gap: 24, boardWidth: 1200 });
  assert.equal(pos.get("a").y, pos.get("b").y);
});

test("wraps to a second row once the ids exceed the board width", () => {
  const ids = ["a", "b", "c", "d", "e"];
  const pos = flowPositions(ids, { cardWidth: 320, gap: 24, boardWidth: 700 });
  const rows = new Set([...pos.values()].map((p) => p.y));
  assert.ok(rows.size > 1, `expected more than one row, got ${rows.size}`);
});

test("every card gets a distinct position", () => {
  const ids = ["a", "b", "c", "d", "e", "f"];
  const pos = flowPositions(ids, { cardWidth: 320, gap: 24, boardWidth: 700 });
  const distinct = new Set([...pos.values()].map((p) => `${p.x},${p.y}`));
  assert.equal(distinct.size, ids.length);
});

test("the same input yields the same output twice", () => {
  const ids = ["a", "b", "c"];
  const first = [...flowPositions(ids).entries()];
  const second = [...flowPositions(ids).entries()];
  assert.deepEqual(first, second);
});

test("a single card lands at the origin with default options", () => {
  const pos = flowPositions(["a"]);
  assert.deepEqual(pos.get("a"), { x: 0, y: 0 });
});

test("stackPositions: every card shares one x", () => {
  const heights = new Map([["a", 100], ["b", 200], ["c", 50]]);
  const pos = stackPositions(["a", "b", "c"], { heights, x: 40 });
  assert.equal(pos.get("a").x, 40);
  assert.equal(pos.get("b").x, 40);
  assert.equal(pos.get("c").x, 40);
});

test("stackPositions: y increases strictly in the given order", () => {
  const heights = new Map([["a", 100], ["b", 200], ["c", 50]]);
  const pos = stackPositions(["a", "b", "c"], { heights });
  assert.ok(pos.get("a").y < pos.get("b").y);
  assert.ok(pos.get("b").y < pos.get("c").y);
});

test("stackPositions: y is the previous card's y plus its height plus the gap", () => {
  const heights = new Map([["a", 100], ["b", 200]]);
  const pos = stackPositions(["a", "b"], { heights, gap: 24 });
  assert.equal(pos.get("a").y, 0);
  assert.equal(pos.get("b").y, 100 + 24);
});

test("stackPositions: an id missing from heights falls back to the default spacing", () => {
  const pos = stackPositions(["a", "b"], { heights: new Map(), gap: 24 });
  // Default cardHeight is 220 — the fallback used when heights carries
  // nothing for an id, never the same y as its neighbour.
  assert.equal(pos.get("b").y, 220 + 24);
});

test("stackPositions: startY offsets every card", () => {
  const heights = new Map([["a", 100]]);
  const withoutOffset = stackPositions(["a", "b"], { heights, gap: 24 });
  const withOffset = stackPositions(["a", "b"], { heights, gap: 24, startY: 500 });
  assert.equal(withOffset.get("a").y, withoutOffset.get("a").y + 500);
  assert.equal(withOffset.get("b").y, withoutOffset.get("b").y + 500);
});

test("stackPositions: the same input yields the same output twice", () => {
  const heights = new Map([["a", 100], ["b", 200]]);
  const first = [...stackPositions(["a", "b"], { heights }).entries()];
  const second = [...stackPositions(["a", "b"], { heights }).entries()];
  assert.deepEqual(first, second);
});
