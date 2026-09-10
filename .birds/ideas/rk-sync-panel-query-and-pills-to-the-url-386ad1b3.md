---
id: rk-sync-panel-query-and-pills-to-the-url-386ad1b3
short-id: '38'
title: 'Sync #panel query and pills to the URL'
priority: 4
labels:
- type:feature
- feat-url-state
deps:
- blocked-by:rk-add-urlstate-js-url-param-state-2afe3277
closed: false
---
Give `#panel` an opt-in `sync:` key that mirrors its filter box and its pressed
pills into the query string and rehydrates them from there on load. This is the
bird the whole feature exists for; everything else forwards to it.

## Why this exists

`rheo watch` reloads with a hard `location.reload()`, and `wirePanel` keeps all of
its state in closures — the `facets` Map and the `pressed` Set at
`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js:146-167`, mirrored only onto
`aria-pressed` — so every rebuild empties the filter box and un-presses every pill.
Putting that state in the URL is what survives a reload, and it makes a filtered
view a copyable link as a side effect.

## Prerequisite already in the tree

`/home/lox/code/_fcl/rookery/search/0.1.0/src/urlstate.js` exists and is exported
from `src/search.js` and listed in `typst.toml`'s `[tool.rheo.source.html]`
`js_scripts`. Its surface, which this bird consumes and must not change:

- `readSync(key, search)` → `{ q, values }` where `q` is the `<key>.q` param (`""`
  when absent) and `values` is a `Map<field, Set<value>>` built from every other
  `<key>.<field>` param, repeated params collected into the Set.
- `writeSync(key, { q, values }, search)` → a new query string, merging into
  `search`: it deletes this key's params, writes `<key>.q` only when `q` is
  non-empty, appends one `<key>.<field>` param per value, and leaves every param
  outside the key's namespace untouched.
- `commit(search)` → `history.replaceState` in place, preserving `location.hash`;
  a no-op where `location`/`history` are absent.
- `claimKey(key)` → `false` plus one `console.warn` when a key is claimed twice on
  one page.
- `debounce(fn, ms = 200)`.

## Decisions already made — do not re-derive

- **Opt-in, caller-named key.** No `sync:` means emit nothing and read nothing, so
  every existing consumer of this package is byte-identical and behaviourally
  unchanged. Do not invent a default key from document order.
- **`q` and `t` are RESERVED field names** inside a key's namespace: `<key>.q` is
  the text input and `<key>.t` is the tag-mode pill set. A `#panel` whose `facets:`
  contains `"q"` or `"t"` while `sync:` is set must panic in Typst (step 2), rather
  than silently fighting the text box for the same param.
- **A URL value with no matching pill on the page is IGNORED, not applied.** A
  stale link naming a pill that no longer exists would otherwise filter every row
  away with nothing on screen to explain it or press to undo it.
- **Rehydrate before the first `apply()`.** `wirePanel` already ends with
  `container.setAttribute("data-panel-ready", "true")` then `apply()` at
  `panel.js:332-333`; restoring state just above that means one render, not two,
  and no flash of the unfiltered list.
- **Writes: debounced on typing, immediate on a pill.** A `replaceState` per
  keystroke is what the debounce is for; a pill press is one deliberate act and
  should land in the URL at once.
- **Read `location.search` fresh on every write.** Two synced widgets on one page
  each own their own namespace, and a stale captured query string would drop the
  other's params.

## Steps

### 1. `src/panel.typ` — a key validator

In `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ`, add a private helper
beside the existing `_attr` (lines 46-59) and `_multi-attr` (lines 73-96):

```typ
#let _sync-key(key) = {
  assert(
    type(key) == str and key.len() > 0 and key.match(regex("^[a-z0-9-]+$")) != none,
    message: "@rookery/search: `sync:` is the widget's URL-parameter namespace, so it "
      + "must be a non-empty string of lowercase letters, digits and hyphens — got "
      + repr(key) + ". A key carrying `.`, `&` or `=` would break out of its own "
      + "namespace in the query string.",
  )
  key
}
```

It must be exported from this file's scope in whatever way `filter-panel.typ`
already reaches `_panel-shell` — that file imports from `panel.typ` (its line 27
region), so a top-level `#let` here is reachable. Do not add it to the package's
public surface in `src/lib.typ`.

### 2. `src/panel.typ` — `sync:` on `_panel-shell`

`_panel-shell`'s signature is at lines 139-150. Add `sync: none` to it.

In the wrapper element's attribute dictionary (lines 163-180), emit the attribute
between the existing `"data-panel-ready": "false"` at line 175 and the
`..attrs-after` spread at line 176:

```typ
..if sync == none { (:) } else { ("data-panel-sync": sync) },
```

