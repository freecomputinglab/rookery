// The `tags:` QUERY LANGUAGE IN A PANEL INPUT, over a real DOM (linkedom).
//
// WHAT IT PINS. `wirePanel` used to score the raw input against `data-panel-text` and
// nothing else, so typing `tags:todo` into a panel fuzzy-matched the literal string
// "tags:todo" against note titles and found nothing — while the same string in the
// search bar worked, because `search()` splits the query. Both readmes advertise
// `tags:todo&!todo-closed`; only one of the two inputs honoured it.
//
// EVERY CASE HERE IS A DOM CASE on purpose. The parser and the evaluator are pinned by
// `just parity` and by the Typst fixtures; what is unpinned is the JOIN — reading the
// right attribute, folding it, splitting once, and ANDing the result with the pills. A
// mistake in any of those is correct-looking JavaScript that filters nothing or
// everything.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

// Four rows. `data-panel-all-tags` is the QUERY channel; `data-tag` is a multi-valued
// FACET, so the AND between a typed expression and a pressed pill can be exercised.
// `d` deliberately carries NO query channel at all — an older page's markup, which must
// fail a tag expression rather than pass it.
const PANEL = `<!doctype html><body>
<div class="panel" data-panel-ready="false" data-panel-multi="tag">
<input class="panel-input" type="search">
<div class="panel-pills">
  <span class="panel-pill-group" data-panel-group="tag">
    <button class="panel-pill" data-panel-facet="tag" data-panel-value="frontend" aria-pressed="false">frontend</button>
  </span>
</div>
<p class="panel-count">4 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha window" data-panel-all-tags=" todo frontend " data-tag=" frontend ">a</li>
<li class="panel-row" data-panel-text="beta reference" data-panel-all-tags=" todo todo-closed " data-tag="">b</li>
<li class="panel-row" data-panel-text="gamma window" data-panel-all-tags=" note " data-tag="">c</li>
<li class="panel-row" data-panel-text="delta window" data-tag="">d</li>
</ul></div></body>`;

const wire = (html = PANEL) => {
  const { document } = parseHTML(html);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  const input = document.querySelector(".panel-input");
  return {
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    press: (facet, value) =>
      document
        .querySelector(`.panel-pill[data-panel-facet="${facet}"][data-panel-value="${value}"]`)
        .dispatchEvent(new document.defaultView.Event("click")),
    shown: () =>
      [...document.querySelectorAll(".panel-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent)
        .sort(),
    count: () => document.querySelector(".panel-count").textContent,
  };
};

test("an empty query shows every row", () => {
  const p = wire();
  assert.deepEqual(p.shown(), ["a", "b", "c", "d"]);
  assert.equal(p.count(), "4 rows");
});

test("`tags:todo` keeps the rows carrying that tag", () => {
  const p = wire();
  p.type("tags:todo");
  // `c` carries `note`, `d` carries nothing at all. NOTE the prefix rule: an atom
  // matches by prefix, so `todo` also matches `todo-closed` — which is why `b` is here
  // and why the next case needs the negation to exclude it.
  assert.deepEqual(p.shown(), ["a", "b"]);
});

test("`tags:todo&!todo-closed` is the string both readmes advertise", () => {
  const p = wire();
  p.type("tags:todo&!todo-closed");
  assert.deepEqual(p.shown(), ["a"]);
  assert.equal(p.count(), "1 of 4");
});

test("the expression filters and the residual text ranks", () => {
  const p = wire();
  // `a` and `b` both carry `todo`; only `a`'s haystack holds "window".
  p.type("tags:todo window");
  assert.deepEqual(p.shown(), ["a"]);
});

test("a half-typed expression behaves as its valid prefix", () => {
  const p = wire();
  // A live input types every prefix of a valid query on the way to it, so
  // `parseTagQuery` repairs rather than throwing and a dangling `&` is dropped.
  p.type("tags:todo&");
  assert.deepEqual(p.shown(), ["a", "b"]);
  p.type("tags:(todo");
  assert.deepEqual(p.shown(), ["a", "b"]);
});

test("a tag expression ANDs with a pressed pill", () => {
  const p = wire();
  p.press("tag", "frontend");
  assert.deepEqual(p.shown(), ["a"]);
  // `b` satisfies the expression but not the pill; the pill stays pressed and keeps
  // filtering, which is the composition the panel commits to.
  p.type("tags:todo-closed");
  assert.deepEqual(p.shown(), []);
  assert.equal(p.count(), "nothing matches");
});

test("a query with no `tags:` prefix is an ordinary fuzzy filter", () => {
  const p = wire();
  p.type("window");
  assert.deepEqual(p.shown(), ["a", "c", "d"]);
});

test("`tags:` is only recognised in leading position", () => {
  const p = wire();
  // Mid-query it is text, matching how a person reads it — and no row's haystack holds
  // it, so nothing survives. The point is that it is SCORED rather than parsed.
  p.type("window tags:todo");
  assert.deepEqual(p.shown(), []);
});

test("a row with no query channel fails every tag expression", () => {
  const p = wire();
  p.type("tags:note");
  // `d` has no `data-panel-all-tags`. A row whose tags are unknown must not pass a
  // filter it was never tested against.
  assert.deepEqual(p.shown(), ["c"]);
});

test("the query channel is read, not the pill channel", () => {
  // `b`'s pill channel (`data-tag`) is empty while its query channel holds
  // `todo todo-closed`. Reading the wrong attribute would hide it here.
  const p = wire();
  p.type("tags:todo-closed");
  assert.deepEqual(p.shown(), ["b"]);
});

test("matching folds case and hyphens, as the search bar does", () => {
  const p = wire();
  p.type("tags:TODO-CLOSED");
  assert.deepEqual(p.shown(), ["b"]);
  // `_fold` maps `-` and `_` to a space on both sides, so these are the same atom.
  p.type("tags:todo_closed");
  assert.deepEqual(p.shown(), ["b"]);
});
