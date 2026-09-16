// Unit tests for the drag arithmetic — the pure half of the drag code, kept
// apart from `makeDraggable` itself so it is testable under `node --test`
// with no browser, DOM shim, or pointer events. `makeDraggable`'s own
// gesture behaviour is exercised separately, under Playwright.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { offsetPosition, clampPosition, movedEnough, DRAG_THRESHOLD } from "../src/drag.js";

test("movedEnough is false while the press is a click, on either axis", () => {
  const start = { x: 100, y: 100 };
  assert.equal(movedEnough(start, start), false);
  assert.equal(movedEnough(start, { x: 100 + DRAG_THRESHOLD - 1, y: 100 }), false);
  assert.equal(movedEnough(start, { x: 100, y: 100 - (DRAG_THRESHOLD - 1) }), false);
});

test("movedEnough is true once either axis reaches the threshold", () => {
  const start = { x: 100, y: 100 };
  assert.equal(movedEnough(start, { x: 100 + DRAG_THRESHOLD, y: 100 }), true);
  assert.equal(movedEnough(start, { x: 100, y: 100 - DRAG_THRESHOLD }), true);
});

test("offsetPosition adds the pointer's delta to the start position", () => {
  const start = { x: 100, y: 50 };
  const startPointer = { x: 10, y: 10 };
  const pointer = { x: 25, y: 4 };
  assert.deepEqual(offsetPosition(start, startPointer, pointer), { x: 115, y: 44 });
});

test("offsetPosition returns the start position when the pointer has not moved", () => {
  const start = { x: 100, y: 50 };
  const pointer = { x: 10, y: 10 };
  assert.deepEqual(offsetPosition(start, pointer, pointer), start);
});

test("clampPosition leaves an in-bounds position untouched", () => {
  const pos = clampPosition(
    { x: 40, y: 60 },
    { width: 300, height: 200 },
    { width: 1200, height: 800 },
  );
  assert.deepEqual(pos, { x: 40, y: 60 });
});

test("clampPosition floors negative coordinates at zero", () => {
  const pos = clampPosition(
    { x: -30, y: -5 },
    { width: 300, height: 200 },
    { width: 1200, height: 800 },
  );
  assert.deepEqual(pos, { x: 0, y: 0 });
});

test("clampPosition keeps the card's right edge inside the board and leaves y alone", () => {
  const pos = clampPosition(
    { x: 1150, y: 750 },
    { width: 300, height: 200 },
    { width: 1200, height: 800 },
  );
  assert.deepEqual(pos, { x: 900, y: 750 });
});

test("clampPosition never asks for a negative max when the card is larger than the board", () => {
  const pos = clampPosition(
    { x: 500, y: 500 },
    { width: 400, height: 400 },
    { width: 300, height: 300 },
  );
  assert.deepEqual(pos, { x: 0, y: 500 });
});

test("clampPosition lets a card pass the board's bottom edge, growing it", () => {
  const pos = clampPosition(
    { x: 40, y: 5000 },
    { width: 300, height: 200 },
    { width: 1200, height: 800 },
  );
  assert.deepEqual(pos, { x: 40, y: 5000 });
});