Conditional so a panel with no `sync:` emits exactly the bytes it does today. The
header comment at lines 129-133 explains that this function has two attribute slots
because the two widgets state their declarations on opposite sides of the ready
flag and Typst emits attributes in the order given — respect that and add the
attribute in this one place rather than threading it through `attrs`/`attrs-after`.

### 3. `src/panel.typ` — `sync:` on `#panel`

`#panel`'s signature runs lines 209-333. Add a `sync: none` parameter, documented
in this file's register — a comment block saying what it is (this widget's URL
parameter namespace), what the params look like (`<key>.q` for the text box,
`<key>.<field>` per facet, repeated once per pressed value), that `none` means the
widget carries no URL state at all, and that the key must be unique on the page.

In the body, before the `_panel-shell(` call at line 461, add the reserved-name
check:

```typ
if sync != none {
  let _ = _sync-key(sync)
  for f in facets {
    assert(
      f not in ("q", "t"),
      message: "@rookery/search: a synced panel reserves `" + f + "` — `<key>.q` is "
        + "the filter box and `<key>.t` is the tag-pill set. Rename the projected "
        + "field, or drop `sync:`.",
    )
  }
}
```

Then pass `sync: sync` in the `_panel-shell(` call, alongside the existing
`visible:`/`placeholder:`/`noun:`/`empty:` forwards at lines 521-524.

### 4. `src/panel.js` — read the key and claim it

In `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js`:

- add `readSync`, `writeSync`, `commit`, `claimKey`, `debounce` to the imports at
  the top of the file (the existing imports of `./score.js`, `./tagquery.js` and
  `./text.js` are at lines 38-45).
- inside `wirePanel` (which begins at line 130), after `pillMatch` is read at line
  142, add:

  ```js
  const syncKey = container.dataset.panelSync;
  const syncing = syncKey !== undefined && syncKey !== "" && claimKey(syncKey);
  ```

  `claimKey` is what emits the duplicate-key warning; a duplicate simply does not
  sync, and the panel otherwise works exactly as it does now.

### 5. `src/panel.js` — persist

Still inside `wirePanel`, after `apply` is defined (it ends at line 301), add a
writer:

```js
const persist = () => {
  if (!syncing) return;
  const values = new Map();
  if (tagMode) values.set("t", pressed);
  else for (const [field, set] of facets) values.set(field, set);
  commit(writeSync(syncKey, { q: input.value, values }, location.search));
};
const persistSoon = debounce(persist);
```

`location.search` is read HERE, per call, not captured — a second synced widget on
the page writes between two of these and a captured string would drop its params.

Wire it to the three existing state changes without disturbing them:

- line 303, `input.addEventListener("input", apply)` — add `persistSoon()` so both
  run. Keep `apply` synchronous and unconditional; only the URL write is delayed.
- lines 304-310, the `keydown` handler that clears the box on Escape — call
  `persist()` (not the debounced form) after `apply()`, so a cleared box drops its
  param at once.
- lines 315-330, the pill click handler — call `persist()` after the existing
  `apply()` at line 328.

### 6. `src/panel.js` — rehydrate

Between the pill-click loop (ending line 330) and
`container.setAttribute("data-panel-ready", "true")` at line 332, restore state
from the URL:

```js
if (syncing) {
  const st = readSync(syncKey, location.search);
  if (st.q) input.value = st.q;
  if (tagMode) {
    for (const v of st.values.get("t") ?? []) {
      const pill = container.querySelector(`.panel-pill[data-panel-tag="${CSS.escape(v)}"]`);
      if (!pill) continue;
      pressed.add(v);
      pill.setAttribute("aria-pressed", "true");
    }
  } else {
    for (const [field, wanted] of st.values) {
      const set = facets.get(field);
      if (!set) continue;
      for (const v of wanted) {
        const pill = container.querySelector(
          `.panel-pill[data-panel-facet="${CSS.escape(field)}"][data-panel-value="${CSS.escape(v)}"]`,
        );
        if (!pill) continue;
        set.add(v);
        pill.setAttribute("aria-pressed", "true");
      }
    }
  }
}
```

`CSS.escape` may be absent under linkedom — VERIFY THIS RATHER THAN ASSUMING. If it
is, add a tiny local fallback (`const esc = (s) => (globalThis.CSS?.escape ? CSS.escape(s) : s.replace(/["\\]/g, "\\$&"))`)
and use that instead; do not drop the escaping, and do not build the selector by
raw interpolation.

Skipping a value with no pill is deliberate, not defensive tidiness — see the
decisions above. `pressed`/`facets` must not learn a value the reader cannot see or
un-press.

The existing `apply()` at line 333 then renders the restored state as the first
paint. Do not add a second `apply()`.

### 7. `test/panelsync.test.mjs`

