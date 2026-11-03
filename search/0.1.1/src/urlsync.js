// A radio group's selection, synced to one query-string param by name — the
// declarative hook a CSS-only tab strip (or any other radio-driven view)
// needs to survive a reload without the consuming site writing a line of
// JavaScript. This module has no idea what a tab is: it only knows a
// radio's `value` attribute and the param name carried on
// `data-rookery-url-radio`.
//
// Reads `getAttribute("value")`, never the `.value` property: a radio with
// no `value` attribute reports `.value === "on"` in the DOM, which would
// sync the whole group to the literal string "on". A radio missing that
// attribute is skipped, and a group where none of its radios carry one
// syncs nothing.
//
// Nothing is written to the URL until the reader changes the selection —
// wiring only ever reads the param, never writes one — so a page nobody has
// touched keeps a clean query string.

import { readParam, writeParam, commit, claimKey } from "./urlstate.js";

// Wires one group scoped to `container`, keyed by `key` in the URL. Returns
// something truthy on success, `null` when there is nothing to sync — no
// valued radio in the container, or `key` already claimed by another group.
//
// `signal` IS OPTIONAL and this is public API, so it stays that way: a caller
// wiring a group by hand has nothing to abort. `init()` passes the signal for
// its own pass, because rheo's dev server re-runs the wiring after it morphs a
// content edit into the live DOM and a radio it matched in place keeps the
// listener the last pass gave it — two `change` handlers then write the same
// param twice per click.
export function wireRadioGroup(container, key, signal) {
  const radios = [...container.querySelectorAll('input[type="radio"]')].filter(
    (radio) => (radio.getAttribute("value") ?? "") !== "",
  );
  // `container` owns the claim, so a re-wire after a morph re-claims rather
  // than colliding with the claim it made last pass.
  if (radios.length === 0 || !claimKey(key, container)) return null;

  const want = readParam(key, location.search);
  if (want !== null && radios.some((radio) => radio.getAttribute("value") === want)) {
    // Setting `.checked` also unchecks its `name`-group siblings in a real
    // browser, but every radio here is set explicitly anyway: this group is
    // scoped to `container`, not to a `name`, so a container holding two
    // `name` groups must not end up with two checked radios.
    for (const radio of radios) radio.checked = radio.getAttribute("value") === want;
  }

  for (const radio of radios) {
    radio.addEventListener("change", () => {
      // `location.search` read here, per event, never captured ahead of
      // time: a synced panel on the same page can write between two of
      // these, and a stale captured string would drop its params.
      commit(writeParam(key, radio.getAttribute("value"), location.search));
    }, { signal });
  }

  return { container, key };
}

export function initUrlSync(signal) {
  for (const el of document.querySelectorAll("[data-rookery-url-radio]")) {
    const key = el.dataset.rookeryUrlRadio;
    if (key) wireRadioGroup(el, key, signal);
  }
}
