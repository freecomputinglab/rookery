// Boot module for @rookery/pinboard, and vite's entry: finds every
// `[data-pinboard]` container already on the page, computes a flow layout
// for its cards with `src/layout.js`, writes each card's position as
// `--pin-x`/`--pin-y` custom properties for `src/pinboard.css` to place it
// with, and wires the handle drag from `src/drag.js`. Position rides on
// those two properties, and not `style.left`/`style.top`, so the flow
// layout and the drag both go through the same pair.
//
// Injected on every page of a rheo project, most of which carry no board at
// all, so absent a `[data-pinboard]` this finds nothing and returns silently
// — no throw, no console output.

import { flowPositions } from "./layout.js";
import { makeDraggable, writePosition } from "./drag.js";

function layOutBoard(board) {
  const cards = [...board.querySelectorAll(":scope > .pinboard-card")];
  if (cards.length === 0) return;
  const ids = cards.map((c) => c.dataset.pinboardId);
  const width = board.getBoundingClientRect().width;
  const positions = flowPositions(ids, width > 0 ? { boardWidth: width } : {});
  for (const card of cards) {
    const pt = positions.get(card.dataset.pinboardId);
    if (!pt) continue;
    writePosition(card, pt.x, pt.y);
  }
  makeDraggable(board);
}

function init() {
  for (const board of document.querySelectorAll("[data-pinboard]")) layOutBoard(board);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
