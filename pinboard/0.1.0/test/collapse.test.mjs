// Unit tests for collapse-to-title. `isCollapsed`/`setCollapsed` are plain
// attribute reads and writes on an element, which linkedom's lightweight DOM
// models faithfully — one of the few things in this package a node test can
// exercise with no browser.

import { strict as assert } from "node:assert";
import { test } from "node:test";
import { parseHTML } from "linkedom";

import { isCollapsed, setCollapsed } from "../src/collapse.js";

function makeCard() {
  const { document } = parseHTML("<!DOCTYPE html><html><body></body></html>");
  const card = document.createElement("article");
  card.setAttribute("class", "pinboard-card");
  const handle = document.createElement("header");
  handle.setAttribute("class", "pinboard-card-handle");
  const button = document.createElement("button");
  button.setAttribute("class", "pinboard-card-toggle");
  button.setAttribute("type", "button");
  button.setAttribute("aria-expanded", "true");
  button.textContent = "−";
  handle.appendChild(button);
  card.appendChild(handle);
  document.body.appendChild(card);
  return { card, button };
}

test("setCollapsed(card, true) sets data-collapsed and aria-expanded=false", () => {
  const { card, button } = makeCard();
  setCollapsed(card, true);
  assert.ok(card.hasAttribute("data-collapsed"));
  assert.equal(button.getAttribute("aria-expanded"), "false");
});

test("setCollapsed(card, false) removes data-collapsed and restores aria-expanded=true", () => {
  const { card, button } = makeCard();
  setCollapsed(card, true);
  setCollapsed(card, false);
  assert.ok(!card.hasAttribute("data-collapsed"));
  assert.equal(button.getAttribute("aria-expanded"), "true");
});

test("setCollapsed is idempotent", () => {
  const { card, button } = makeCard();
  setCollapsed(card, true);
  setCollapsed(card, true);
  assert.ok(card.hasAttribute("data-collapsed"));
  assert.equal(button.getAttribute("aria-expanded"), "false");
  setCollapsed(card, false);
  setCollapsed(card, false);
  assert.ok(!card.hasAttribute("data-collapsed"));
  assert.equal(button.getAttribute("aria-expanded"), "true");
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
  const { card, button } = makeCard();
  // No listener ever attached or run — this is the boot-time restore path.
  setCollapsed(card, true);
  assert.ok(isCollapsed(card));
  assert.equal(button.getAttribute("aria-expanded"), "false");
});
