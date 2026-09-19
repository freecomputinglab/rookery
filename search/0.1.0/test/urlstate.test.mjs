// `urlstate.js` — the query-string primitives, exercised as pure string-in
// string-out functions (no `history`; `URLSearchParams` is a node global). The
// comma-and-space case pins the reason every value is written as its own
// repeated param rather than comma-joined: a facet value legally containing a
// comma would corrupt a joined param with no escaping rule to recover it.
//
// `claimKey` IS THE ONE EXCEPTION and needs a DOM, because a claim is refused
// on whether the element holding it is still in the document — which is what
// lets a widget re-claim its own key after a rheo morph. Those cases build a
// throwaway document with linkedom rather than making the whole file DOM-bound.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { readSync, writeSync, readParam, writeParam, commit, claimKey, resetKeys, debounce } from "../src/urlstate.js";

test("readSync: q and repeated values for the given key", () => {
  const { q, values } = readSync("todos", "todos.q=rheo&todos.state=ready&todos.state=blocked");
  assert.equal(q, "rheo");
  assert.deepEqual(values.get("state"), new Set(["ready", "blocked"]));
});

test("readSync: a leading '?' behaves identically", () => {
  const { q, values } = readSync("todos", "?todos.q=rheo&todos.state=ready&todos.state=blocked");
  assert.equal(q, "rheo");
  assert.deepEqual(values.get("state"), new Set(["ready", "blocked"]));
});

test("readSync: another widget's params are invisible", () => {
  const { q, values } = readSync("todos", "ideas.t=cfp");
  assert.equal(q, "");
  assert.equal(values.size, 0);
});

test("writeSync/readSync round-trip", () => {
  const search = "todos.q=rheo&todos.state=ready&todos.state=blocked";
  const state = readSync("todos", search);
  const rewritten = writeSync("todos", state, search);
  assert.deepEqual(readSync("todos", rewritten), state);
});

test("writeSync: clearing a widget removes its params and keeps everyone else's", () => {
  const out = writeSync("todos", { q: "", values: new Map() }, "todos.q=x&tab=todos");
  assert.equal(out, "tab=todos");
});

test("writeSync: a facet value containing a comma and a space survives the round trip unchanged", () => {
  const state = { q: "", values: new Map([["tag", new Set(["a, b"])]]) };
  const search = writeSync("todos", state, "");
  assert.deepEqual(readSync("todos", search).values.get("tag"), new Set(["a, b"]));
});

test("readParam/writeParam: the scalar case", () => {
  const search = writeParam("tab", "todos", "");
  assert.equal(readParam("tab", search), "todos");
});

test("readParam: absent param is null", () => {
  assert.equal(readParam("tab", "todos.q=x"), null);
});

test("writeParam: null deletes the param and leaves the rest", () => {
  assert.equal(writeParam("tab", null, "tab=todos&todos.q=x"), "todos.q=x");
});

test("writeParam: undefined and empty string also delete", () => {
  assert.equal(writeParam("tab", undefined, "tab=todos"), "");
  assert.equal(writeParam("tab", "", "tab=todos"), "");
});

test("claimKey: first claim wins, every repeat is refused", () => {
  assert.equal(claimKey("a"), true);
  assert.equal(claimKey("a"), false);
  assert.equal(claimKey("b"), true);
});

test("claimKey: a repeat with no resetKeys() in between still warns and is refused", (t) => {
  const warn = t.mock.method(console, "warn", () => {});
  assert.equal(claimKey("dup"), true);
  assert.equal(claimKey("dup"), false);
  assert.equal(warn.mock.calls.length, 1);
});

test("resetKeys: a key claimed, then reset, can be claimed again", () => {
  assert.equal(claimKey("reclaim"), true);
  assert.equal(claimKey("reclaim"), false);
  resetKeys();
  assert.equal(claimKey("reclaim"), true);
});

// THE THREE OWNER CASES, and between them they are why the rehydrate path needs
// no `resetKeys()` and therefore no agreement about which package's hook runs
// first. A widget re-wiring itself after a rheo morph is the first case; a
// widget whose element the morph replaced rather than matched is the second;
// two widgets genuinely sharing one key on a live page is the third, and it
// must still be caught.
test("claimKey: the same owner re-claims its own key", () => {
  const { document } = parseHTML("<!doctype html><body><div id=a></div></body>");
  const owner = document.getElementById("a");
  assert.equal(claimKey("own", owner), true);
  assert.equal(claimKey("own", owner), true);
});

test("claimKey: a detached owner's claim is taken over by its replacement", () => {
  const { document } = parseHTML(
    "<!doctype html><body><div id=old></div><div id=new></div></body>",
  );
  const gone = document.getElementById("old");
  const fresh = document.getElementById("new");
  assert.equal(claimKey("handover", gone), true);
  // What a morph does when it cannot match an element: the old node leaves the
  // document, so the claim it is holding is dead rather than merely held.
  gone.remove();
  assert.equal(claimKey("handover", fresh), true);
});

test("claimKey: two owners both in the document still collide", (t) => {
  const warn = t.mock.method(console, "warn", () => {});
  const { document } = parseHTML(
    "<!doctype html><body><div id=one></div><div id=two></div></body>",
  );
  assert.equal(claimKey("shared", document.getElementById("one")), true);
  assert.equal(claimKey("shared", document.getElementById("two")), false);
  assert.equal(warn.mock.calls.length, 1);
});

test("commit: does not throw with no history present", () => {
  assert.doesNotThrow(() => commit("a=1"));
});

test("debounce: runs fn only once after the trailing call, with its arguments", () => {
  let calls = [];
  const fn = (...args) => calls.push(args);
  const debounced = debounce(fn, 10);
  debounced(1);
  debounced(2);
  debounced(3);
  assert.equal(calls.length, 0);
  return new Promise((resolve) => {
    setTimeout(() => {
      assert.deepEqual(calls, [[3]]);
      resolve();
    }, 30);
  });
});
