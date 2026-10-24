// Query-string state primitives, so a stateful widget survives rheo's `watch`
// rebuild by mirroring its state into the URL rather than keeping it only in a
// closure. A filtered view becomes a copyable link as a side effect.
//
// THAT REBUILD IS NO LONGER ALWAYS A NAVIGATION, which is why `resetKeys`
// exists below. rheo 0.6.4 morphs the new HTML into the live DOM on a content
// edit rather than reloading the page: a reload took the whole JS heap with it,
// a morph keeps it, so the module-level claim registry now outlives the widgets
// that filled it.
//
// Every function but `commit` takes and returns a plain STRING rather than
// reading `location`/`history` directly — the node suite here runs under
// linkedom, which provides no `history`, so a pure-string contract is what
// keeps this module testable at all. `commit` is the one function that
// touches the address bar, and it does so with `history.replaceState`, never
// `pushState`: `pushState` would stack one history entry per keystroke, and
// Back must keep leaving the page.

// key -> the element holding it, or `null` for an ownerless claim. A MAP rather
// than the Set this was, because a claim is now refused on the holder's
// liveness and not merely on its existence — see `claimKey`.
const claimedKeys = new Map();

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
//
// `owner` IS THE ELEMENT MAKING THE CLAIM, and passing it is what makes the
// claim survivable across a rheo morph. A claim is refused only by an owner
// that is STILL IN THE DOCUMENT, so the same widget re-wiring itself re-claims
// its own key, and a widget whose element the morph replaced leaves a claim
// that the replacement can take over. Two widgets genuinely sharing a key on
// one live page still collide, which is the mistake this exists to catch.
//
// SO THERE IS NOTHING TO RESET, AND NO ORDER TO GET RIGHT. The alternative was
// clearing the registry at the top of each rehydrate, which only works if the
// package that clears it is guaranteed to run before every package that claims
// — and hook order follows script order, which follows a consuming project's
// own import order. Neither package can see that, let alone control it, so a
// project that imported them the other way round would have silently lost its
// URL sync on the first edit. Liveness is a property each claim can answer by
// itself.
//
// `owner` STAYS OPTIONAL because this is published API. An ownerless claim
// keeps the original write-once behaviour exactly: `undefined` is never `null`
// and reports no `isConnected`, so a repeat is refused the way it always was.
export function claimKey(key, owner) {
  const held = claimedKeys.get(key);
  if (held !== undefined && held !== owner && held?.isConnected !== false) {
    console.warn(`@rookery/search: "${key}" is already synced to the URL by another widget — this one will not sync.`);
    return false;
  }
  claimedKeys.set(key, owner ?? null);
  return true;
}

// DROPS EVERY CLAIM. Not needed by the rehydrate path — see `claimKey` on why
// liveness replaced a reset — and kept because a test suite sharing one module
// instance across cases needs a way back to a clean registry.
export function resetKeys() {
  claimedKeys.clear();
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
