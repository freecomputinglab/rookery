// Boot module for @rookery/pinboard, and vite's entry: finds every
// `[data-pinboard]` container already on the page, restores each card's
// pinned position and collapsed state from `src/store.js`, lays out any card
// the store has nothing for with the board's chosen layout from
// `src/layout.js`, and wires the summary-row drag from `src/drag.js` and the
// card's own disclosure from `src/collapse.js` to persist through the same
// store on change. The marquee selection from `src/select.js` is wired
// alongside them and persists nothing: a selection is a gesture in progress,
// not part of a board's arrangement. Position rides on the
// `--pin-x`/`--pin-y` custom properties for `src/pinboard.css` to place a
// card with, and not `style.left`/`style.top`, so the store, the layouts and
// the drag all go through the same pair.
//
// Restoring the store happens synchronously, before a card is ever painted
// with a computed position — a stored layout applied a frame late would be a
// visible jump whether the page just loaded or `rheo watch` just morphed it.
//
// THIS FILE DECLARES `js_rehydrate = true` (`typst.toml`) and pushes `init`
// onto `globalThis.__rheoRehydrate`: a rebuild that touched only `.typ` sources
// now patches the edit into the live DOM (Idiomorph) rather than reloading,
// re-running no script, and writes the PRE-HYDRATION markup back over
// whatever a board's boot already did to it — so `init` has to run again,
// exactly as it did on first load, and running it twice on the same board has
// to be safe. `layOutBoard` gets that safety from a fresh wiring per board
// (`@rheo/rehydrate`'s `wiring`, below), which drops the previous pass's
// drag, collapse and selection listeners before wiring a new set on whatever
// the morph left behind. An asset change still reloads the page outright,
// where nothing here runs at all.
//
// Injected on every page of a rheo project, most of which carry no board at
// all, so absent a `[data-pinboard]` this finds nothing and returns silently
// — no throw, no console output.

import { flowPositions, stackPositions } from "./layout.js";
import { makeDraggable, readPosition, writePosition } from "./drag.js";
import { makeCollapsible, isCollapsed, setCollapsed } from "./collapse.js";
import { makeSelectable } from "./select.js";
import { loadBoard, saveCard } from "./store.js";

// ONE WIRING PASS PER BOARD. `layOutBoard` calls three separate modules'
// wiring functions on every pass — `makeDraggable`, `makeCollapsible`,
// `makeSelectable` — so one signal keyed on the board scopes all three, rather
// than a wiring per module.
//
// `@rheo/rehydrate` keeps the per-key controller bookkeeping. READ AT CALL
// TIME: script execution order between two packages is whatever order a
// consuming project imported them in, which neither package can see.
//
// The fallback returns a signal without aborting a previous one, which is only
// reached on a rheo too old to have injected the helper — and that is a rheo too
// old to morph, so it reloads the page and there is no previous pass to drop.
const wiring = (key) =>
  globalThis.RheoRehydrate?.wiring?.(key) ?? new AbortController().signal;

// Recomputes `--pinboard-height` (read by `src/pinboard.css`) from every
// card's own bottom edge, so the board both grows and shrinks with its
// content — a card opening or a drag ending both call this. `growBoardFor`
// below is the grow-only path used while a drag is still in flight, where
// measuring every card on each `pointermove` would be too slow.
function sizeBoard(board) {
  const cards = [...board.querySelectorAll(":scope > .pinboard-card")];
  let maxBottom = 0;
  for (const card of cards) {
    const bottom = readPosition(card).y + card.getBoundingClientRect().height;
    if (bottom > maxBottom) maxBottom = bottom;
  }
  board.style.setProperty("--pinboard-height", `${maxBottom + 24}px`);
}

// The per-frame half of `sizeBoard`, for a card being dragged: raises
// `--pinboard-height` to clear this one card's bottom edge and never
// lowers it, so a drag downward grows the board under the pointer
// instead of stopping at its old extent. The drag's end calls `persist`,
// and so `sizeBoard`, which recomputes the exact height from every card.
function growBoardFor(board, card) {
  const bottom = readPosition(card).y + card.getBoundingClientRect().height + 24;
  const current = parseFloat(board.style.getPropertyValue("--pinboard-height")) || 0;
  if (bottom > current) board.style.setProperty("--pinboard-height", `${bottom}px`);
}

