---
id: rk-sync-todos-search-facets-to-the-url-b4312fc7
short-id: b4
title: 'Sync #todos-search facets to the URL'
priority: 2
labels:
- type:feature
- feat-url-state
deps:
- blocked-by:rk-add-urlstate-js-url-param-state-2afe3277
closed: false
---
Give `#todos-search` an opt-in `sync:` key, so its filter box and its pressed
`ready`/`blocked`/type pills survive a reload and ride in a copyable URL. This
widget has its own browser half, so unlike `#todo-table` it needs both sides.

## Why this widget is separate from the panel work

`#todos-search` is not built on `@rookery/search`'s `#panel`. It is this package's
own widget with its own script —
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ` for the markup,
`src/todo-search.js` for the behaviour — and its state is a plain object of two
Sets at `todo-search.js:128`:

```js
const facets = { status: new Set(), type: new Set() };
```

mirrored only onto `aria-pressed` at lines 197-203. A `rheo watch` reload
(`location.reload()`) empties the box and un-presses every pill.

It already reaches `@rookery/search` WITHOUT importing it, by feature-detecting the
global at lines 87-96:

```js
const tq = globalThis.RookerySearch;
const hasTagQuery = Boolean(tq && tq.splitQuery && tq.evalTagQuery && tq.fold);
```

That is the pattern this bird extends, and it must stay a feature detection rather
than becoming a second import edge. `/home/lox/code/_fcl/rookery/CLAUDE.md:26-31`
states the rule: the one `todos` → `search` import lives in `table.typ` alone, and
`#todos-search` still reaches for nothing in that package.

## The helper this consumes, and how

`@rookery/search`'s bundle exports these on `globalThis.RookerySearch` (source of
truth: `/home/lox/code/_fcl/rookery/search/0.1.0/src/urlstate.js`, published on the
global in `search/0.1.0/src/search.js`):

- `readSync(key, search)` → `{ q, values }`, `q` from the `<key>.q` param (`""` when
  absent), `values` a `Map<field, Set<value>>` from every other `<key>.<field>`
  param, repeated params collected into the Set.
- `writeSync(key, { q, values }, search)` → a new query string, deleting this key's
  params and re-appending, leaving every param outside the key untouched, and
  writing nothing for an empty `q` or an empty set.
- `commit(search)` → `history.replaceState` in place, preserving `location.hash`.
- `claimKey(key)` → `false` plus one `console.warn` on a repeated key.
- `debounce(fn, ms = 200)`.

**All five or none**, checked once at wire time, exactly as `hasTagQuery` is and for
the reason its comment at lines 91-94 gives: a partial surface is a version skew and
must degrade the way an absent one does rather than half-work. With the global
absent — a page carrying `@rookery/todos` and not `@rookery/search` — the widget
must behave precisely as it does today.

## Decisions already made — do not re-derive

- **Param shape**: `<key>.q` for the box, `<key>.status` and `<key>.type` for the
  two pill facets, one repeated param per pressed value. Same namespacing every
  other synced widget in the family uses.
- **A URL value with no matching pill on the page is IGNORED.** A type pill only
  exists when some listed row carries that type (`search.typ:148-150`), so a stale
  link naming a vanished type must not filter every row away with nothing on
  screen to press.
- **Debounced on typing, immediate on a pill and on Escape.**
- **Read `location.search` fresh per write**, never captured — another synced widget
  on the page writes between two of these.
- **`history.replaceState`, never `pushState`.** Back keeps leaving the page.

## Steps

### 1. `src/search.typ` — the key and the attribute

