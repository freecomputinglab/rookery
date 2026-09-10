---
id: rk-take-sync-on-filter-panel-6b93790a
short-id: 6b
title: 'Take sync: on #filter-panel'
priority: 3
labels:
- type:feature
- feat-url-state
deps:
- blocked-by:rk-sync-panel-query-and-pills-to-the-url-386ad1b3
closed: true
---
Give `#filter-panel` the same opt-in `sync:` key `#panel` has, so its filter box
and its pressed tag pills survive a reload and ride in a copyable URL. Typst only:
the JavaScript that does the work already exists.

## Why this is small

`#filter-panel` and `#panel` share their chrome (`_panel-shell`) and share their
browser half (`wirePanel` in
`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js`, which branches on
`data-panel-mode="tags"` at line 140 and otherwise treats the two identically). A
prior bird added `sync:` to `_panel-shell` — which is where the
`data-panel-sync` attribute is emitted — and implemented BOTH the facet path and
the tag path in `panel.js`, including reading and writing `<key>.t` for the pressed
tag set. So this widget needs one parameter and one forward, and no JavaScript at
all.

## What is already in the tree — do not re-derive or re-implement

- `_panel-shell` in `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ` (its
  signature is the `#let _panel-shell(` block near line 139) takes `sync: none` and
  emits `data-panel-sync="<key>"` on the wrapper `<div>` when it is set, and nothing
  when it is not.
- `_sync-key(key)` in the same file asserts the key is a non-empty string matching
  `^[a-z0-9-]+$` and panics with a message naming the bad value otherwise.
- `filter-panel.typ` already does `#import "panel.typ": *` (near its line 27), so
  both are in scope here with no new import.
- `panel.js`, in tag mode, writes the pressed tags as repeated `<key>.t` params and
  restores them on load, pressing only pills that exist on the page.

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/filter-panel.typ`, add a
   `sync: none` parameter to `#filter-panel`'s signature. The signature is the
   `#let filter-panel(` block; put the new parameter next to the other chrome
   arguments — `visible: 8`, `placeholder: "Filter"`, `noun: "ideas"`,
   `empty: [Nothing here.]` sit together just above `haystack:` — so the
   forwarding block below reads in the same order.

   Document it in this file's register, per
   `/home/lox/code/_fcl/rookery/CLAUDE.md`'s "Comment style" section: present
   tense, describe the current shape, comment the non-obvious. The two
   non-obvious facts are that a tag panel's pressed pills ride as REPEATED `<key>.t`
   params (one per tag, because a tag may contain a comma and there is no escaping
   rule) and that `none` means the widget carries no URL state at all, so every
   existing caller is unchanged.

2. In the same function's body, before the `_panel-shell(` call, validate the key:

   ```typ
   if sync != none { let _ = _sync-key(sync) }
   ```

   Put it beside the existing `assert` on `order` at the top of the body (the block
   whose message begins `"@rookery/search: #filter-panel's \`order\` must be"`), so
   every argument check on this function is in one place.

3. Forward it in the `_panel-shell(` call at the end of the function, alongside the
   existing `visible: visible`, `placeholder: placeholder`, `noun: noun`,
   `empty: empty` lines:

   ```typ
   sync: sync,
   ```

   Do NOT put it in the `attrs:` dictionary in that call — that slot holds
   `data-panel-mode` and `data-panel-pill-match`, and `_panel-shell` owns where
   `data-panel-sync` lands. The header comment on `_panel-shell` in `panel.typ`
   explains that the function has two attribute slots because the two widgets state
   their declarations on opposite sides of the ready flag and Typst emits attributes
   in the order given; adding this attribute a second way would rewrite the bytes of
   every page carrying this widget.

## Do NOT

- Do NOT touch any `.js` file. Nothing in the browser half needs to change; if it
  seems to, the tag path in `panel.js` was misread.
- Do NOT touch `src/panel.typ`, `src/urlstate.js`, `src/search.js` or `typst.toml`.
- Do NOT add a reserved-name check here. `#filter-panel` has no projected facet
  fields — its pills are bare tag names in one undifferentiated row — so the `q`/`t`
  collision `#panel` guards against cannot arise.
- Do NOT touch `search/0.1.0/readme.md`; one later bird documents the whole feature
  so that 1571-line file has a single writer.
- Do NOT touch anything under `todos/`.

## VERIFY

From `/home/lox/code/_fcl/rookery/search/0.1.0`:

```sh
just test
rheo compile demo/rheo
./demo/rheo/check.sh
```

`just test` must stay green — `test/filterpanel.test.mjs` is this widget's
regression net and this bird must not move it. `rheo compile demo/rheo` proves the
Typst change compiles inside a real rheo project; that fixture resolves
`@rookery/*` out of this tree via `[packages.rookery] path = "../../../.."` in
`demo/rheo/rheo.toml`, so no package-cache symlink is needed. (This package's
`Justfile` has no `check` recipe — run the two commands directly.)

Then pin the new parameter with a temporary call in a page under
`demo/rheo/content/`:

- `#filter-panel(.., sync: "ideas")` must compile, and the built page under
  `demo/rheo/build/` must carry `data-panel-sync="ideas"` on the same `<div>` that
  carries `data-panel-mode="tags"`.
- `#filter-panel(.., sync: "Bad.Key")` must fail the compile with the `sync:`
  message naming `"Bad.Key"`.

Remove both temporary calls before finishing.