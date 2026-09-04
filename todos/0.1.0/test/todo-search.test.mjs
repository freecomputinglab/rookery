// `score` and `passes` — the pure half of the `#todos-search` filter, split out
// of `todo-search.js` so it can be tested without a DOM.
//
// AND, BELOW THE PURE CASES, the `tags:` EXPRESSION over a real DOM (linkedom).
// That half cannot be pure: what is unpinned there is the JOIN — detecting the
// `RookerySearch` global, reading `data-todo-tags`, folding it, splitting the
// query once and ANDing the result with the pills. A mistake in any of those is
// correct-looking JavaScript that filters nothing or everything. The language
// itself is pinned in `@rookery/search` by `just parity` and needs no second
// harness here.

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";

import { passes, score, wire } from "../src/todo-search.js";
// THE REAL LANGUAGE, BY RELATIVE PATH ACROSS THE PACKAGE BOUNDARY — which node
// can do and the browser cannot, and that asymmetry is the whole reason the
// widget reaches for a global at runtime instead of importing anything. A stub
// of these three would only pin the stub. Test-only: nothing in `src/` imports
// across this boundary, and no manifest declares the edge.
import { fold } from "../../../search/0.1.0/src/text.js";
import { splitQuery, evalTagQuery } from "../../../search/0.1.0/src/tagquery.js";

test("a non-subsequence does not match", () => {
  assert.equal(score("the manifest parser", "zzz"), -1);
  // Right letters, wrong order: a subsequence match is ordered.
  assert.equal(score("abc", "cba"), -1);
});

test("an empty query scores 0 for everything", () => {
  // Equal scores everywhere is what leaves the build-time priority order
  // untouched until someone types.
  assert.equal(score("anything at all", ""), 0);
  assert.equal(score("", ""), 0);
});

test("a contiguous match beats a scattered one", () => {
  const contiguous = score("manifest parser", "manifest");
  const scattered = score("m a n i f e s t", "manifest");
  assert.ok(contiguous > scattered, `${contiguous} should beat ${scattered}`);
  assert.ok(scattered > 0, "a scattered subsequence still matches");
});

test("matching is case-insensitive both ways", () => {
  assert.ok(score("The Manifest Parser", "manifest") > 0);
  assert.ok(score("the manifest parser", "MANIFEST") > 0);
});

test("an earlier first match scores higher, all else equal", () => {
  assert.ok(score("parser here", "parser") > score("well over there parser", "parser"));
});

const row = (status, type) => ({ status, type });

test("empty facets constrain nothing", () => {
  const none = { status: new Set(), type: new Set() };
  assert.equal(passes(row("ready", "bug"), none), true);
  assert.equal(passes(row("blocked", "docs"), none), true);
});

test("values within one facet OR", () => {
  const f = { status: new Set(["ready", "blocked"]), type: new Set() };
  assert.equal(passes(row("ready", "bug"), f), true);
  assert.equal(passes(row("blocked", "bug"), f), true);
  assert.equal(passes(row("open", "bug"), f), false);
});

test("facets AND across each other", () => {
  const f = { status: new Set(["blocked"]), type: new Set(["docs"]) };
  assert.equal(passes(row("blocked", "docs"), f), true);
  // Each half alone is not enough.
  assert.equal(passes(row("blocked", "bug"), f), false);
  assert.equal(passes(row("ready", "docs"), f), false);
});

// ---------------------------------------------------------------------------
// The `tags:` expression, over a DOM.

// Four rows. `parse` and `ship` both carry `todo`; only `parse`'s haystack holds
// "window", so the expression and the residual text can be told apart. `nodata`
// deliberately carries NO `data-todo-tags` at all — an older page's markup, which
// must FAIL a tag expression rather than pass one it was never tested against.
const WIDGET = `<!doctype html><body>
<div class="todo-search" data-todo-search-ready="false">
<input class="todo-search-input" type="search">
<div class="todo-search-pills">
  <button class="todo-search-pill" data-todo-facet="status" data-todo-value="ready" aria-pressed="false">ready</button>
</div>
<p class="todo-search-count">4 todos</p>
<ul class="todo-list todo-search-results">
<li class="todo-row todo-search-row" data-todo-status="ready" data-todo-type="bug"
    data-todo-text="parse the manifest window" data-todo-tags=" todo todo-p1 phd ">parse</li>
<li class="todo-row todo-search-row" data-todo-status="open" data-todo-type="task"
    data-todo-text="ship the release" data-todo-tags=" todo todo-closed frontend ">ship</li>
<li class="todo-row todo-search-row" data-todo-status="open" data-todo-type=""
    data-todo-text="a plain note window" data-todo-tags=" note ">note</li>
<li class="todo-row todo-search-row" data-todo-status="open" data-todo-type=""
    data-todo-text="undocumented window">nodata</li>
</ul></div></body>`;