In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ`:

- add `sync: none` to `#todos-search`'s signature at lines 130-135, after `closed:`.
  Document it in this file's register (see
  `/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style"): what the params look
  like — `<key>.q`, `<key>.status`, `<key>.type` — and that `none` means no URL
  state at all.
- validate it in the body, near the existing `assert-acyclic(graph)` at line 137:

  ```typ
  if sync != none {
    assert(
      type(sync) == str and sync.len() > 0 and sync.match(regex("^[a-z0-9-]+$")) != none,
      message: "@rookery/todos: `sync:` is the widget's URL-parameter namespace, so it "
        + "must be a non-empty string of lowercase letters, digits and hyphens — got "
        + repr(sync) + ". A key carrying `.`, `&` or `=` would break out of its own "
        + "namespace in the query string.",
    )
  }
  ```

  Written out here rather than imported from `@rookery/search`: this file
  deliberately has no edge to that package (`CLAUDE.md:29-31`) and must not grow one
  for a validator. Say that in one comment line, the way `_fmt-day` in
  `search/0.1.0/src/filter-panel.typ` explains the same kind of duplication.
- emit the attribute on the container at line 170, conditionally, so a widget with
  no `sync:` is byte-identical to today:

  ```typ
  attrs: (
    (class: "todo-search", "data-todo-search-ready": "false")
      + if sync == none { (:) } else { ("data-todo-search-sync": sync) }
  ),
  ```

  Use whatever dictionary-building form compiles cleanly in this file — note the
  warning in `search/0.1.0/src/panel.typ` around lines 505-507 that `(..a, ..b)`
  with no named field is an ARRAY literal in Typst and spreading a dictionary into
  one is an error. Build by `+` or by `insert`, not by a bare spread pair.

### 2. `src/todo-search.js` — detect, rehydrate, persist

In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo-search.js`, inside `wire`
(which begins at line 81):

- beside the existing `tq`/`hasTagQuery` detection at lines 95-96, add:

  ```js
  const syncKey = container.getAttribute("data-todo-search-sync");
  const hasUrlState = Boolean(
    tq && tq.readSync && tq.writeSync && tq.commit && tq.claimKey && tq.debounce,
  );
  const syncing = Boolean(syncKey) && hasUrlState && tq.claimKey(syncKey);
  ```

  Keep the all-five-or-none comment shape its neighbour uses.

- after `apply` is defined (it ends at line 180), add the writer:

  ```js
  const persist = () => {
    if (!syncing) return;
    const values = new Map([
      ["status", facets.status],
      ["type", facets.type],
    ]);
    tq.commit(tq.writeSync(syncKey, { q: input.value, values }, location.search));
  };
  const persistSoon = syncing ? tq.debounce(persist) : () => {};
  ```

- wire it to the three existing state changes without disturbing them:
  - line 182, `input.addEventListener("input", apply)` — also call `persistSoon()`.
  - lines 183-189, the Escape handler — call `persist()` after `apply()`.
  - lines 191-206, the pill click handler — call `persist()` after the `apply()` at
    line 204.

- rehydrate just before `container.setAttribute("data-todo-search-ready", "true")`
  at line 208:

  ```js
  if (syncing) {
    const st = tq.readSync(syncKey, location.search);
    let restored = false;
    if (st.q) { input.value = st.q; restored = true; }
    for (const facet of ["status", "type"]) {
      for (const v of st.values.get(facet) ?? []) {
        const pill = pills.find(
          (p) =>
            p.getAttribute("data-todo-facet") === facet &&
            p.getAttribute("data-todo-value") === v,
        );
        if (!pill) continue;
        facets[facet].add(v);
        pill.setAttribute("aria-pressed", "true");
        restored = true;
      }
    }
    if (restored) apply();
  }
  ```

  `pills` is already collected at line 129, so reuse it rather than re-querying —
  and it sidesteps any need to escape a value into a CSS selector.

  **`apply()` only when something was restored**, and this matters: `wire` does NOT
  call `apply()` today (it ends at line 208 with the ready flag and nothing else),
  so the rows are left in the build-time priority order Typst sorted them into. An
  unconditional first `apply()` would change that path for every existing consumer.

### 3. `test/todo-search-sync.test.mjs`

