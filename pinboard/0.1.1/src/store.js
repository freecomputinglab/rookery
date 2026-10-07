// Persists a board's card positions and collapse state to `localStorage`,
// keyed on the board's own id (`data-pinboard`) rather than the page's path —
// moving or renaming the file that holds `#pinboard(id: ..)` must not throw
// the arrangement away, and two boards sharing an id sharing a layout is the
// author's business for choosing that id in the first place.
//
// The entry for each card is keyed on the idea's own stable id (the
// `data-pinboard-id` `src/board.typ` emits from `core`'s `ideas()`), which is
// what lets a card's place survive edits to its title and prose: the note
// keeps its id no matter what changes underneath it.
//
// `localStorage` can throw on mere access — a private window, blocked site
// data, some embedding contexts — so every read and write here is wrapped;
// a board that cannot read or write storage falls back to the flow layout
// and boots anyway, rather than throwing during boot.

export function storageKey(boardId) {
  return `rookery-pinboard:${boardId}`;
}

function isFiniteNumber(n) {
  return typeof n === "number" && Number.isFinite(n);
}

// Discards a malformed entry rather than the whole board's layout — one bad
// value (a corrupted write, a future shape this version doesn't know) must
// cost that one card its saved position, not every card on the board.
function isValidEntry(entry) {
  return (
    entry !== null &&
    typeof entry === "object" &&
    isFiniteNumber(entry.x) &&
    isFiniteNumber(entry.y)
  );
}

// -> `{ "<idea id>": { x, y, collapsed } }`. Never throws: a missing key, a
// storage access that throws, a value that isn't valid JSON, or a value that
// doesn't parse to a plain object all fall back to `{}`, and invalid entries
// within an otherwise-valid object are dropped individually.
export function loadBoard(boardId) {
  let raw;
  try {
    raw = localStorage.getItem(storageKey(boardId));
  } catch {
    return {};
  }
  if (!raw) return {};

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return {};
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) return {};

  const board = {};
  for (const [ideaId, entry] of Object.entries(parsed)) {
    if (!isValidEntry(entry)) continue;
    board[ideaId] = { x: entry.x, y: entry.y, collapsed: entry.collapsed === true };
  }
  return board;
}

// Writes the whole entry for one idea id, reading the board's current
// object and writing it back — never a long-lived in-memory copy flushed on
// an interval, which would let two tabs open on the same board silently
// overwrite one another. Entries for ids no longer on the board are left
// untouched here (see `loadBoard`'s caller in `src/pinboard.js` for why
// nothing ever prunes them): a note deleted, renamed, or dropped from one
// `rheo watch` build by an unrelated compile error must find its place again
// when it comes back, and an entry is a few dozen bytes against a corpus
// bounded by the size of the project.
export function saveCard(boardId, ideaId, entry) {
  try {
    const board = loadBoard(boardId);
    board[ideaId] = { x: entry.x, y: entry.y, collapsed: entry.collapsed === true };
    localStorage.setItem(storageKey(boardId), JSON.stringify(board));
  } catch {
    // A write that fails (quota, blocked storage, a throwing getter) leaves
    // the board unarranged on the next load rather than breaking this one.
  }
}
