// Drag-by-summary for pinboard cards. `makeDraggable(board)` wires ONE set of
// Pointer Event listeners on the board itself and lets events from the cards
// bubble up to it — a board can carry a hundred cards, added and removed
// only by a rebuild, so a delegated listener is both cheaper and simpler
// than one per card.
//
// THE HANDLE IS THE WINDOW'S SUMMARY ROW, which is also the control that
// opens the card (`src/board.typ` renders each card as a `@rookery/core`
// `#window`). Two gestures on one row, told apart by distance: a press that
// stays inside `DRAG_THRESHOLD` is a click and must reach the `<summary>`
// under it, anything further is a drag and the click it ends with is
// suppressed. A press on a SELECTED card (`src/select.js`'s `data-selected`)
// drags every selected card together, preserving their relative offsets; a
// press on an unselected one drops the selection first and drags that card
// alone. Hence the two rules below that read as omissions:
//
//   - NO `preventDefault` on `pointerdown`. It is the ordinary way to stop a
//     drag becoming a text selection, and it also costs the disclosure its
//     click; `src/pinboard.css` sets `user-select: none` on the row instead.
//   - NO pointer capture until the threshold is crossed. A captured pointer
//     retargets the click that follows it to the capturing element, so
//     capturing at `pointerdown` would mean no click ever reached a summary.
//
// Position rides on the `--pin-x`/`--pin-y` custom properties `src/pinboard.js`
// already writes; `readPosition`/`writePosition` are the one pair of helpers
// that touch them.
//
// `makeDraggable`'s `opts.onChange` is called once per drag, with the card,
// when the gesture ends — not on every `pointermove`, which would mean a
// synchronous storage write per frame, and not at all for a press that only
// clicked. `src/pinboard.js` supplies the callback that persists a card's new
// position via `src/store.js`; this module has no dependency on storage.
// `opts.onMove`, unlike `onChange`, IS called on every `pointermove` of a
// real drag, so the board's height can follow a card dragged past its
// bottom edge — it must stay cheap and must not write to storage.

import { selectedCards, isSelected, clearSelection } from "./select.js";

const HANDLE = '[data-rookery="window-summary"]';

// Pixels of pointer movement that separate a click from a drag.
export const DRAG_THRESHOLD = 3;

export function readPosition(card) {
  return {
    x: parseFloat(card.style.getPropertyValue("--pin-x")) || 0,
    y: parseFloat(card.style.getPropertyValue("--pin-y")) || 0,
  };
}

export function writePosition(card, x, y) {
  card.style.setProperty("--pin-x", `${x}px`);
  card.style.setProperty("--pin-y", `${y}px`);
}

// Whether the pointer has travelled far enough for this gesture to be a drag
// rather than a click. Either axis on its own is enough: the threshold is a
// square around the press, not a circle, which costs a comparison instead of
// a square root and is indistinguishable at three pixels.
export function movedEnough(startPointer, pointer, threshold = DRAG_THRESHOLD) {
  return (
    Math.abs(pointer.x - startPointer.x) >= threshold ||
    Math.abs(pointer.y - startPointer.y) >= threshold
  );
}

// Narrows a drag's delta until every card in the group stays inside the
// board, rather than clamping each card on its own — an independent clamp
// deforms the group the moment one member reaches an edge, and the whole
// point of a group drag is that the arrangement travels intact. The bound
// from each card is gathered first and the delta clamped once at the end:
// clamping card by card lets a later card's bound undo an earlier card's,
// so the result would depend on the order the cards happen to arrive in.
// Only `dx` has an upper bound: `dy` has a floor and no ceiling, because a
// drag downward is how the board is made taller, and `src/pinboard.js`'s
// `growBoardFor` raises `--pinboard-height` to follow it. A group wider than
// the board can leave its left and right bounds unsatisfiable together; the
// left bound wins, since a card pushed to a negative `x` cannot be dragged
// back (the board does not scroll leftward), while one left past the right
// edge is still draggable.
export function clampGroupDelta(items, delta, boardWidth) {
  let minDx = -Infinity;
  let maxDx = Infinity;
  let minDy = -Infinity;
  for (const item of items) {
    minDx = Math.max(minDx, -item.x);
    maxDx = Math.min(maxDx, boardWidth - item.width - item.x);
    minDy = Math.max(minDy, -item.y);
  }
  const ceilingDx = Math.max(maxDx, minDx);
  // `+ 0` folds a `-0` produced by clamping against a card already at that
  // edge (`Math.max`/`Math.min` preserve the sign of a zero bound) back to
  // an ordinary zero, which a caller comparing the delta to `0` expects.
  return {
    x: Math.min(Math.max(delta.x, minDx), ceilingDx) + 0,
    y: Math.max(delta.y, minDy) + 0,
  };
}

