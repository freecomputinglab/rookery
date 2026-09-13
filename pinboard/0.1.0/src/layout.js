// Pure flow layout for the pinboard's cards: no DOM and no measurement, so it
// is testable under `node --test` with no browser or DOM shim. `src/pinboard.js`
// is the DOM half — it reads a board's cards, calls this, and applies the
// result as CSS custom properties.

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
