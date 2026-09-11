// Numbers-only tests for the pure camera geometry — no DOM, no browser.
import { test } from "node:test";
import assert from "node:assert/strict";
import { targetFor, clamp, clampTo, unfocusTarget } from "../src/camera.js";

const VP = { height: 800, width: 600, scrollLeft: 0, scrollTop: 0 };

test("up: scrollTop puts the element's top at the top of the viewport", () => {
  const t = targetFor("up", { top: 500, height: 100, left: 0, width: 100 }, VP, { margin: 0 });
  assert.equal(t.scrollTop, 500);
  assert.equal(t.scale, 1);
});

test("up: margin shifts the target above the element's top", () => {
  const t = targetFor("up", { top: 500, height: 100, left: 0, width: 100 }, VP, { margin: 20 });
  assert.equal(t.scrollTop, 480);
});

test("up: leaves the horizontal position untouched", () => {
  const t = targetFor(
    "up",
    { top: 500, height: 100, left: 0, width: 100 },
    { ...VP, scrollLeft: 250 },
    { margin: 0 },
  );
  assert.equal(t.scrollLeft, 250);
});

test("down: scrollTop puts the element's bottom at the bottom of the viewport", () => {
  // bottom edge (600) + margin (0) - viewport height (800) = -200
  const t = targetFor("down", { top: 500, height: 100, left: 0, width: 100 }, VP, { margin: 0 });
  assert.equal(t.scrollTop, -200);
});

test("center: scrollTop centres the element in the viewport", () => {
  const t = targetFor("center", { top: 500, height: 100, left: 0, width: 100 }, VP);
  assert.equal(t.scrollTop, 150);
});

test("scroll: an element taller than the viewport (plus margin) behaves as up", () => {
  const rect = { top: 200, height: 1000, left: 0, width: 100 };
  const scrolled = targetFor("scroll", rect, VP);
  const up = targetFor("up", rect, VP);
  assert.deepEqual(scrolled, up);
});

test("scroll: an element shorter than the viewport (plus margin) behaves as center", () => {
  const rect = { top: 200, height: 100, left: 0, width: 100 };
  const scrolled = targetFor("scroll", rect, VP);
  const centered = targetFor("center", rect, VP);
  assert.deepEqual(scrolled, centered);
});

test("scroll: an element exactly the viewport height (plus margin) still fits — behaves as center", () => {
  // The boundary is <=, not <: rect.height + 2*margin === viewport.height
  // counts as fitting.
  const rect = { top: 0, height: 800, left: 0, width: 100 };
  const scrolled = targetFor("scroll", rect, VP);
  const centered = targetFor("center", rect, VP);
  assert.deepEqual(scrolled, centered);
});

test("left: scrollLeft puts the element's left edge at the left of the viewport", () => {
  const t = targetFor(
    "left",
    { top: 0, height: 100, left: 900, width: 300 },
    { height: 800, width: 600, scrollLeft: 0, scrollTop: 0 },
    { margin: 0 },
  );
  assert.equal(t.scrollLeft, 900);
});

test("right: scrollLeft puts the element's right edge at the right of the viewport", () => {
  const t = targetFor(
    "right",
    { top: 0, height: 100, left: 900, width: 300 },
    { height: 800, width: 600, scrollLeft: 0, scrollTop: 0 },
    { margin: 0 },
  );
  assert.equal(t.scrollLeft, 600);
});

test("left: margin shifts the target left of the element's left edge", () => {
  const t = targetFor("left", { top: 0, height: 100, left: 900, width: 300 }, VP, { margin: 20 });
  assert.equal(t.scrollLeft, 880);
});

test("center-x: scrollLeft centres the element horizontally in the viewport", () => {
  const t = targetFor("center-x", { top: 0, height: 100, left: 900, width: 300 }, VP);
  assert.equal(t.scrollLeft, 900 + 150 - 300);
});

test("left/right: also set scrollTop, following scroll's rule on the vertical axis", () => {
  const rect = { top: 200, height: 100, left: 900, width: 300 };
  const left = targetFor("left", rect, VP);
  const right = targetFor("right", rect, VP);
  const scrolled = targetFor("scroll", rect, VP);
  assert.equal(left.scrollTop, scrolled.scrollTop);
  assert.equal(right.scrollTop, scrolled.scrollTop);
});

