// `wirePanel`'s PILL MIRRORING, over a real DOM (linkedom): a facet value may be drawn
// TWICE on one panel — once in the pill block, once again inside its own row, which is
// what `@rookery/todos` wants for a row's own tag badge — and `aria-pressed` is the
// state, so both copies must always agree.
//
// WHAT IT PINS. Pressing either copy has to set BOTH buttons' `aria-pressed`, an in-row
// press has to filter the list exactly as a block press does (it is a real pill, not
// decoration), and pressing one copy then the other has to RELEASE the filter — the
// underlying value is toggled once, never added twice because two buttons answered one
// click each. The last test pins that a pill with only one copy on the page still
// behaves exactly as it always did.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

// `state` carries "ready" TWICE: once in the pill block, once inside row `a`'s own
// list item, standing in for a row drawing its own facet value as a badge.
const PANEL = `<!doctype html><body>
<div class="panel" data-panel-ready="false">
<input class="panel-input" type="search">
<div class="panel-pills">
  <span class="panel-pill-group" data-panel-group="state">
    <button class="panel-pill" data-panel-facet="state" data-panel-value="ready" aria-pressed="false">ready</button>
    <button class="panel-pill" data-panel-facet="state" data-panel-value="blocked" aria-pressed="false">blocked</button>
  </span>
</div>
<p class="panel-count">3 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha" data-state="ready">a
  <button class="panel-pill" data-panel-facet="state" data-panel-value="ready" aria-pressed="false">ready</button>
</li>
<li class="panel-row" data-panel-text="beta" data-state="blocked">b</li>
<li class="panel-row" data-panel-text="gamma" data-state="ready">c</li>
</ul></div></body>`;

const wire = () => {
  const { document } = parseHTML(PANEL);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  return document;
};

const blockPill = (document, value) =>
  document.querySelector(`.panel-pills .panel-pill[data-panel-value="${value}"]`);
const rowPill = (document, value) =>
  document.querySelector(`.panel-row .panel-pill[data-panel-value="${value}"]`);
const press = (el, document) => el.dispatchEvent(new document.defaultView.Event("click"));
const shownIds = (document) =>
  [...document.querySelectorAll(".panel-row")]
    .filter((r) => !r.hidden)
    .map((r) => r.dataset.panelText)
    .sort();

test("pressing the block copy mirrors aria-pressed onto the row copy", () => {
  const document = wire();
  press(blockPill(document, "ready"), document);
  assert.equal(blockPill(document, "ready").getAttribute("aria-pressed"), "true");
  assert.equal(rowPill(document, "ready").getAttribute("aria-pressed"), "true");
});

test("pressing the row copy mirrors onto the block copy and actually filters the list", () => {
  const document = wire();
  press(rowPill(document, "ready"), document);
  assert.equal(blockPill(document, "ready").getAttribute("aria-pressed"), "true");
  assert.equal(rowPill(document, "ready").getAttribute("aria-pressed"), "true");
  // An in-row pill is a working filter, not decoration: only the "ready" rows remain.
  assert.deepEqual(shownIds(document), ["alpha", "gamma"]);
});

test("pressing one copy and then the other RELEASES the filter, not toggling it twice", () => {
  const document = wire();
  press(blockPill(document, "ready"), document);
  press(rowPill(document, "ready"), document);
  assert.equal(blockPill(document, "ready").getAttribute("aria-pressed"), "false");
  assert.equal(rowPill(document, "ready").getAttribute("aria-pressed"), "false");
  assert.deepEqual(shownIds(document), ["alpha", "beta", "gamma"]);
});

test("a pill with only one copy on the panel behaves exactly as before", () => {
  const document = wire();
  const blocked = blockPill(document, "blocked");
  press(blocked, document);
  assert.equal(blocked.getAttribute("aria-pressed"), "true");
  press(blocked, document);
  assert.equal(blocked.getAttribute("aria-pressed"), "false");
});