New file, in the shape of `test/panelinput.test.mjs` — that file is the model to
copy: `parseHTML` from linkedom, `globalThis.document = document`, then
`wirePanel(document.querySelector(".panel"), 0)`, with helpers that dispatch a
real `input` event via `new document.defaultView.Event("input")`.

Because `urlstate.js`'s `commit` needs an address bar and linkedom may not supply
one, stub it explicitly in the test — the suite already assigns `globalThis.document`
by hand, so this is the same move:

```js
let captured = null;
globalThis.location = { pathname: "/index.html", search: "", hash: "" };
globalThis.history = { replaceState: (_a, _b, url) => { captured = url; } };
```

Set `location.search` before wiring to test rehydration, and read `captured` after
an interaction to test persistence. Reset both between tests.

Fixtures: a facet panel carrying `data-panel-sync="todos"`, a
`.panel-pill-group[data-panel-group="state"]` with two
`.panel-pill[data-panel-facet="state"][data-panel-value="..."]` buttons and rows
carrying `data-state`; and a tag panel with `data-panel-mode="tags"`,
`data-panel-sync="ideas"` and `.panel-pill[data-panel-tag="..."]`. Cover:

1. Rehydration: `location.search = "todos.q=alpha"` before wiring leaves the input
   holding `alpha` and only matching rows unhidden on first paint.
2. Rehydration of pills: `todos.state=ready` presses that pill
   (`aria-pressed === "true"`) and filters the list, with no click dispatched.
3. A stale value: `todos.state=nonexistent` presses nothing, adds nothing to the
   filter, and leaves every row visible.
4. Persistence on a pill press: clicking a pill puts `todos.state=<value>` in
   `captured`; clicking it again removes it and leaves no `todos.state` param.
5. Persistence of the box: typing then flushing the debounce (either
   `await new Promise((r) => setTimeout(r, 250))` or fake timers) puts `todos.q=`
   in `captured`; Escape clears it immediately with no wait.
6. Merging: with `location.search = "tab=todos&other.q=x"`, pressing a pill keeps
   both of those params in `captured`.
7. A panel with NO `data-panel-sync` never calls `replaceState` — `captured` stays
   `null` through typing and a pill press.
8. Tag mode round-trips through `ideas.t=<tag>`.

## Do NOT

- Do NOT change `apply` (lines 224-301), `passesFacets` (lines 83-97), `passesTags`
  (lines 120-128) or `accepts` (lines 57-61). The filtering rules are not in scope
  and their tests pin them.
- Do NOT touch `src/filter-panel.typ` — `sync:` reaches `#filter-panel` in its own
  bird. The tag-mode JS path here must nonetheless be complete, because that bird
  adds no JavaScript.
- Do NOT touch anything under `todos/`.
- Do NOT touch `src/urlstate.js`, `src/search.js` or `typst.toml`. The primitives
  and their registration are already in place; needing to change them means the
  contract above was misread.
- Do NOT touch `search/0.1.0/readme.md` — one later bird documents the whole
  feature, so that file has a single writer.
- Do NOT use `pushState`, `location.hash`, `localStorage` or `sessionStorage`.
- Do NOT sync scroll position. `apply` deliberately resets `list.scrollTop = 0` at
  line 294 on every render and the two rules would contradict.
- Do NOT edit `dist/`. It is a gitignored build artifact.

## VERIFY

From `/home/lox/code/_fcl/rookery/search/0.1.0`:

```sh
just test
just parity
just build
```

All three green, `just test` including the new `panelsync.test.mjs` and every
pre-existing file — `panelinput.test.mjs`, `panelmulti.test.mjs`,
`panelquery.test.mjs`, `panelunion.test.mjs` and `filterpanel.test.mjs` all wire
`wirePanel` and are the regression net for steps 4-6.

Then prove the Typst half through this package's own rheo fixture, which resolves
`@rookery/*` out of this tree via `[packages.rookery] path = "../../../.."` in
`demo/rheo/rheo.toml` (so no package-cache symlink is needed). Note that this
package's `Justfile` has no `check` recipe — run the two commands directly:

```sh
rheo compile demo/rheo
./demo/rheo/check.sh
```

Both must succeed, proving a page full of `#panel`/`#filter-panel` calls carrying
NO `sync:` still compiles and still renders. Then, to pin the new asserts, add two
temporary calls to a page under `demo/rheo/content/`: one `#panel(.., sync: "todos")`,
which must compile and must put `data-panel-sync="todos"` on the wrapper in
`demo/rheo/build/`, and one `#panel(.., sync: "Bad Key")`, which must fail the
compile with the message from step 1 naming `"Bad Key"`. Remove both temporary
calls again before finishing — the fixture is not the place to leave them.