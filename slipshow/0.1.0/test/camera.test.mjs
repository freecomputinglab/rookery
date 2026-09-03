// Numbers-only tests for the pure camera geometry — no DOM, no browser.
import { test } from "node:test";
import assert from "node:assert/strict";
import { targetFor, clamp, unfocusTarget } from "../src/camera.js";

test("up: scrollTop puts the element's top at the top of the viewport", () => {
  const t = targetFor("up", { top: 500, height: 100 }, { height: 800 }, { margin: 0 });
  assert.equal(t.scrollTop, 500);
  assert.equal(t.scale, 1);
});

test("up: margin shifts the target above the element's top", () => {
  const t = targetFor("up", { top: 500, height: 100 }, { height: 800 }, { margin: 20 });
  assert.equal(t.scrollTop, 480);
});

test("down: scrollTop puts the element's bottom at the bottom of the viewport", () => {
  // bottom edge (600) + margin (0) - viewport height (800) = -200
  const t = targetFor("down", { top: 500, height: 100 }, { height: 800 }, { margin: 0 });
  assert.equal(t.scrollTop, -200);
});

test("center: scrollTop centres the element in the viewport", () => {
  const t = targetFor("center", { top: 500, height: 100 }, { height: 800 });
  assert.equal(t.scrollTop, 150);
});

test("scroll: an element taller than the viewport (plus margin) behaves as up", () => {
  const rect = { top: 200, height: 1000 };
  const viewport = { height: 800 };
  const scrolled = targetFor("scroll", rect, viewport);
  const up = targetFor("up", rect, viewport);
  assert.deepEqual(scrolled, up);
});

test("scroll: an element shorter than the viewport (plus margin) behaves as center", () => {
  const rect = { top: 200, height: 100 };
  const viewport = { height: 800 };
  const scrolled = targetFor("scroll", rect, viewport);
  const centered = targetFor("center", rect, viewport);
  assert.deepEqual(scrolled, centered);
});

test("scroll: an element exactly the viewport height (plus margin) still fits — behaves as center", () => {
  // The boundary is <=, not <: rect.height + 2*margin === viewport.height
  // counts as fitting.
  const rect = { top: 0, height: 800 };
  const viewport = { height: 800 };
  const scrolled = targetFor("scroll", rect, viewport);
  const centered = targetFor("center", rect, viewport);
  assert.deepEqual(scrolled, centered);
});

test("focus: scale shrinks to fit a tall element into the viewport", () => {
  const t = targetFor("focus", { top: 0, height: 1600 }, { height: 800 });
  assert.equal(t.scale, 0.5);
});

test("focus: scale is capped at 1 — a short element is never magnified", () => {
  const t = targetFor("focus", { top: 0, height: 100 }, { height: 800 });
  assert.equal(t.scale, 1);
});

test("focus: a zero-height rect yields scale 1 instead of dividing by zero", () => {
  const t = targetFor("focus", { top: 0, height: 0 }, { height: 800 });
  assert.equal(t.scale, 1);
});

test("focus: a negative-height rect also yields scale 1", () => {
  const t = targetFor("focus", { top: 0, height: -50 }, { height: 800 });
  assert.equal(t.scale, 1);
});

test("focus: scrollTop centres the element, same as center", () => {
  const rect = { top: 500, height: 100 };
  const viewport = { height: 800 };
  const focused = targetFor("focus", rect, viewport);
  const centered = targetFor("center", rect, viewport);
  assert.equal(focused.scrollTop, centered.scrollTop);
});

test("clamp: a negative target clamps to 0", () => {
  assert.equal(clamp(-50, 1000, 800), 0);
});

test("clamp: a target past the document's end clamps to the last reachable position", () => {
  assert.equal(clamp(9999, 1000, 800), 200);
});

test("clamp: a document shorter than the viewport clamps everything to 0", () => {
  assert.equal(clamp(50, 400, 800), 0);
});

test("clamp: an in-range target passes through unchanged", () => {
  assert.equal(clamp(150, 1000, 800), 150);
});

test("targetFor: an unknown action throws, naming the bad action and the accepted set", () => {
  assert.throws(() => targetFor("nope", { top: 0, height: 0 }, { height: 800 }), (err) => {
    assert.ok(err instanceof Error);
    assert.match(err.message, /nope/);
    for (const name of ["scroll", "up", "down", "center", "focus"]) {
      assert.match(err.message, new RegExp(name));
    }
    return true;
  });
});

test("unfocusTarget: restores a saved position unchanged", () => {
  const saved = { scrollTop: 321, scale: 0.7 };
  assert.deepEqual(unfocusTarget(saved), saved);
});

test("unfocusTarget: falls back to the document top at natural scale when nothing was saved", () => {
  assert.deepEqual(unfocusTarget(undefined), { scrollTop: 0, scale: 1 });
  assert.deepEqual(unfocusTarget(null), { scrollTop: 0, scale: 1 });
});