// `language: true` publishes the three functions `#todos-search` detects, taken
// from `@rookery/search` itself; `false` deletes the global, which is the
// no-search-package page. Read at WIRE time by the widget, so the choice is made
// per fixture rather than per file.
const widget = ({ language = true } = {}) => {
  const { document } = parseHTML(WIDGET);
  globalThis.document = document;
  if (language) globalThis.RookerySearch = { splitQuery, evalTagQuery, fold };
  else delete globalThis.RookerySearch;
  wire(document.querySelector(".todo-search"));
  const input = document.querySelector(".todo-search-input");
  return {
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    press: (value) =>
      document
        .querySelector(`.todo-search-pill[data-todo-value="${value}"]`)
        .dispatchEvent(new document.defaultView.Event("click")),
    shown: () =>
      [...document.querySelectorAll(".todo-search-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent)
        .sort(),
    count: () => document.querySelector(".todo-search-count").textContent,
  };
};

test("an empty query shows every row", () => {
  const w = widget();
  assert.deepEqual(w.shown(), ["nodata", "note", "parse", "ship"]);
});

test("`tags:todo` keeps the rows carrying that tag", () => {
  const w = widget();
  w.type("tags:todo");
  assert.deepEqual(w.shown(), ["parse", "ship"]);
  assert.equal(w.count(), "2 of 4");
});

test("`tags:todo&!todo-closed` is the string the readme advertises", () => {
  const w = widget();
  w.type("tags:todo&!todo-closed");
  // NOTE the prefix rule: an atom matches by prefix, so `todo` alone also matches
  // `todo-closed` — which is why the negation is what excludes `ship`.
  assert.deepEqual(w.shown(), ["parse"]);
});

test("the expression filters and the residual text ranks", () => {
  const w = widget();
  // Both `parse` and `ship` carry `todo`; only `parse`'s haystack holds "window",
  // and `note`/`nodata` hold it but fail the expression.
  w.type("tags:todo window");
  assert.deepEqual(w.shown(), ["parse"]);
});

test("a half-typed expression behaves as its valid prefix", () => {
  const w = widget();
  // A live input types every prefix of a valid query on the way to it, so the
  // parser repairs rather than throwing and a dangling `&` is dropped.
  w.type("tags:todo&");
  assert.deepEqual(w.shown(), ["parse", "ship"]);
});

test("a tag expression ANDs with a pressed pill", () => {
  const w = widget();
  w.press("ready");
  assert.deepEqual(w.shown(), ["parse"]);
  // `ship` satisfies the expression but not the pill; the pill stays pressed and
  // keeps filtering, which is the composition `#panel` commits to as well.
  w.type("tags:todo-closed");
  assert.deepEqual(w.shown(), []);
});

test("matching folds case and hyphens", () => {
  const w = widget();
  w.type("tags:TODO_CLOSED");
  // Folding maps `-` and `_` to a space on both sides, so this is the same atom
  // as `todo-closed` — the row's tags are folded at read time for exactly this.
  assert.deepEqual(w.shown(), ["ship"]);
});

test("a row with no tag attribute fails every expression", () => {
  const w = widget();
  w.type("tags:note");
  assert.deepEqual(w.shown(), ["note"]);
});

test("with no `@rookery/search` on the page the input is the plain filter", () => {
  const w = widget({ language: false });
  // NOTHING THROWS, and the fuzzy filter is untouched.
  w.type("window");
  assert.deepEqual(w.shown(), ["nodata", "note", "parse"]);
  // The same string that filtered by tag above is now scored as literal text, and
  // no row's haystack contains it — the capability is gone, not half-present.
  w.type("tags:todo");
  assert.deepEqual(w.shown(), []);
  w.type("");
  assert.deepEqual(w.shown(), ["nodata", "note", "parse", "ship"]);
});

test("a partial global degrades exactly as an absent one does", () => {
  const { document } = parseHTML(WIDGET);
  globalThis.document = document;
  // A version skew: `fold` missing. All three or none — a surface this widget
  // cannot fully use must not be half-used.
  globalThis.RookerySearch = { splitQuery, evalTagQuery };
  wire(document.querySelector(".todo-search"));
  const input = document.querySelector(".todo-search-input");
  input.value = "tags:todo";
  input.dispatchEvent(new document.defaultView.Event("input"));
  const shown = [...document.querySelectorAll(".todo-search-row")]
    .filter((r) => !r.hidden)
    .map((r) => r.textContent);
  assert.deepEqual(shown, []);
  delete globalThis.RookerySearch;
});
