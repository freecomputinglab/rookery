// `urlstate.js` — the query-string primitives, exercised as pure string-in
// string-out functions (no DOM, no `history`; `URLSearchParams` is a node
// global). The comma-and-space case pins the reason every value is written
// as its own repeated param rather than comma-joined: a facet value legally
// containing a comma would corrupt a joined param with no escaping rule to
// recover it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readSync, writeSync, readParam, writeParam, commit, claimKey, debounce } from "../src/urlstate.js";

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