function layOutBoard(board) {
  // Abandoned BEFORE anything below runs, so a re-wire cannot briefly leave
  // this pass's listeners racing the last one's, and so a board that has
  // lost its last card since the previous pass still drops whatever that
  // pass wired on it rather than returning early with the old listeners
  // still live. `signal` then scopes every listener `makeDraggable`,
  // `makeCollapsible` and `makeSelectable` add below, and the NEXT pass's
  // abort drops all three sets in one call.
  const signal = wiring(board);

  const cards = [...board.querySelectorAll(":scope > .pinboard-card")];
  if (cards.length === 0) return;

  const boardId = board.dataset.pinboard;
  const stored = loadBoard(boardId);

  // Shared by both `onChange` callbacks below: a card's persisted entry
  // always carries both its position and its collapsed state together, so
  // whichever one just changed, the save reads the other off the card
  // itself rather than out of stale closure state. Either change can also
  // grow the board, so both re-measure it.
  function persist(card) {
    const pos = readPosition(card);
    saveCard(boardId, card.dataset.pinboardId, {
      x: pos.x,
      y: pos.y,
      collapsed: isCollapsed(card),
    });
    sizeBoard(board);
  }

  // A board built by an older copy of the Typst half carries no
  // `data-pinboard-layout` at all — treated as the current default,
  // `"stack"`, rather than the old `"flow"`.
  const useFlow = board.dataset.pinboardLayout === "flow";

  const unplaced = [];
  let restoredBottom = 0;
  for (const card of cards) {
    const entry = stored[card.dataset.pinboardId];
    if (!entry) {
      unplaced.push(card);
      continue;
    }
    writePosition(card, entry.x, entry.y);
    setCollapsed(card, entry.collapsed);
    const bottom = entry.y + card.getBoundingClientRect().height;
    if (bottom > restoredBottom) restoredBottom = bottom;
  }

  // Only the cards the store has nothing for get a computed position — a
  // note written since the board was last arranged lands after whatever the
  // store already placed, rather than wherever a full-board layout would
  // put it.
  if (unplaced.length > 0) {
    const ids = unplaced.map((c) => c.dataset.pinboardId);
    if (useFlow) {
      const width = board.getBoundingClientRect().width;
      const positions = flowPositions(ids, width > 0 ? { boardWidth: width } : {});
      for (const card of unplaced) {
        const pt = positions.get(card.dataset.pinboardId);
        if (!pt) continue;
        writePosition(card, pt.x, pt.y);
      }
    } else {
      // Read every unplaced card's height before writing any position: an
      // interleaved read/write per card is a forced layout per card, and a
      // board carries a hundred of them.
      const heights = new Map();
      for (const card of unplaced) {
        heights.set(card.dataset.pinboardId, card.getBoundingClientRect().height);
      }
      const positions = stackPositions(ids, { heights, startY: restoredBottom, x: 0 });
      for (const card of unplaced) {
        const pt = positions.get(card.dataset.pinboardId);
        if (!pt) continue;
        writePosition(card, pt.x, pt.y);
      }
    }
  }

  sizeBoard(board);
  makeDraggable(board, { onChange: persist, onMove: (card) => growBoardFor(board, card), signal });
  makeCollapsible(board, { onChange: persist, signal });
  makeSelectable(board, { signal });
}

function init() {
  for (const board of document.querySelectorAll("[data-pinboard]")) layOutBoard(board);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}

// REHYDRATE AFTER A rheo MORPH. The dev server patches a content edit into
// the live DOM instead of reloading (`docs/contract.md`), which re-runs no
// script — and the markup it patches in is the PRE-HYDRATION build output,
// so every board comes back with no `--pinboard-height`, no restored
// `--pin-x`/`--pin-y` and no restored collapsed state, while listeners bound
// to whatever nodes survived the morph are still live. `js_rehydrate = true`
// in `typst.toml` is the other half of the declaration: without it rheo
// reloads the page and never calls this.
//
// RE-RUNNING `init()` IS SAFE: `layOutBoard` aborts its own previous pass's
// listeners before wiring a new set (`@rheo/rehydrate`'s `wiring`, keyed on
// the board, the same helper `@rookery/search`'s `panel.js` uses), and
// every boot-time DOM write it makes — the custom properties, the
// position/collapsed restore — is a write rather than an append, so
// repeating it changes nothing a second time. Nothing needs preserving by
// hand across the morph either: a board's arrangement lives in
// `localStorage`, read fresh by `src/store.js` on every pass, not in any
// variable this module or `drag.js`/`select.js` would otherwise have to
// carry across the rewire.
//
// `globalThis`, not `window`: the node suites supply a document and no
// `window`, and reading one at module-evaluation time would throw there on
// an access every real page satisfies for free.
(globalThis.__rheoRehydrate ??= []).push(init);
