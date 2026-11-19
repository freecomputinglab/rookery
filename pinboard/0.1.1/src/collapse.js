// Collapse-to-title for pinboard cards. A card is a `@rookery/core` `#window`
// (see `src/board.typ`), so collapsing one is the `<details>` core already
// put there being shut: the `open` attribute is the single source of truth,
// the browser writes it on every click with no JavaScript involved, and this
// module is only what a boot-time restore and the store need to read and
// write the same state from the outside.
//
// The attribute rather than the `open` IDL property, because the two are the
// one thing a non-browser DOM (`node --test` runs these against linkedom) is
// certain to agree about.

// A card's OWN disclosure, never a nested window's: the card's is first in
// document order, so the first match is the right one whatever a note's body
// transcludes further down.
export function cardDetails(card) {
  return card.querySelector('[data-rookery="window-details"]');
}

export function isCollapsed(card) {
  const details = cardDetails(card);
  return details ? !details.hasAttribute("open") : false;
}

// Sets the card's collapsed state directly, independent of any listener
// having run — this is what lets `src/pinboard.js` restore a persisted state
// on a card that has never been clicked.
export function setCollapsed(card, collapsed) {
  const details = cardDetails(card);
  if (!details) return;
  details.toggleAttribute("open", !collapsed);
}

// `opts.onChange`, when given, is called with the card once per toggle —
// `src/pinboard.js` supplies the callback that persists the card's new
// collapsed state via `src/store.js`; this module has no dependency on
// storage at all.
//
// ONE delegated listener on the board, the same delegation `makeDraggable`
// uses in `src/drag.js` for the same reason: a board can carry a hundred
// cards, added and removed only by a rebuild. `toggle` does not bubble, so
// the listener runs in the CAPTURE phase, which reaches it anyway — and
// catches a keyboard activation and a `setCollapsed` call as well as a click,
// which a delegated `click` listener would not.
//
// A boot-time restore therefore re-persists the entry it just read, since the
// `toggle` it queues lands after this is wired. Idempotent, and cheaper than
// a flag that has to be cleared correctly.
export function makeCollapsible(board, opts = {}) {
  // SCOPED TO `opts.signal`, the same AbortController `src/pinboard.js` holds
  // one of per board and aborts before wiring a board a second time — no
  // in-flight state to reset here, `toggle` carries none, so scoping the
  // listener is the whole fix.
  board.addEventListener(
    "toggle",
    (event) => {
      const card = event.target.closest?.(".pinboard-card");
      // A window nested inside a card's body has a disclosure of its own, and
      // opening it says nothing about the card's own state.
      if (!card || cardDetails(card) !== event.target) return;
      opts.onChange?.(card);
    },
    { capture: true, signal: opts.signal },
  );
}