New file beside the existing `test/layout.test.mjs` and `test/todo-search.test.mjs`
— read the latter first and copy its harness rather than inventing one; it already
wires `wire` over a DOM. Stub the address bar and the global explicitly:

```js
let captured = null;
globalThis.location = { pathname: "/todos.html", search: "", hash: "" };
globalThis.history = { replaceState: (_a, _b, url) => { captured = url; } };
```

`globalThis.RookerySearch` must be stubbed too, and the honest way is to import the
real functions from the sibling package's source —
`import { readSync, writeSync, commit, claimKey, debounce } from "../../../search/0.1.0/src/urlstate.js";`
— and assign an object holding them. THAT PATH IS A GUESS ABOUT THE TEST'S
LOCATION: verify it resolves from `todos/0.1.0/test/` before relying on it, and if
importing across packages is awkward here, hand-write a minimal stub of the five
functions in the test file instead and say so in a comment. Either is acceptable;
silently testing against a stub that disagrees with the real one is not.

Cover at least:
1. `location.search = "t.q=alpha"` before wiring leaves the input holding `alpha`
   and the list filtered on first paint.
2. `t.status=ready` presses that pill (`aria-pressed === "true"`) with no click
   dispatched, and filters the list.
3. `t.type=nonexistent` presses nothing and leaves every row visible.
4. A pill click puts `t.status=ready` in `captured`; a second click removes it.
5. Escape clears the box and drops `t.q` from `captured` immediately.
6. With `location.search = "tab=todos"`, a pill click keeps `tab=todos`.
7. No `data-todo-search-sync` attribute: `captured` stays `null` through typing and
   a pill click, and — pin this explicitly — `apply()` is not called at wire time,
   so the rows stay in their build-time order.
8. `globalThis.RookerySearch` absent entirely: the widget still filters and still
   never calls `replaceState`.

## Do NOT

- Do NOT add `import ... from "@rookery/search"` to `src/search.typ`, and do NOT add
  a relative or package JS import of `search`'s modules to `src/todo-search.js`.
  The feature detection is the contract — see `CLAUDE.md:26-31`.
- Do NOT change `score` (lines 42-61), `passes` (lines 69-75) or the ranking and
  hiding rules inside `apply` (lines 131-180). The comment at lines 156-161 records
  a measured stylesheet dependency; leave it alone.
- Do NOT touch `src/table.typ` or `src/today.typ` — `#todo-table` and
  `#today-panel` get `sync:` in their own bird.
- Do NOT touch anything under `/home/lox/code/_fcl/rookery/search/`.
- Do NOT touch `src/todos.css` — no new rule is needed; the ready-flag gate at lines
  143-144 already covers the chrome.
- Do NOT touch `todos/0.1.0/readme.md`; a later bird documents this package's half of
  the feature so that file has a single writer.
- Do NOT call `apply()` unconditionally at wire time. See step 2.
- Do NOT edit `dist/`. It is a gitignored build artifact.

## VERIFY

From `/home/lox/code/_fcl/rookery/todos/0.1.0`:

```sh
just test
just test-js
just check
```

- `just test` — the Typst unit fixture plus `./test/panics.sh`; a failing `assert`
  fails the compile with a line number.
- `just test-js` — `node --test test/*.test.mjs`, green including the new file AND
  the pre-existing `todo-search.test.mjs`, which is this widget's regression net.
- `just check` — `pnpm install && pnpm run build`, then `rheo compile demo/rheo` and
  `./demo/rheo/check.sh`, which asserts on the BUILT markup and specifically on the
  `.todo-search-row[hidden]` rule.

Then pin the markup: add `sync: "t"` to a `#todos-search` call in a page under
`demo/rheo/`'s content, re-run `just check`, and confirm

```sh
grep -rn 'data-todo-search-sync' demo/rheo/build/ | head
```

prints `data-todo-search-sync="t"` on the `.todo-search` container. Remove the
temporary argument again before finishing.