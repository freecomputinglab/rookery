// Collapse-to-title for pinboard cards. `makeCollapsible(board)` wires ONE
// delegated click listener on the board, the same delegation `makeDraggable`
// uses in `src/drag.js` for the same reason: a board can carry a hundred
// cards, added and removed only by a rebuild, so one listener is cheaper and
// simpler than one per card. `src/drag.js`'s own pointerdown handler already
// ignores a press that lands on a `<button>`, so the toggle and the drag
// never contend for the same gesture.
//
// `data-collapsed` is the single source of truth for a card's state:
// `setCollapsed` is the only place that writes it, `isCollapsed` the only
// place that reads it, and `src/pinboard.css` hides a collapsed card's body
// keyed on that same attribute — nothing here sets an inline style.

export function isCollapsed(card) {
  return card.hasAttribute("data-collapsed");
}

// Sets the card's collapsed state directly, independent of any listener
// having run — this is what lets a boot-time caller (a future bird restoring
// persisted state) collapse a card that has never been clicked.
export function setCollapsed(card, collapsed) {
  if (collapsed) {
    card.setAttribute("data-collapsed", "");
  } else {
    card.removeAttribute("data-collapsed");
  }
  const button = card.querySelector(".pinboard-card-toggle");
  if (!button) return;
  button.setAttribute("aria-expanded", collapsed ? "false" : "true");
  button.textContent = collapsed ? "+" : "−";
}

// `opts.onChange`, when given, is called with the card once per toggle,
// after `setCollapsed` — `src/pinboard.js` supplies the callback that
// persists the card's new collapsed state via `src/store.js`; this module
// has no dependency on storage at all.
export function makeCollapsible(board, opts = {}) {
  board.addEventListener("click", (event) => {
    const toggle = event.target.closest(".pinboard-card-toggle");
    if (!toggle) return;
    const card = toggle.closest(".pinboard-card");
    if (!card) return;
    setCollapsed(card, !isCollapsed(card));
    opts.onChange?.(card);
  });
}
