// Boot module for @rookery/pinboard, and vite's entry: finds every
// `[data-pinboard]` container already on the page, restores each card's
// pinned position and collapsed state from `src/store.js`, lays out any card
// the store has nothing for with a flow layout from `src/layout.js`, and
// wires the summary-row drag from `src/drag.js` and the card's own
// disclosure from `src/collapse.js` to persist through the same store on
// change. Position rides on the `--pin-x`/`--pin-y` custom properties for
// `src/pinboard.css` to place a card with, and not `style.left`/`style.top`,
// so the store, the flow layout and the drag all go through the same pair.
//
// Restoring the store happens synchronously, before a card is ever painted
// with a flow position — under `rheo watch`, a rebuild reloads the whole
// page (rheo exposes no lighter refresh hook), so a stored layout applied a
// frame late would be a visible jump on every single save.
//
// Injected on every page of a rheo project, most of which carry no board at
// all, so absent a `[data-pinboard]` this finds nothing and returns silently
// — no throw, no console output.

import { flowPositions } from "./layout.js";
import { makeDraggable, readPosition, writePosition } from "./drag.js";
import { makeCollapsible, isCollapsed, setCollapsed } from "./collapse.js";
import { loadBoard, saveCard } from "./store.js";

function layOutBoard(board) {
  const cards = [...board.querySelectorAll(":scope > .pinboard-card")];
  if (cards.length === 0) return;

  const boardId = board.dataset.pinboard;
  const stored = loadBoard(boardId);

  // Shared by both `onChange` callbacks below: a card's persisted entry
  // always carries both its position and its collapsed state together, so
  // whichever one just changed, the save reads the other off the card
  // itself rather than out of stale closure state.
  function persist(card) {
    const pos = readPosition(card);
    saveCard(boardId, card.dataset.pinboardId, {
      x: pos.x,
      y: pos.y,
      collapsed: isCollapsed(card),
    });
  }

  const unplaced = [];
  for (const card of cards) {
    const entry = stored[card.dataset.pinboardId];
    if (!entry) {
      unplaced.push(card);
      continue;
    }
    writePosition(card, entry.x, entry.y);
    if (entry.collapsed) setCollapsed(card, true);
  }

  // Only the cards the store has nothing for get a flow position — a note
  // written since the board was last arranged lands in the first free slot
  // of the grid, rather than wherever a full-board layout would put it.
  if (unplaced.length > 0) {
    const ids = unplaced.map((c) => c.dataset.pinboardId);
    const width = board.getBoundingClientRect().width;
    const positions = flowPositions(ids, width > 0 ? { boardWidth: width } : {});
    for (const card of unplaced) {
      const pt = positions.get(card.dataset.pinboardId);
      if (!pt) continue;
      writePosition(card, pt.x, pt.y);
    }
  }

  makeDraggable(board, { onChange: persist });
  makeCollapsible(board, { onChange: persist });
}

function init() {
  for (const board of document.querySelectorAll("[data-pinboard]")) layOutBoard(board);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
