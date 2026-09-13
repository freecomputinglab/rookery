// Unit tests for the drag arithmetic — the pure half of the drag code, kept
// apart from `makeDraggable` itself so it is testable under `node --test`
// with no browser, DOM shim, or pointer events. `makeDraggable`'s own
// gesture behaviour is exercised separately, under Playwright.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { offsetPosition, clampPosition } from "../src/drag.js";

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

test("clampPosition keeps the card's far edge inside the board", () => {
  const pos = clampPosition(
    { x: 1150, y: 750 },
    { width: 300, height: 200 },
    { width: 1200, height: 800 },
  );
  assert.deepEqual(pos, { x: 900, y: 600 });
});

test("clampPosition never asks for a negative max when the card is larger than the board", () => {
  const pos = clampPosition(
    { x: 500, y: 500 },
    { width: 400, height: 400 },
    { width: 300, height: 300 },
  );
  assert.deepEqual(pos, { x: 0, y: 0 });
});
