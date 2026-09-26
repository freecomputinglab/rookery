// Unit tests for the marquee's pure geometry — testable under `node --test`
// with no browser, DOM shim, or pointer events, the same split
// `test/drag.test.mjs` makes for the drag arithmetic.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { marqueeRect, rectsOverlap } from "../src/select.js";

test("marqueeRect normalizes a backwards drag", () => {
  const forward = marqueeRect({ x: 10, y: 10 }, { x: 60, y: 40 });
  const backward = marqueeRect({ x: 60, y: 40 }, { x: 10, y: 10 });
  assert.deepEqual(forward, { x: 10, y: 10, width: 50, height: 30 });
  assert.deepEqual(backward, forward);
});

test("rectsOverlap is true for a partial overlap", () => {
  const a = { x: 0, y: 0, width: 50, height: 50 };
  const b = { x: 25, y: 25, width: 50, height: 50 };
  assert.equal(rectsOverlap(a, b), true);
});

test("rectsOverlap is false for two disjoint rectangles", () => {
  const a = { x: 0, y: 0, width: 10, height: 10 };
  const b = { x: 100, y: 100, width: 10, height: 10 };
  assert.equal(rectsOverlap(a, b), false);
});

test("rectsOverlap is false for rectangles that only touch edges", () => {
  const a = { x: 0, y: 0, width: 10, height: 10 };
  const b = { x: 10, y: 0, width: 10, height: 10 };
  assert.equal(rectsOverlap(a, b), false);
});

test("rectsOverlap is true for full containment either way round", () => {
  const outer = { x: 0, y: 0, width: 100, height: 100 };
  const inner = { x: 25, y: 25, width: 10, height: 10 };
  assert.equal(rectsOverlap(outer, inner), true);
  assert.equal(rectsOverlap(inner, outer), true);
});
