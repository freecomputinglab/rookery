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
import { revealThrough } from "../src/slipshow.js";

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
