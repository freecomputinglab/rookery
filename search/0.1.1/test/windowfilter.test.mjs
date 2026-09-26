// `wireWindowFilter`/`initWindowFilters` — the browser half of `#window`'s
// `display-filter: true`. Core (`@rookery/core`) emits the container, the
// text box and the pills inert; this file is what makes typing and pressing
// actually hide windows, over a real DOM (linkedom), the way `panelinput.test.mjs`
// pins `wirePanel`'s text box.
//
// THE FIXTURE HAS THREE FIGURES: a link row (`unfurl: 0`'s bottomed-out shape)
// tagged `systems`, a second link row tagged `reviews`, and a full window
// (`data-rookery="window"`) tagged `general` titled "Birdkeeping" — one of
// each tag-carrying shape the markup contract names.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wireWindowFilter } from "./internal.mjs";

const MARKUP = `<!doctype html><body>
<div data-rookery="window-filter">
  <div data-rookery="window-filter-controls">
    <input type="search" data-rookery="window-filter-input" placeholder="Filter" aria-label="Filter">
    <button type="button" data-rookery="window-filter-pill" data-rookery-filter-tag="systems" aria-pressed="false">systems</button>
    <button type="button" data-rookery="window-filter-pill" data-rookery-filter-tag="reviews" aria-pressed="false">reviews</button>
  </div>
  <figure>
    <ul data-rookery="page-list"><li data-rookery="page-row" data-rookery-window-link="link" data-rookery-tags="systems"><a href="/a.html">Systems note</a></li></ul>
  </figure>
  <figure>
    <ul data-rookery="page-list"><li data-rookery="page-row" data-rookery-window-link="link" data-rookery-tags="reviews"><a href="/b.html">Reviews note</a></li></ul>
  </figure>
  <figure>
    <div data-rookery="window" data-rookery-tags="general">
      <div data-rookery="window-summary"><span data-rookery="window-title">Birdkeeping</span></div>
    </div>
  </figure>
</div>
</body>`;

const wire = () => {
  const { document } = parseHTML(MARKUP);
  globalThis.document = document;
  const container = document.querySelector('[data-rookery="window-filter"]');
  wireWindowFilter(container);
  const input = document.querySelector('[data-rookery="window-filter-input"]');
  const pill = (tag) =>
    document.querySelector(`[data-rookery="window-filter-pill"][data-rookery-filter-tag="${tag}"]`);
  return {
    document,
    container,
    press: (tag) => pill(tag).dispatchEvent(new document.defaultView.Event("click")),
    pressedState: (tag) => pill(tag).getAttribute("aria-pressed"),
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    visible: () =>
      [...document.querySelectorAll("figure")]
        .filter((f) => !f.hidden)
        .map((f) => f.textContent.trim()),
  };
};

test("wiring marks the container ready", () => {
  const w = wire();
  assert.equal(w.container.getAttribute("data-rookery-ready"), "ready");
});

test("pressing one pill keeps only the figures carrying it", () => {
  const w = wire();
  w.press("systems");
  assert.equal(w.pressedState("systems"), "true");
  const shown = w.visible();
  assert.ok(shown.some((t) => t.includes("Systems note")));
  assert.ok(!shown.some((t) => t.includes("Reviews note")));
  assert.ok(!shown.some((t) => t.includes("Birdkeeping")));
});

test("pressing a second pill widens the result — \"any\", not \"all\"", () => {
  const w = wire();
  w.press("systems");
  w.press("reviews");
  const shown = w.visible();
  assert.ok(shown.some((t) => t.includes("Systems note")));
  assert.ok(shown.some((t) => t.includes("Reviews note")));
  assert.ok(!shown.some((t) => t.includes("Birdkeeping")));
});

test("text and pills compose with AND — clearing pills and typing a title narrows to it", () => {
  const w = wire();
  w.press("systems");
  w.press("reviews");
  w.press("systems");
  w.press("reviews");
  assert.equal(w.pressedState("systems"), "false");
  assert.equal(w.pressedState("reviews"), "false");
  w.type("bird");
  const shown = w.visible();
  assert.deepEqual(shown, ["Birdkeeping"]);
});

test("wiring the same container twice does not double-bind a pill's click", () => {
  const w = wire();
  wireWindowFilter(w.container);
  w.press("systems");
  assert.equal(w.pressedState("systems"), "true");
});