test("center-x: also sets scrollTop, following scroll's rule on the vertical axis", () => {
  const rect = { top: 200, height: 1000, left: 900, width: 300 };
  const centeredX = targetFor("center-x", rect, VP);
  const scrolled = targetFor("scroll", rect, VP);
  assert.equal(centeredX.scrollTop, scrolled.scrollTop);
});

test("focus: scale shrinks to fit a tall element into the viewport", () => {
  const t = targetFor("focus", { top: 0, height: 1600, left: 0, width: 100 }, VP);
  assert.equal(t.scale, 0.5);
});

test("focus: scale is capped at 1 — a short element is never magnified", () => {
  const t = targetFor("focus", { top: 0, height: 100, left: 0, width: 100 }, VP);
  assert.equal(t.scale, 1);
});

test("focus: a zero-height rect yields scale 1 instead of dividing by zero", () => {
  const t = targetFor("focus", { top: 0, height: 0, left: 0, width: 100 }, VP);
  assert.equal(t.scale, 1);
});

test("focus: a negative-height rect also yields scale 1", () => {
  const t = targetFor("focus", { top: 0, height: -50, left: 0, width: 100 }, VP);
  assert.equal(t.scale, 1);
});

test("focus: a zero-width rect also yields scale 1", () => {
  const t = targetFor("focus", { top: 0, height: 100, left: 0, width: 0 }, VP);
  assert.equal(t.scale, 1);
});

test("focus: a negative-width rect also yields scale 1", () => {
  const t = targetFor("focus", { top: 0, height: 100, left: 0, width: -50 }, VP);
  assert.equal(t.scale, 1);
});

test("focus: scrollTop centres the element, same as center", () => {
  const rect = { top: 500, height: 100, left: 0, width: 100 };
  const focused = targetFor("focus", rect, VP);
  const centered = targetFor("center", rect, VP);
  assert.equal(focused.scrollTop, centered.scrollTop);
});

test("focus: scrollLeft centres the element horizontally, same as center-x", () => {
  const rect = { top: 0, height: 100, left: 900, width: 300 };
  const focused = targetFor("focus", rect, VP);
  const centeredX = targetFor("center-x", rect, VP);
  assert.equal(focused.scrollLeft, centeredX.scrollLeft);
});

test("clampTo: a negative target clamps to 0", () => {
  assert.equal(clampTo(-50, 1000, 800), 0);
});

test("clampTo: a target past the document's end clamps to the last reachable position", () => {
  assert.equal(clampTo(9999, 1000, 800), 200);
});

test("clampTo: a document shorter than the viewport clamps everything to 0", () => {
  assert.equal(clampTo(50, 400, 800), 0);
});

test("clampTo: an in-range target passes through unchanged", () => {
  assert.equal(clampTo(150, 1000, 800), 150);
});

test("clamp: is the same function as clampTo", () => {
  assert.equal(clamp(-50, 1000, 800), clampTo(-50, 1000, 800));
  assert.equal(clamp(9999, 1000, 800), clampTo(9999, 1000, 800));
});

test("targetFor: an unknown action throws, naming the bad action and the accepted set", () => {
  assert.throws(
    () => targetFor("nope", { top: 0, height: 0, left: 0, width: 0 }, VP),
    (err) => {
      assert.ok(err instanceof Error);
      assert.match(err.message, /nope/);
      for (const name of ["scroll", "up", "down", "center", "left", "right", "center-x", "focus"]) {
        assert.match(err.message, new RegExp(name));
      }
      return true;
    },
  );
});

test("unfocusTarget: restores a saved position unchanged", () => {
  const saved = { scrollLeft: 40, scrollTop: 321, scale: 0.7 };
  assert.deepEqual(unfocusTarget(saved), saved);
});

test("unfocusTarget: falls back to the document top-left at natural scale when nothing was saved", () => {
  assert.deepEqual(unfocusTarget(undefined), { scrollLeft: 0, scrollTop: 0, scale: 1 });
  assert.deepEqual(unfocusTarget(null), { scrollLeft: 0, scrollTop: 0, scale: 1 });
});
