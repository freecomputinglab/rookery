// Unit tests for collapse-to-title. `isCollapsed`/`setCollapsed` are plain
// attribute reads and writes on the `<details>` a card's `#window` puts there,
// which linkedom's lightweight DOM models faithfully — one of the few things
// in this package a node test can exercise with no browser.

import { strict as assert } from "node:assert";
import { test } from "node:test";
import { parseHTML } from "linkedom";

import { cardDetails, isCollapsed, setCollapsed } from "../src/collapse.js";

// The DOM `src/board.typ` renders, trimmed to what these functions read: the
// card, and the window's disclosure inside the figure core wraps it in.
function makeCard({ nested = false } = {}) {
  const body = nested
    ? '<details data-rookery="window-details" open><summary>nested</summary></details>'
    : "prose";
  const { document } = parseHTML(`<!DOCTYPE html><html><body>
    <article class="pinboard-card" data-pinboard-id="idea:etal">
      <figure><div data-rookery="window">
        <details class="idea-window-details" data-rookery="window-details" open>
          <summary data-rookery="window-summary">Outline</summary>
          <div data-rookery="window-body">${body}</div>
        </details>
      </div></figure>
    </article>
  </body></html>`);
  const card = document.querySelector(".pinboard-card");
  return { card, details: cardDetails(card) };
}

test("setCollapsed(card, true) shuts the card's disclosure", () => {
  const { card, details } = makeCard();
  setCollapsed(card, true);
  assert.ok(!details.hasAttribute("open"));
});

test("setCollapsed(card, false) opens it again", () => {
  const { card, details } = makeCard();
  setCollapsed(card, true);
  setCollapsed(card, false);
  assert.ok(details.hasAttribute("open"));
});

test("setCollapsed is idempotent", () => {
  const { card, details } = makeCard();
  setCollapsed(card, true);
  setCollapsed(card, true);
  assert.ok(!details.hasAttribute("open"));
  setCollapsed(card, false);
  setCollapsed(card, false);
  assert.ok(details.hasAttribute("open"));
});

test("isCollapsed agrees with what setCollapsed last set", () => {
  const { card } = makeCard();
  assert.equal(isCollapsed(card), false);
  setCollapsed(card, true);
  assert.equal(isCollapsed(card), true);
  setCollapsed(card, false);
  assert.equal(isCollapsed(card), false);
});

test("setCollapsed(card, true) works on a card that has never been clicked", () => {
  const { card } = makeCard();
  // No listener ever attached or run — this is the boot-time restore path.
  setCollapsed(card, true);
  assert.ok(isCollapsed(card));
});

test("a window nested in the body does not stand in for the card's own", () => {
  const { card, details } = makeCard({ nested: true });
  const inner = card.querySelector('[data-rookery="window-body"] details');
  assert.equal(cardDetails(card), details);
  setCollapsed(card, true);
  assert.ok(!details.hasAttribute("open"));
  assert.ok(inner.hasAttribute("open"));
});

test("a card with no window at all reads as open and takes no writes", () => {
  const { document } = parseHTML(
    '<!DOCTYPE html><html><body><article class="pinboard-card"></article></body></html>',
  );
  const card = document.querySelector(".pinboard-card");
  assert.equal(isCollapsed(card), false);
  setCollapsed(card, true);
  assert.equal(isCollapsed(card), false);
});