export function makeDraggable(board, opts = {}) {
  let topZ = 1;
  let drag = null;
  // The one-shot listener that eats the click ending a real drag, so letting
  // go over the summary does not also toggle the card. Held in a variable
  // rather than added with `{ once: true }` alone, because a gesture that ends
  // without a click — a `pointercancel`, a drag released outside the board —
  // would otherwise leave it armed for the next, unrelated click.
  let suppressor = null;

  function clearSuppressor() {
    if (!suppressor) return;
    board.removeEventListener("click", suppressor, true);
    suppressor = null;
  }

  function suppressNextClick() {
    clearSuppressor();
    suppressor = (event) => {
      event.preventDefault();
      event.stopPropagation();
      clearSuppressor();
    };
    board.addEventListener("click", suppressor, true);
  }

  board.addEventListener("pointerdown", (event) => {
    const handle = event.target.closest(HANDLE);
    if (!handle) return;
    // The hat carries the note's permalink; a press that lands on it (or on
    // any other interactive descendant of the row) must not swallow its click.
    if (event.target.closest("a, button, input")) return;
    if (event.button !== 0) return;
    const card = handle.closest(".pinboard-card");
    if (!card) return;

    // A press on a selected card moves the whole selection; a press on an
    // unselected one is the "click anywhere that is not a selected handle"
    // that drops the selection, and then drags that card alone.
    let cards;
    if (isSelected(card)) {
      cards = selectedCards(board);
    } else {
      clearSelection(board);
      cards = [card];
    }

    clearSuppressor();
    drag = {
      cards,
      starts: cards.map((c) => readPosition(c)),
      startPointer: { x: event.clientX, y: event.clientY },
      pointerId: event.pointerId,
      moved: false,
    };
    // Raised on the press rather than on the drag: a card the reader is
    // reading belongs in front of the ones it overlaps, whether or not they
    // go on to move it.
    for (const c of cards) c.style.zIndex = String(++topZ);
  });

  board.addEventListener("pointermove", (event) => {
    if (!drag) return;
    const pointer = { x: event.clientX, y: event.clientY };
    const { cards, starts, startPointer } = drag;
    if (!drag.moved) {
      if (!movedEnough(startPointer, pointer)) return;
      drag.moved = true;
      for (const c of cards) c.dataset.dragging = "";
      // From here the gesture is a drag, and capture keeps it on the board
      // even when the pointer outruns the cards.
      board.setPointerCapture(event.pointerId);
    }
    const items = cards.map((c, i) => ({
      x: starts[i].x,
      y: starts[i].y,
      width: c.offsetWidth,
    }));
    const delta = clampGroupDelta(
      items,
      { x: pointer.x - startPointer.x, y: pointer.y - startPointer.y },
      board.scrollWidth,
    );
    cards.forEach((c, i) => {
      writePosition(c, starts[i].x + delta.x, starts[i].y + delta.y);
      opts.onMove?.(c);
    });
  });

  function endDrag() {
    if (!drag) return;
    const { cards, moved, pointerId } = drag;
    drag = null;
    if (!moved) return;
    for (const c of cards) delete c.dataset.dragging;
    if (board.hasPointerCapture(pointerId)) board.releasePointerCapture(pointerId);
    suppressNextClick();
    for (const c of cards) opts.onChange?.(c);
  }

  // `pointercancel` fires when the browser takes the gesture over — a touch
  // turning into a scroll, for instance — and must end the drag exactly as
  // `pointerup` does, or the board is left stuck mid-drag until reload.
  board.addEventListener("pointerup", endDrag);
  board.addEventListener("pointercancel", endDrag);
}
