// Drag-by-handle for pinboard cards. `makeDraggable(board)` wires ONE set of
// Pointer Event listeners on the board itself and lets events from the cards
// bubble up to it — a board can carry a hundred cards, added and removed
// only by a rebuild, so a delegated listener is both cheaper and simpler
// than one per card.
//
// Position rides on the `--pin-x`/`--pin-y` custom properties `src/pinboard.js`
// already writes; `readPosition`/`writePosition` are the one pair of helpers
// that touch them, so the bird that persists positions has one place to
// hook rather than three call sites to find.

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

// The dragged position is the drag's start position plus the pointer's
// delta since `pointerdown` — never the raw pointer position, which would
// snap the card's top-left corner under the cursor the instant a drag
// begins.
export function offsetPosition(start, startPointer, pointer) {
  return {
    x: start.x + (pointer.x - startPointer.x),
    y: start.y + (pointer.y - startPointer.y),
  };
}

// Clamps a card's position so it never carries the card off the board: `x`
// and `y` are never negative, and the card's own width/height never push it
// past the board's scrollable extent.
export function clampPosition(pos, size, boardSize) {
  const maxX = Math.max(0, boardSize.width - size.width);
  const maxY = Math.max(0, boardSize.height - size.height);
  return {
    x: Math.min(Math.max(0, pos.x), maxX),
    y: Math.min(Math.max(0, pos.y), maxY),
  };
}

export function makeDraggable(board) {
  let topZ = 1;
  let drag = null;

  board.addEventListener("pointerdown", (event) => {
    const handle = event.target.closest(".pinboard-card-handle");
    if (!handle) return;
    // The card title is a link to the note's own page; a drag that starts
    // on it (or on any other interactive descendant of the handle) must not
    // swallow that click.
    if (event.target.closest("a, button, input, summary")) return;
    if (event.button !== 0) return;
    const card = handle.closest(".pinboard-card");
    if (!card) return;

    drag = {
      card,
      start: readPosition(card),
      startPointer: { x: event.clientX, y: event.clientY },
    };
    card.dataset.dragging = "";
    card.style.zIndex = String(++topZ);
    board.setPointerCapture(event.pointerId);
    // Suppresses native text-selection and image-drag, which would
    // otherwise fight the drag for the same gesture.
    event.preventDefault();
  });

  board.addEventListener("pointermove", (event) => {
    if (!drag) return;
    const { card, start, startPointer } = drag;
    const next = offsetPosition(start, startPointer, { x: event.clientX, y: event.clientY });
    const clamped = clampPosition(
      next,
      { width: card.offsetWidth, height: card.offsetHeight },
      { width: board.scrollWidth, height: board.scrollHeight },
    );
    writePosition(card, clamped.x, clamped.y);
  });

  function endDrag(event) {
    if (!drag) return;
    delete drag.card.dataset.dragging;
    board.releasePointerCapture(event.pointerId);
    drag = null;
  }

  // `pointercancel` fires when the browser takes the gesture over — a touch
  // turning into a scroll, for instance — and must end the drag exactly as
  // `pointerup` does, or the board is left stuck mid-drag until reload.
  board.addEventListener("pointerup", endDrag);
  board.addEventListener("pointercancel", endDrag);
}
