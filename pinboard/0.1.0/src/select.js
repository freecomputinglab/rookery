// Marquee (rubber-band) selection for pinboard cards. Selection is the
// `data-selected` attribute on a card, not a JavaScript set: the DOM is the
// single source of truth, it is stylable straight from CSS, and it lets
// `src/drag.js` read the current selection without importing this module
// back for it. A card's rectangle is its `--pin-x`/`--pin-y` pair plus its
// offset size, since `.pinboard` is the cards' own coordinate space — no
// `getBoundingClientRect` needed for the hit test.

import { readPosition, movedEnough } from "./drag.js";

// The marquee's rectangle from the two pointer positions it was dragged
// between, in board coordinates. Normalized, so a drag up-and-left is the
// same rectangle as the drag down-and-right that traces it backwards.
export function marqueeRect(start, pointer) {
  const x = Math.min(start.x, pointer.x);
  const y = Math.min(start.y, pointer.y);
  return {
    x,
    y,
    width: Math.abs(pointer.x - start.x),
    height: Math.abs(pointer.y - start.y),
  };
}

// Any overlap counts, not containment: a reader dragging a band across a
// column of cards means the ones it crossed, not only the ones it managed
// to swallow whole. Edge-touching does not count.
export function rectsOverlap(a, b) {
  return (
    a.x < b.x + b.width &&
    b.x < a.x + a.width &&
    a.y < b.y + b.height &&
    b.y < a.y + a.height
  );
}

// A card's rectangle in board coordinates.
export function cardRect(card) {
  const pos = readPosition(card);
  return { x: pos.x, y: pos.y, width: card.offsetWidth, height: card.offsetHeight };
}

export function selectedCards(board) {
  return [...board.querySelectorAll(".pinboard-card[data-selected]")];
}

export function isSelected(card) {
  return card.hasAttribute("data-selected");
}

export function setSelected(card, selected) {
  card.toggleAttribute("data-selected", selected);
}

export function clearSelection(board) {
  for (const card of selectedCards(board)) setSelected(card, false);
}

export function makeSelectable(board, opts = {}) {
  let gesture = null;

  board.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) return;
    // A press on a card belongs to `src/drag.js`'s own gesture.
    if (event.target.closest(".pinboard-card")) return;

    clearSelection(board);
    // The board's rect is read once per gesture, here, rather than on every
    // `pointermove` — that would be a forced layout per frame.
    const rect = board.getBoundingClientRect();
    gesture = {
      startPointer: { x: event.clientX - rect.left, y: event.clientY - rect.top },
      boardRect: rect,
      pointerId: event.pointerId,
      band: null,
    };
  });

  board.addEventListener("pointermove", (event) => {
    if (!gesture) return;
    const pointer = {
      x: event.clientX - gesture.boardRect.left,
      y: event.clientY - gesture.boardRect.top,
    };
    if (!gesture.band) {
      if (!movedEnough(gesture.startPointer, pointer)) return;
      gesture.band = document.createElement("div");
      gesture.band.className = "pinboard-marquee";
      board.appendChild(gesture.band);
      board.setPointerCapture(event.pointerId);
    }
    const rect = marqueeRect(gesture.startPointer, pointer);
    gesture.band.style.left = `${rect.x}px`;
    gesture.band.style.top = `${rect.y}px`;
    gesture.band.style.width = `${rect.width}px`;
    gesture.band.style.height = `${rect.height}px`;
    gesture.lastPointer = pointer;
  });

  function endGesture(select) {
    if (!gesture) return;
    const { band, pointerId, startPointer, lastPointer } = gesture;
    gesture = null;
    if (!band) return;
    if (select) {
      const rect = marqueeRect(startPointer, lastPointer);
      for (const card of board.querySelectorAll(":scope > .pinboard-card")) {
        if (rectsOverlap(cardRect(card), rect)) setSelected(card, true);
      }
      opts.onChange?.(selectedCards(board));
    }
    band.remove();
    if (board.hasPointerCapture(pointerId)) board.releasePointerCapture(pointerId);
  }

  board.addEventListener("pointerup", () => endGesture(true));
  // A gesture the browser takes over must not leave the board stuck with a
  // band on it, mirroring `src/drag.js`'s own `pointercancel` handling.
  board.addEventListener("pointercancel", () => endGesture(false));
}
