// `#todos-search`'s `sync:` opt-in — mirroring the filter box and the pressed
// pills into the URL, and rehydrating them on the next load. `todo-search.test.mjs`
// already covers the widget without this feature; this file is only the join
// between `wire()` and `@rookery/search`'s `urlstate.js`.
//
// THE REAL PRIMITIVES, BY RELATIVE PATH ACROSS THE PACKAGE BOUNDARY — the same
// asymmetry `todo-search.test.mjs` exercises for the tag-query language: node can
// reach across it, the browser cannot, and that asymmetry is why the widget
// feature-detects a global instead of importing anything. A stub of these five
// would only pin the stub, not the real contract.
//
// `location`/`history` ARE STUBBED, not the real globals — `urlstate.js`'s own
// suite runs under linkedom, which provides neither, and `commit` is the one
// function in that module that touches them.

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";

import { wire } from "../src/todo-search.js";
import { readSync, writeSync, commit, claimKey, debounce } from "../../../search/0.1.0/src/urlstate.js";

// Three rows, enough to tell the `q` filter, the `status` pill and the `type`
// pill apart: only "alpha" matches the text query used below, only "alpha" is
// `ready`, and "alpha"/"gamma" share the `bug` type.
const WIDGET = ({ syncKey, count = "3 todos" }) => `<!doctype html><body>
<div class="todo-search" data-todo-search-ready="false"${syncKey ? ` data-todo-search-sync="${syncKey}"` : ""}>
<input class="todo-search-input" type="search">
<div class="todo-search-pills">
  <button class="todo-search-pill" data-todo-facet="status" data-todo-value="ready" aria-pressed="false">ready</button>
  <button class="todo-search-pill" data-todo-facet="status" data-todo-value="blocked" aria-pressed="false">blocked</button>
  <button class="todo-search-pill" data-todo-facet="type" data-todo-value="bug" aria-pressed="false">bug</button>
</div>
<p class="todo-search-count">${count}</p>
<ul class="todo-list todo-search-results">
<li class="todo-row todo-search-row" data-todo-status="ready" data-todo-type="bug" data-todo-text="alpha item">alpha</li>
<li class="todo-row todo-search-row" data-todo-status="open" data-todo-type="task" data-todo-text="beta item">beta</li>
<li class="todo-row todo-search-row" data-todo-status="blocked" data-todo-type="bug" data-todo-text="gamma item">gamma</li>
</ul></div></body>`;

// `syncKey: null` omits `data-todo-search-sync` — the widget on a page with no
// URL state opted in. `language: "full"` (default) publishes the five
// `urlstate.js` exports the widget checks for; `"none"` deletes the global
// entirely, the page-carries-`@rookery/todos`-alone case.
function setup({ syncKey, search = "", language = "full", count } = {}) {
  let capturedUrl = null;
  globalThis.location = { pathname: "/todos.html", search, hash: "" };
  globalThis.history = { replaceState: (_a, _b, url) => { capturedUrl = url; } };
  if (language === "full") {
    globalThis.RookerySearch = { readSync, writeSync, commit, claimKey, debounce };
  } else {
    delete globalThis.RookerySearch;
  }

  const { document } = parseHTML(WIDGET({ syncKey, count }));
  globalThis.document = document;
  wire(document.querySelector(".todo-search"));

  const input = document.querySelector(".todo-search-input");
  const capturedHas = (name, value) => {
    if (capturedUrl === null) return false;
    const params = new URLSearchParams(capturedUrl.includes("?") ? capturedUrl.split("?")[1] : "");
    return value === undefined ? params.has(name) : params.getAll(name).includes(value);
  };

  return {
    input,
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    escape: () => {
      // linkedom has no `KeyboardEvent` constructor; a plain `Event` with
      // `key` set by hand is enough, since `wire()` only reads `ev.key`.
      const ev = new document.defaultView.Event("keydown");
      ev.key = "Escape";
      input.dispatchEvent(ev);
    },
    press: (facet, value) =>
      document
        .querySelector(`.todo-search-pill[data-todo-facet="${facet}"][data-todo-value="${value}"]`)
        .dispatchEvent(new document.defaultView.Event("click")),
    pillPressed: (facet, value) =>
      document
        .querySelector(`.todo-search-pill[data-todo-facet="${facet}"][data-todo-value="${value}"]`)
        .getAttribute("aria-pressed"),
    shown: () =>
      [...document.querySelectorAll(".todo-search-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent)
        .sort(),
    count: () => document.querySelector(".todo-search-count").textContent,
    captured: () => capturedUrl,
    capturedHas,
  };
}

test("a `.q` param rehydrates the input and filters on first paint", () => {
  const w = setup({ syncKey: "a", search: "a.q=alpha" });
  assert.equal(w.input.value, "alpha");
  assert.deepEqual(w.shown(), ["alpha"]);
});

test("a `.status` param presses that pill with no click, and filters", () => {
  const w = setup({ syncKey: "b", search: "b.status=ready" });
  assert.equal(w.pillPressed("status", "ready"), "true");
  assert.deepEqual(w.shown(), ["alpha"]);
});

test("a `.type` param naming no pill on the page presses nothing and filters nothing", () => {
  const w = setup({ syncKey: "c", search: "c.type=nonexistent" });
  assert.deepEqual(w.shown(), ["alpha", "beta", "gamma"]);
  assert.equal(w.pillPressed("status", "ready"), "false");
  assert.equal(w.pillPressed("type", "bug"), "false");
});

test("a pill click writes its facet into the URL; a second click removes it", () => {
  const w = setup({ syncKey: "d" });
  w.press("status", "ready");
  assert.equal(w.capturedHas("d.status", "ready"), true);
  w.press("status", "ready");
  assert.equal(w.capturedHas("d.status", "ready"), false);
});

test("Escape clears the box and drops `.q` from the URL immediately, ahead of the debounce", () => {
  const w = setup({ syncKey: "e" });
  w.type("alpha");
  // The debounced writer has not fired yet — typing alone never writes.
  assert.equal(w.captured(), null);
  w.escape();
  assert.notEqual(w.captured(), null);
  assert.equal(w.capturedHas("e.q"), false);
});

test("a pill click preserves a param outside the sync namespace", () => {
  const w = setup({ syncKey: "f", search: "tab=todos" });
  w.press("status", "ready");
  assert.equal(w.capturedHas("tab", "todos"), true);
  assert.equal(w.capturedHas("f.status", "ready"), true);
});

test("no `sync` attribute: `apply()` never runs at wire time and nothing reaches the URL", () => {
  // A count deliberately unequal to the real total: if `apply()` ran at wire
  // time it would overwrite this string, the same regression its own comment
  // in `todo-search.js` warns against for the unsynced widget.
  const w = setup({ syncKey: null, count: "stale" });
  assert.equal(w.count(), "stale");
  w.type("beta");
  w.press("status", "ready");
  assert.equal(w.captured(), null);
});

test("no `RookerySearch` global at all: the widget still filters and the URL is never touched", () => {
  const w = setup({ syncKey: "h", language: "none" });
  w.type("beta");
  assert.deepEqual(w.shown(), ["beta"]);
  assert.equal(w.captured(), null);
});
