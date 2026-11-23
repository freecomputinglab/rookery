// Numbers-only tests for the connector layer's pure geometry — no DOM, no
// browser. `redraw`/`deckBox` read the document and are exercised by the
// `dag` example's own check instead.
import { test } from "node:test";
import assert from "node:assert/strict";
import { edgePath, railX } from "../src/edges.js";

test("edgePath: the d string for a known pair of points", () => {
  assert.equal(edgePath({ x: 10, y: 100 }, { x: 50, y: 300 }), "M 10 100 C 10 200, 50 200, 50 300");
});

test("edgePath: both control points sit at the vertical midpoint", () => {
  // The whole reason for the shape: a control point directly below the start
  // and directly above the end leaves and arrives VERTICAL, so the curve is
  // continuous with the rail at each end rather than kinked into it.
  const d = edgePath({ x: 0, y: 40 }, { x: 200, y: 140 });
  const [, c1x, c1y, c2x, c2y] = d.match(/C (\S+) (\S+), (\S+) (\S+),/).map(Number);
  assert.equal(c1y, 90);
  assert.equal(c2y, 90);
  assert.equal(c1x, 0);
  assert.equal(c2x, 200);
});

test("edgePath: an upward edge midpoints just the same", () => {
  assert.equal(edgePath({ x: 5, y: 300 }, { x: 5, y: 100 }), "M 5 300 C 5 200, 5 200, 5 100");
});

test("railX: centres a stroke on a rule of the given width", () => {
  assert.equal(railX({ x: 100, y: 0, width: 400, height: 60 }, 4), 102);
  assert.equal(railX({ x: 100, y: 0, width: 400, height: 60 }, 10), 105);
});

test("railX: a zero-width rule puts the stroke on the box's own edge", () => {
  assert.equal(railX({ x: 100, y: 0, width: 400, height: 60 }, 0), 100);
});
