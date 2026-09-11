// The reveal boundary, without a DOM. `revealThrough` is the whole of the
// progressive reveal that is expressible as arithmetic — everything else in
// `src/slipshow.js` is class toggling and measurement — and the off-by-one it
// settles is the behaviour itself: a deck that opened showing slip 0 would not
// be a deck that opens empty.
//
// Importing `src/slipshow.js` in node is safe: its bottom guard is
// `typeof document !== "undefined"`, so `init` never runs here.
import { test } from "node:test";
import assert from "node:assert/strict";
import { revealThrough, entersDeck, exitsDeck } from "../src/slipshow.js";

test("before the first press nothing is revealed, whatever the index says", () => {
  assert.equal(revealThrough(false, 0), -1);
  // `currentIndex` is 0 on a deck opened without a fragment, so this is the
  // real load-time case and not a hypothetical one.
  assert.equal(revealThrough(false, 7), -1);
});

test("the first press reveals the current slip and no more", () => {
  assert.equal(revealThrough(true, 0), 0);
});

test("the boundary is the current slip, so going back re-hides", () => {
  assert.equal(revealThrough(true, 5), 5);
  assert.equal(revealThrough(true, 2), 2);
});

test("a forward press enters an unstarted deck", () => {
  assert.equal(entersDeck(false, 0, 1), true);
});

test("a backwards press on an unentered deck does nothing", () => {
  assert.equal(entersDeck(false, 0, -1), false);
});

test("a Home press, or a fragment landing, still enters even at the current index", () => {
  assert.equal(entersDeck(false, 3, 3), true);
});

test("a backwards press off slip 0 leaves a started deck", () => {
  assert.equal(exitsDeck(true, 0, -1), true);
});

test("an ordinary backwards step does not leave the deck", () => {
  assert.equal(exitsDeck(true, 3, 2), false);
});

test("a deck already out cannot be exited again", () => {
  assert.equal(exitsDeck(false, 0, -1), false);
});
