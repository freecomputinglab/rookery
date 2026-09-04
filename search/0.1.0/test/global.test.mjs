// THE `RookerySearch` GLOBAL, and the one asymmetry it exists to end.
//
// WHAT IT PINS. `vite.config.js` builds `dist/lib.js` as an IIFE named
// `RookerySearch`, so a project consuming a RELEASE has always had the whole
// surface on `globalThis`. A project consuming `src/*.js` through a repo-backed
// namespace got ES modules and no global at all, so the same site code — and
// `@rookery/todos`' `#todos-search`, which feature-detects this object rather
// than importing across the package boundary — worked or did not depending on
// which coordinate the project happened to use. `src/search.js` now publishes it
// itself, and vite's own assignment still wins where both run (`??=`).
//
// AND THE OTHER HALF: under BARE NODE nothing is published. The parity harness
// imports this module, and a global appearing there would make the two modes
// indistinguishable from a test's point of view — the guard is `typeof document`,
// so this is the case that proves the guard is the guard.
//
// TWO EVALUATIONS OF ONE MODULE, which is why both imports are dynamic and the
// second carries a query string: ES module instances are cached per specifier, so
// `?dom=1` is what buys a second evaluation with a document in place. The order
// is load-bearing — bare node first, then a DOM.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";

await import("../src/search.js");
const bare = globalThis.RookerySearch;

globalThis.document = parseHTML("<!doctype html><body></body>").document;
await import("../src/search.js?dom=1");
const published = globalThis.RookerySearch;

test("bare node gets no global", () => {
  assert.equal(bare, undefined);
});

test("a document gets the whole surface", () => {
  assert.equal(typeof published, "object");
  // The three `#todos-search` feature-detects, named first because that widget's
  // availability test is `splitQuery && evalTagQuery && fold` and a partial
  // surface must degrade as an absent one does.
  for (const name of ["splitQuery", "evalTagQuery", "fold"]) {
    assert.equal(typeof published[name], "function", `${name} is missing`);
  }
  // The rest of the documented surface, so a rename here fails here rather than
  // on a consuming site.
  for (const name of [
    "clusters",
    "parseTagQuery",
    "positiveAtoms",
    "score",
    "bodyScore",
    "search",
    "readIndex",
    "initPanels",
    "wirePanel",
    "init",
  ]) {
    assert.equal(typeof published[name], "function", `${name} is missing`);
  }
  assert.equal(published.TAG_PREFIX, "tags:");
});

test("the global's functions are the module's own", async () => {
  // Not a re-implementation and not a stale copy: the same rule, reachable two
  // ways. `fold` is the cheap witness — it is what a consumer must apply to a
  // row's tags before `evalTagQuery` will agree with the search bar.
  const { fold } = await import("../src/text.js");
  assert.equal(published.fold("In-Progress"), fold("In-Progress"));
  assert.equal(published.fold("In-Progress"), "in progress");
});
