---
id: rk-document-sync-in-todos-readme-2b7e1228
short-id: 2b
title: 'Document sync: in todos'' readme'
priority: 2
labels:
- type:task
- docs-url-state
deps:
- blocked-by:rk-forward-sync-through-todo-table-and-6f60e9ab
- blocked-by:rk-sync-todos-search-facets-to-the-url-b4312fc7
closed: false
---
Document `sync:` in `@rookery/todos`' readme — on `#todos-search`, `#todo-table`
and `#today-panel` — so a consuming site can find the feature from the package it
is actually calling. Documentation only, no code changes.

## Why this is a bird of its own

`/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md` is 811 lines and is this
package's only API documentation — there is no docs site. Two separate birds added
`sync:` to this package's three views, and if each had written its own readme
section they would have conflicted on landing in one file. The code birds
deliberately left the readme alone; this writes it in one pass.

## What is already in the tree, and must be described exactly as it is

Read the implementation first — the readme has to match it, not this bird's summary:

- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ` — `sync:` on
  `#todos-search`, emitting `data-todo-search-sync` on the `.todo-search` container.
- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo-search.js` — its rehydrate and
  persist paths inside `wire`, gated on a feature detection of
  `globalThis.RookerySearch`.
- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` — `sync:` on
  `#todo-table`, forwarded to `@rookery/search`'s `#panel`.
- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ` — `sync:` on
  `#today-panel`, forwarded to `#todo-table`.

The full explanation of the parameter shape, the reserved names, the key charset and
the one-key-per-page rule lives in `@rookery/search`'s readme, under its
`sync:` section. This readme should state what a todos caller needs and POINT there
for the rest, rather than duplicating it — that is how this readme already treats
the `tags:` language (`### A `tags:` expression, when `@rookery/search` is installed`,
line 295).

## Steps

1. `#todos-search`. Add a subsection under the existing
   `## Filtering todos in the page: `#todos-search`` chapter (line 259), placed
   after `### A `tags:` expression, when `@rookery/search` is installed` (line 295)
   and before `### Without JavaScript` (line 319). Cover:
   - what it does: `sync: "t"` puts the filter box in `?t.q=`, the pressed
     `ready`/`blocked` pills in repeated `?t.status=` parameters and the pressed
     type pills in `?t.type=`, so a reload or a shared link restores the view.
   - that it defaults to `none` and a widget without it is unchanged.
   - **that it needs `@rookery/search` on the page**, detected at wire time exactly
     as the `tags:` language is, and degrades to doing nothing when that package is
     absent — the sibling subsection at line 295 already sets up this framing, so
     match it rather than re-arguing it. Say plainly that the URL primitives live in
     that package and this one reaches them through the global rather than by
     importing, and why: this file has no import edge to `@rookery/search`.
   - a worked call, and the resulting URL.
   - a pointer to `@rookery/search`'s readme for the parameter shape, the reserved
     `q` name, the key charset and the one-key-per-page warning.

2. `#todo-table` and `#today-panel`. Add `sync:` to the argument documentation in
   the `## Grouped pills: `#todo-table`` chapter (line 333), with the parameter
   names those two views actually produce: `<key>.q` for the box and `<key>.epic`,
   `<key>.tag`, `<key>.state`, `<key>.priority` for the four default pill groups.
   Note that these views forward straight to `@rookery/search`'s `#panel`, so its
   readme is the reference, and that `#today-panel` takes the same argument with the
   same meaning — that chapter already documents `#today-panel` as taking
   `#todo-table`'s knobs unchanged, so extend that list rather than opening a new
   chapter.

3. Check whether `## Requirements` (line 793) needs a line. It states what this
   package needs; `sync:` on `#todos-search` adds a soft dependency on
   `@rookery/search` being present for one feature. If that section already says
   something equivalent for the `tags:` language, extend that sentence instead of
   adding a second one.

## Do NOT

- Do NOT change any `.typ`, `.js`, `.css` or `.toml` file. If the readme cannot be
  written truthfully without a code change, stop and say so rather than making one.
- Do NOT touch `search/0.1.0/readme.md` — that package documents its own half in a
  separate bird, and the two must not both grow a full copy of the parameter-shape
  explanation.
- Do NOT restate the whole `sync:` contract here. Point at `@rookery/search`'s
  readme for it.
- Do NOT write a changelog entry or a "what changed" passage.
  `/home/lox/code/_fcl/rookery/CLAUDE.md`'s comment-style section — describe the
  present, not how it got that way — holds for prose here too. Note that this
  readme does carry dated `## 0.1.0` chapters; do not add one, and do not fold this
  feature into the existing one.
- Do NOT document `#window` fold state or scroll-position syncing. Neither exists.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0
grep -n '^#\{1,3\} ' readme.md
```

The new `#todos-search` subsection must sit inside the chapter beginning at
`## Filtering todos in the page: `#todos-search``, between the `tags:` subsection
and `### Without JavaScript`.

Then check every claim against the code, not against this bird:

```sh
grep -n 'sync' src/search.typ src/table.typ src/today.typ
grep -n 'searchSync\|todo-search-sync\|readSync\|writeSync' src/todo-search.js
```

Every parameter name, attribute name and facet name in the readme must be spelled
the way those outputs spell it — in particular the facet names in step 2 must match
`#todo-table`'s actual `facets:` default.

Finally:

```sh
just test
just test-js
```

must still pass — nothing here should touch either, and a failure means a code file
was edited by accident.