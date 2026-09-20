---
id: rk-forward-sync-through-todo-table-and-6f60e9ab
short-id: 6f
title: 'Forward sync: through todo-table and today-panel'
priority: 3
labels:
- type:feature
- feat-url-state
deps:
- blocked-by:rk-sync-panel-query-and-pills-to-the-url-386ad1b3
closed: true
---
Forward a `sync:` key through `#todo-table` and `#today-panel` to the `#panel`
underneath, so a todo view's filter box and pressed pills survive a reload and ride
in a copyable URL. Pure Typst pass-through — no JavaScript in this bird.

## Why it is only forwarding

`#todo-table` is `#panel` with the todo model's facets derived on top: it imports
`@rookery/search:0.1.0`'s `panel` and calls it at the end of its own body
(`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`, the `panel(` call around
line 496, forwarding `visible:`, `placeholder:`, `noun:`, `empty:`, `haystack:` and
`render:` verbatim near lines 533-538). This is the one cross-package edge in the
family, and `/home/lox/code/_fcl/rookery/CLAUDE.md` explains at lines 26-31 why it
exists and why it is confined to this file. At runtime a `#todo-table` is therefore
wired by `wirePanel` in `search/0.1.0/src/panel.js` — the same script, the same
state model — so the URL syncing is already done once `sync:` reaches that call.

`#today-panel` in `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ` is the
same story one level up: it narrows the rows to the day's selection and then
forwards `#todo-table`'s own knobs unchanged — same names, same defaults, same
meaning, as its own comment at lines 94-97 says — in the `todo-table(` call at
lines 125-155.

## What is already in the tree — do not re-implement

- `@rookery/search`'s `#panel` takes `sync: none`. Set, it emits
  `data-panel-sync="<key>"` on the panel wrapper; unset, it emits nothing and every
  existing caller is byte-identical.
- The key must be a non-empty string of lowercase letters, digits and hyphens;
  `#panel` asserts that itself and panics naming the bad value, so this bird adds
  no validation of its own.
- `panel.js` reads that attribute, rehydrates the filter box from `<key>.q` and the
  pressed facet pills from repeated `<key>.<field>` params, and writes them back
  with `history.replaceState`. Nothing about that needs to know it is looking at
  todos.
- `#panel` panics if a synced panel's `facets:` contains `"q"` or `"t"`, which are
  reserved inside a key's namespace. `#todo-table`'s facets default to
  `("epic", "tag", "state", "priority")`, so the default path cannot trip it.

## Steps

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`, add `sync: none` to
   `#todo-table`'s signature (the `#let todo-table(` block begins around line 136).
   Put it with the other chrome arguments that are forwarded verbatim — `visible:`,
   `placeholder:`, `noun:`, `empty:`, `haystack:` — so the parameter list and the
   forwarding block read in the same order.

   Document it in this file's register, per `/home/lox/code/_fcl/rookery/CLAUDE.md`,
   "Comment style": present tense, describe the current shape, comment the
   non-obvious. Say what the params look like for THIS widget specifically —
   `<key>.q` is the filter box and `<key>.epic` / `<key>.tag` / `<key>.state` /
   `<key>.priority` are the four pill groups, one repeated param per pressed value
   — that `none` means the view carries no URL state, and that the key must be
   unique on the page.

2. In the same file's `panel(` call, forward it: `sync: sync,` beside the existing
   `visible: visible`, `placeholder: placeholder`, `noun: noun`, `empty: empty`
   lines. Nothing else in that call changes — in particular do not touch the
   `facets:`, `multi:`, `union:` or `facet-rows:` arguments, whose derivations and
   the reasoning behind them are the substance of that call.

3. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ`, add `sync: none` to
   `#today-panel`'s signature (the `#let today-panel(` block begins around line 45).
   It belongs in the block of `#todo-table` knobs forwarded unchanged, which runs
   from `facets:` down through `render:` around lines 98-118 — the comment
   introducing that block is at lines 94-97 and says these are the same names, same
   defaults, same meaning. Keep it consistent with that: name it `sync`, default it
   to `none`, and let the one-line comment defer to `table.typ` the way its
   neighbours do rather than restating the param shape a second time.

4. In the same file's `todo-table(` call at lines 125-155, forward `sync: sync,`
   alongside the existing `visible: visible`, `placeholder: placeholder`,
   `noun: noun`, `empty: empty`, `haystack: haystack`, `render: render` lines.

## Do NOT

- Do NOT touch any `.js` file. `#todo-table` ships no browser half of its own — it
  is wired by `@rookery/search`'s `panel.js` — so a JS edit here means the design
  above was misread.
- Do NOT touch `/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ` or
  `src/todo-search.js`. `#todos-search` is a separate widget with its own bird.
- Do NOT touch anything under `/home/lox/code/_fcl/rookery/search/`.
- Do NOT touch `/home/lox/code/_fcl/rookery/todos/0.1.0/typst.toml` — no new asset
  is introduced here.
- Do NOT touch `todos/0.1.0/readme.md`; a later bird documents this package's half
  of the feature in one pass, so that file has a single writer.
- Do NOT add a default key. `none` must stay the default in both functions, so that
  every existing consuming site is unchanged.
- Do NOT change `facets:`, `pill-rows:`, the graph/`corpus:` handling, or the
  `filter: r => true` that `#today-panel` passes to `#todo-table` (its comment at
  lines 137-142 explains why that must stay).

## VERIFY

From `/home/lox/code/_fcl/rookery/todos/0.1.0`:

```sh
just test
just test-js
just check
```

- `just test` runs the Typst unit fixture
  (`typst compile --features html --root . --format pdf test/units.typ /dev/null`)
  plus `./test/panics.sh`. A failing `assert` fails the compile with a line number,
  so a green run is the pass.
- `just test-js` runs `node --test test/*.test.mjs`, untouched by this bird and the
  proof it stayed untouched.
- `just check` runs `pnpm install && pnpm run build`, then `rheo compile demo/rheo`
  and `./demo/rheo/check.sh`, which asserts on the BUILT markup. This is the
  command that proves the forwarding compiles inside a real rheo project.

Then pin the forward itself. Add `sync: "todos"` to a `#todo-table` call and
`sync: "today"` to a `#today-panel` call in a page under `demo/rheo/`'s content,
re-run `just check`, and confirm:

```sh
grep -rn 'data-panel-sync' demo/rheo/build/ | head
```

prints `data-panel-sync="todos"` and `data-panel-sync="today"` on the panel
wrappers. Remove the two temporary arguments again before finishing — unless
`demo/rheo` is the natural place to demonstrate the feature permanently, in which
case keep them and say so, but do not leave a half-demo behind.