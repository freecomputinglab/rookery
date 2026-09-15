// Query-string state primitives, so a stateful widget survives rheo's `watch`
// reload (a hard `location.reload()`, not a patch) by mirroring its state
// into the URL rather than keeping it only in a closure. A filtered view
// becomes a copyable link as a side effect.
//
// Every function but `commit` takes and returns a plain STRING rather than
// reading `location`/`history` directly — the node suite here runs under
// linkedom, which provides no `history`, so a pure-string contract is what
// keeps this module testable at all. `commit` is the one function that
// touches the address bar, and it does so with `history.replaceState`, never
// `pushState`: `pushState` would stack one history entry per keystroke, and
// Back must keep leaving the page.

const claimedKeys = new Set();

// `{ q, values }` for one widget's namespace: `<key>.q` as a scalar, every
// other `<key>.<field>` repeated-and-collected into a Set. A param outside
// the namespace (another widget's, or a plain site param) is invisible here.
export function readSync(key, search) {
  const params = new URLSearchParams(search);
  const qName = `${key}.q`;
  const q = params.get(qName) ?? "";
  const prefix = `${key}.`;
  const values = new Map();
  for (const [name, value] of params) {
    if (name === qName || !name.startsWith(prefix)) continue;
    const field = name.slice(prefix.length);
    if (!values.has(field)) values.set(field, new Set());
    values.get(field).add(value);
  }
  return { q, values };
}

// The inverse of `readSync`: replaces this key's whole namespace with the
// given state and leaves every other param, and their order, untouched. An
// empty `q` and an empty `values` therefore write nothing for this key.
export function writeSync(key, state, search) {
  const params = new URLSearchParams(search);
  const prefix = `${key}.`;
  for (const name of [...params.keys()]) {
    if (name.startsWith(prefix)) params.delete(name);
  }
  if ((state.q ?? "").trim() !== "") params.append(`${key}.q`, state.q);
  for (const [field, fieldValues] of state.values ?? []) {
    for (const value of fieldValues) params.append(`${key}.${field}`, value);
  }
  return params.toString();
}

// The scalar case a radio group needs: one bare `<key>` param, not a
// namespace.
export function readParam(key, search) {
  const params = new URLSearchParams(search);
  return params.has(key) ? params.get(key) : null;
}

export function writeParam(key, value, search) {
  const params = new URLSearchParams(search);
  if (value === null || value === undefined || value === "") {
    params.delete(key);
  } else {
    params.set(key, value);
  }
  return params.toString();
}

// The one function that touches the address bar. Guarded so importing this
// module under node — or calling it before a widget has anything to sync —
// is a no-op rather than a `ReferenceError`.
export function commit(search) {
  if (
    typeof location === "undefined" ||
    typeof history === "undefined" ||
    typeof history.replaceState !== "function"
  ) {
    return;
  }
  const qs = search === "" ? "" : `?${search}`;
  // Preserves `location.hash`: rheo's link rule mints in-page `#handle`
  // anchors, and dropping one would knock a reader off their scroll position.
  history.replaceState(null, "", location.pathname + qs + location.hash);
}

// One widget per key. Typst cannot see across two widget calls to assert
// this itself, so it is checked here: the first claim wins, every repeat
// warns and refuses, and the second widget simply never syncs.
export function claimKey(key) {
  if (claimedKeys.has(key)) {
    console.warn(`@rookery/search: "${key}" is already synced to the URL by another widget — this one will not sync.`);
    return false;
  }
  claimedKeys.add(key);
  return true;
}

// Runs `fn` at most once per quiet `ms`, so a caller can wire this straight
// to a keystroke without a `replaceState` per character.
export function debounce(fn, ms = 200) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}
