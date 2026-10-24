// Pure layouts for the pinboard's cards: no DOM and no measurement, so both
// are testable under `node --test` with no browser or DOM shim. `src/pinboard.js`
// is the DOM half — it reads a board's cards, measures what a layout needs,
// calls one of these, and applies the result as CSS custom properties.

const DEFAULTS = { cardWidth: 320, cardHeight: 220, gap: 24, boardWidth: 1200 };

// Lays `ids` left to right in rows that wrap at `boardWidth`, returning a
// `Map` from id to `{x, y}`. A pure function of its arguments: the same
// `ids` in the same order always yields the same positions, which is what
// keeps a board's initial layout stable across builds — `ideas()` already
// sorts by id, so this needs no sort of its own.
export function flowPositions(ids, opts = {}) {
  const { cardWidth, cardHeight, gap, boardWidth } = { ...DEFAULTS, ...opts };
  const perRow = Math.max(1, Math.floor((boardWidth + gap) / (cardWidth + gap)));
  const positions = new Map();
  ids.forEach((id, i) => {
    const col = i % perRow;
    const row = Math.floor(i / perRow);
    positions.set(id, { x: col * (cardWidth + gap), y: row * (cardHeight + gap) });
  });
  return positions;
}

// Stacks `ids` in one column in the given order, returning a `Map` from id to
// `{x, y}`. Every card shares `x`; each `y` is the running sum of the
// preceding cards' real heights (from `heights`, a `Map` from id to pixels —
// a missing or non-finite entry falls back to `DEFAULTS.cardHeight`, a
// spacing constant rather than a measurement) plus one `gap` each, starting
// at `startY`. Ids keep their given order: no sort here, callers hand this
// an already-sorted sequence.
export function stackPositions(ids, opts = {}) {
  const { heights, gap, x, startY } = {
    heights: new Map(),
    gap: DEFAULTS.gap,
    x: 0,
    startY: 0,
    ...opts,
  };
  const positions = new Map();
  let y = startY;
  for (const id of ids) {
    positions.set(id, { x, y });
    const height = heights.get(id);
    y += (Number.isFinite(height) ? height : DEFAULTS.cardHeight) + gap;
  }
  return positions;
}
