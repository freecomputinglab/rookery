// `wirePanel`'s MULTI-VALUED FACETS (`data-panel-multi`), over a real DOM (linkedom),
// because the whole of this feature is a predicate reading an attribute — and the two
// halves that have to agree about it are in different languages.
//
// WHAT IT PINS. A scalar facet tests `wanted.has(row.values[field])`; a multi-valued
// one has to INTERSECT, and a row's attribute holds `" a b "` rather than a value. Get
// either half wrong and the pills match NOTHING while the page still renders and the
// build still passes — which is the failure mode every guard in `panel.typ` is written
// against, and the one a markup grep cannot see because the pills are correct markup.
//
// The composition rules are the point of the last two tests: within a group the values
// OR (pressing a second tag widens), and across groups they AND (a tag and a state
// narrow together). That is what `#filter-panel`'s single undifferentiated pill row
// could not express and what `multi:` exists to keep.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

// Three rows over two groups: `tag` is multi-valued, `state` is not. `b` carries both
// tags, which is the only row an intersection test and an equality test disagree about.
const PANEL = `<!doctype html><body>
<div class="panel" data-panel-ready="false" data-panel-multi="tag">
<input class="panel-input" type="search">
<div class="panel-pills">
  <span class="panel-pill-group" data-panel-group="tag">
    <button class="panel-pill" data-panel-facet="tag" data-panel-value="frontend" aria-pressed="false">frontend</button>
    <button class="panel-pill" data-panel-facet="tag" data-panel-value="phd" aria-pressed="false">phd</button>
  </span>
  <span class="panel-pill-group" data-panel-group="state">
    <button class="panel-pill" data-panel-facet="state" data-panel-value="ready" aria-pressed="false">ready</button>
    <button class="panel-pill" data-panel-facet="state" data-panel-value="blocked" aria-pressed="false">blocked</button>
  </span>
</div>
<p class="panel-count">3 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha" data-tag=" frontend " data-state="ready">a</li>
<li class="panel-row" data-panel-text="beta" data-tag=" frontend phd " data-state="blocked">b</li>
<li class="panel-row" data-panel-text="gamma" data-tag="" data-state="ready">c</li>
</ul></div></body>`;

const wire = () => {
  const { document } = parseHTML(PANEL);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  return {
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

test("no pill pressed shows every row, the untagged one included", () => {
  const p = wire();
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 rows");
});

test("a tag pill keeps every row CARRYING that tag, not one equal to it", () => {
  const p = wire();
  p.press("tag", "phd");
  // `b`'s attribute is " frontend phd ": an equality test against "phd" finds nothing,
  // which is exactly the bug this file exists to catch.
  assert.deepEqual(p.shown(), ["b"]);
  assert.equal(p.count(), "1 of 3");
});

test("a row carrying two tags is matched by either", () => {
  const p = wire();
  p.press("tag", "frontend");
  assert.deepEqual(p.shown(), ["a", "b"]);
});

test("two tag pills OR — a second press WIDENS the list", () => {
  const p = wire();
  p.press("tag", "phd");
  assert.deepEqual(p.shown(), ["b"]);
  p.press("tag", "frontend");
  assert.deepEqual(p.shown(), ["a", "b"]);
});

test("pressing a tag again releases it", () => {
  const p = wire();
  p.press("tag", "phd");
  p.press("tag", "phd");
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 rows");
});

test("a tag group ANDs with a scalar group — the two narrow together", () => {
  const p = wire();
  p.press("tag", "frontend");
  p.press("state", "ready");
  // `b` carries `frontend` but is blocked; `c` is ready but untagged.
  assert.deepEqual(p.shown(), ["a"]);
});

test("a tag pill and a state that no row combines matches nothing", () => {
  const p = wire();
  p.press("tag", "phd");
  p.press("state", "ready");
  assert.deepEqual(p.shown(), []);
  assert.equal(p.count(), "nothing matches");
});

test("with no data-panel-multi a tag attribute is compared as a whole value", () => {
  // THE DEFAULT IS UNCHANGED, which is what keeps every panel written before this
  // feature reading exactly as it did: absent the declaration the field is a scalar,
  // so `" frontend phd "` is one value and matches no pill. Pinned so the tokenizing
  // cannot leak into the scalar path.
  const { document } = parseHTML(PANEL.replace(' data-panel-multi="tag"', ""));
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  document
    .querySelector('.panel-pill[data-panel-facet="tag"][data-panel-value="phd"]')
    .dispatchEvent(new document.defaultView.Event("click"));
  assert.deepEqual(
    [...document.querySelectorAll(".panel-row")].filter((r) => !r.hidden).map((r) => r.textContent),
    [],
  );
});
