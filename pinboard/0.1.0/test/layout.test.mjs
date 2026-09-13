// Unit tests for the flow layout — the pure half of the browser code, kept
// apart in `src/layout.js` so it is testable under `node --test` with no
// browser or DOM shim.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { flowPositions } from "../src/layout.js";

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
