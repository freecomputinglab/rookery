---
id: rk-scaffold-rookery-pinboard-c9b5e67f
short-id: c9
title: Scaffold @rookery/pinboard
priority: 5
labels:
- feat-pinboard
deps: []
closed: false
---
A `@rookery/pinboard` is a browser view that lays every note in a rookery out as a
card on a two-dimensional board the author arranges by hand. The motivating use is
John McPhee's structural method: write each component of a piece on its own card,
put the cards where you can see them all at once, and move them around until a
sequence appears. What makes that work is that a card can be reduced to its title —
you are arranging labels, not reading prose — and that a card stays where you put it
while its contents go on changing underneath.

This bird files none of that behaviour. It files the PACKAGE and a board that renders,
so the three birds chained behind it (drag, collapse, pin-by-id) each add one
mechanism to a thing that already compiles and already appears on screen.

Touches: pinboard/0.1.0/typst.toml, pinboard/0.1.0/package.json, pinboard/0.1.0/vite.config.js, pinboard/0.1.0/Justfile, pinboard/0.1.0/.gitignore, pinboard/0.1.0/readme.md, pinboard/0.1.0/src/lib.typ, pinboard/0.1.0/src/board.typ, pinboard/0.1.0/src/pinboard.css, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/src/layout.js, pinboard/0.1.0/test/layout.test.mjs, pinboard/0.1.0/demo/rheo/rheo.toml, pinboard/0.1.0/demo/rheo/content/index.typ, CLAUDE.md

## What already exists, so you do not have to find it

Everything below was read out of this repo before this bird was written. Do not
re-derive it.

`@rookery/core` already hands you every note as plain data. `ideas()` is defined at
`/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ:273` and returns an array of
dictionaries, one per note, sorted by id. The fields are `id`, `name`, `title`,
`text`, `label`, `tags`, `body`, `href`, `page`, `created` and `tags-dict`. Two of
them matter here:

- **`id`** is the stable per-note string identifier. It is what a position gets
  pinned to in the bird chained behind this one, and it is what you put in the DOM.
- **`href`** is already the correct link to the note's own minted page, measured
  relative to the page the call happens on. Use it directly. Do NOT call
  `note-href()` yourself — it exists at `core/0.1.0/src/urls.typ:122`, but the row
  already carries its result, and calling it again just repeats the depth arithmetic.

`ideas()` MUST be called inside a `#context` block. It reads `_registry.final()`,
and the comment above its definition says so explicitly. A call outside `#context`
is a compile error.

The import spec for core, used verbatim everywhere else in this repo (for instance
`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ:55`), is:

```typ
#import "@rookery/core:0.1.0": ideas
```

This package follows **Pattern B** from the repo's own `CLAUDE.md` — feature-detect
rheo, never require it. A pinboard does not need the CURRENT FILE's own handle: it
needs the whole corpus, which `ideas()` already supplies whether rheo is present or
not. So take NO `ctx:` parameter, write NO assert, and write NO panic about rheo
being absent. `core` itself is the model — see its `_rheo-ctx()`/`_target()` at
`core/0.1.0/src/base.typ:20-26`.

The repo's CI needs no registration for a new package.
`.github/workflows/publish-packages.yml:88` enumerates packages with
`find . -name typst.toml`, and the root `/home/lox/code/_fcl/rookery/Justfile`'s
`build` recipe walks every nested `Justfile` at depth two or more. Creating the
directory is the whole of "registering" it.

## Steps

1. **Create `/home/lox/code/_fcl/rookery/pinboard/0.1.0/` and write `typst.toml`.**
   Mirror `todos/0.1.0/typst.toml` — this is a package that ships JavaScript, so it
   is a BUILT package with both a `[tool.rheo.html]` bundle and a
   `[tool.rheo.source.html]` list of unbundled modules. Write exactly:

   ```toml
   [package]
   name = "pinboard"
   version = "0.1.0"
   compiler = "0.15.0"
   entrypoint = "src/lib.typ"
   authors = ["The Free Computing Lab <https://freecomputinglab.ohrg.org>"]
   license = "MIT"
   description = "A board of draggable cards for arranging @rookery/core notes by hand"
   repository = "https://github.com/freecomputinglab/rookery"

   [tool.rheo]
   min_version = "0.6.2"

   [tool.rheo.html]
   js_scripts = "dist/lib.js"
   css_stylesheet = "src/pinboard.css"

   [tool.rheo.source.html]
   js_scripts = ["src/layout.js", "src/pinboard.js"]
   js_module = true
   ```

   `min_version = "0.6.2"` is the floor every package in this family declares, and
   it is not arbitrary: 0.6.2 is where rheo learned to locate a package fetched from
   a git ref, and `[tool.rheo.source.html]` is a key an older rheo reads straight
   past. `entrypoint` and `css_stylesheet` point at `src/`, not `dist/`, exactly as
   `todos/0.1.0/typst.toml` does — vite copies those files into `dist/`
   byte-identically, so the manifest names the originals. The
   `[tool.rheo.source.html]` list is DEPENDENCY-FIRST and is not a hint: rheo's
   asset copy acts on precisely this list rather than scanning import statements, so
   a module missing from it never lands in the output even though the browser's own
   module graph would have found it.

2. **Write the three build files**, copied in shape from `search/0.1.0`.

   `package.json`:

   ```json
   {
     "name": "rookery-pinboard",
     "version": "0.1.0",
     "type": "module",
     "scripts": {
       "build": "vite build",
       "test": "node --test test/*.test.mjs"
     },
     "packageManager": "pnpm@10.21.0",
     "devDependencies": {
       "linkedom": "^0.18.13",
       "vite": "^8.0.5"
     }
   }
   ```

   `vite.config.js`:

   ```js
   import { defineConfig } from "vite";

   export default defineConfig({
     build: {
       lib: {
         entry: "src/pinboard.js",
         formats: ["iife"],
         name: "RookeryPinboard",
         fileName: () => "lib.js",
       },
       outDir: "dist",
     },
   });
   ```

   `.gitignore`, matching `search/0.1.0/.gitignore` line for line:

   ```gitignore
   dist
   node_modules
   .direnv/
   build
   *.pdf
   ```

   No `flake.nix`. `todos/0.1.0` has none and takes `node`/`pnpm` from the repo
   root's flake, which direnv finds by walking up. Do the same.

3. **Write `Justfile`**, following `todos/0.1.0/Justfile`'s recipe names so the
   repo has one vocabulary:

   ```just
   default:
       @just --list

   # Bundles `src/` into `dist/lib.js`. `typst.toml` names `dist/` for the
   # release path, so this must run before a project compiling against a
   # released copy of this package sees an edit.
   build:
       pnpm install
       pnpm run build

   # The browser-only half: the flow layout in `src/layout.js`.
   test-js:
       node --test test/*.test.mjs

   # Asserts on the OUTPUT: a board compiles and every card carries the id
   # its position will later be pinned to.
   check: build
       rheo compile demo/rheo
       ./demo/rheo/check.sh
   ```

   Note the absence of a `test` recipe. `todos` has one because it has pure Typst
   helpers worth asserting on; this package's Typst half is one emitter function and
   is covered by `check`.

4. **Write `src/board.typ`**, the package's one real module. Define:

   ```typ
   #let pinboard(id: "default", notes: none) = { .. }
   ```

   - `id:` names THIS board. It becomes `data-pinboard="<id>"` on the container, and
     the bird chained behind this one uses it as the storage key for the board's
     layout. A project with two boards gives them two ids. Default `"default"`.
   - `notes:` is an optional explicit array of `ideas()` rows. When `none` (the
     default) the board shows every note. This is how a caller narrows the board
     without this package growing a query language of its own — `ideas(tags: "..")`
     already does that, and the caller passes the result in.

   The body is a `#context` block (mandatory, see above) emitting:

   ```typ
   html.elem("div", attrs: (class: "pinboard", "data-pinboard": id), { .. })
   ```

   and inside it one element per row:

   ```typ
   html.elem("article", attrs: (class: "pinboard-card", "data-pinboard-id": row.id), {
     html.elem("header", attrs: (class: "pinboard-card-handle"), link(row.href, row.title))
     html.elem("div", attrs: (class: "pinboard-card-body"), row.body)
   })
   ```

   `html.elem("tag", attrs: (..), body)` is the idiom this repo uses throughout —
   see `slipshow/0.1.0/src/slipshow.typ:497-503` for a container emitting a class
   and two `data-*` attributes together.

   When `row.href` is `none` — which happens under plain `typst compile` with no
   rheo, because no page was minted — render the title as plain content rather than
   a link, instead of passing `none` to `link()`.

   Emit cards in the order `ideas()` returns them, which is sorted by id and
   therefore stable across builds. A stable order is what makes the flow layout in
   step 6 deterministic.

5. **Write `src/lib.typ`** as a manifest and nothing else, matching
   `core/0.1.0/src/lib.typ`'s stated rule that the entrypoint is a manifest, not a
   place to add code:

   ```typ
   #import "board.typ": *
   ```

   Put a short header comment above it saying what the package is.

6. **Write `src/layout.js`** — the pure half, with no DOM in it, so it is testable
   under node. Export one function:

   ```js
   export function flowPositions(ids, opts)
   ```

   It takes an array of card ids and returns a `Map` from id to `{x, y}`, laying
   them out left to right in rows that wrap at a board width. Take `cardWidth`,
   `cardHeight`, `gap` and `boardWidth` from `opts` with defaults (320, 220, 24 and
   1200). It must be a pure function of its arguments — no `document`, no `window`,
   no measurement. This is the only part of this package a node test can reach, and
   the bird for browser tests is filed separately.

7. **Write `src/pinboard.js`** — the boot module, and vite's entry. It imports
   `flowPositions` from `./layout.js`, finds every `[data-pinboard]` in the
   document, and for each board reads its cards' `data-pinboard-id` values, computes
   flow positions, and writes each card's position as two CSS custom properties:

   ```js
   card.style.setProperty("--pin-x", `${x}px`);
   card.style.setProperty("--pin-y", `${y}px`);
   ```

   Positions go through custom properties rather than `style.left`/`style.top`
   because the CSS in step 8 owns the positioning rule, and the later drag bird
   updates the same two properties without having to know anything else about how a
   card is placed.

   This module is injected on EVERY page of a rheo project, most of which have no
   board on them. Absent a `[data-pinboard]` it must find nothing and return
   silently — no throw, no console output. `slipshow/0.1.0/src/slipshow.js:14-16`
   states the same requirement for the same reason.

   Boot on `DOMContentLoaded` if the document is still loading, and immediately
   otherwise, so the module works whether it is injected as a deferred module or
   evaluated late.

8. **Write `src/pinboard.css`.** The board is `position: relative` with an explicit
   `min-height`; a card is `position: absolute` with
   `translate: var(--pin-x, 0) var(--pin-y, 0)`. Give the handle a distinct
   background and `cursor: grab` — the cursor is a promise the drag bird keeps, and
   costs one line now. Give the card a border, a background that is not transparent
   (cards overlap), and a `max-height` on the body with `overflow: auto` so one long
   note cannot make a card taller than the board.

   Scope every rule under `.pinboard` or `.pinboard-card`. This stylesheet is
   injected into every page of a consuming project, and an unscoped rule here would
   restyle pages that have no board at all.

9. **Write `test/layout.test.mjs`** — node's own `--test`, matching the shape of
   `search/0.1.0/test/*.test.mjs`. Assert that `flowPositions` wraps to a second row
   when the ids exceed the board width, that positions are distinct, and that the
   same input array yields the same output twice.

10. **Write the demo project.** Copy `search/0.1.0/demo/rheo/rheo.toml` as the
    starting point — it already carries the `[packages.rookery] path = "../../../.."`
    table that makes the demo read `@rookery/*` out of THIS tree rather than out of
    the machine's Typst cache symlink, which may point at a different checkout.
    The relative depth is identical (`<pkg>/<version>/demo/rheo` is four levels down
    from the repo root), so the path needs no adjusting. Drop search's
    `[[html.assets]]` stylesheet block and its `[spine] exclude` list; neither
    applies here.

    Write `demo/rheo/content/index.typ` declaring a handful of `#idea("name")[..]`
    notes with real prose in them and then calling `#pinboard()`. Import both
    packages — `@rookery/core:0.1.0` for `idea`, `@rookery/pinboard:0.1.0` for
    `pinboard`.

    Write `demo/rheo/check.sh`, executable, modelled on
    `todos/0.1.0/demo/rheo/check.sh`. It must assert on the built HTML that a
    `data-pinboard` container exists and that the number of `data-pinboard-id`
    attributes equals the number of notes the demo declares. Exit non-zero with a
    message naming what was missing.

11. **Write `readme.md`**, covering what the package is, the `#pinboard(id:, notes:)`
    signature, that it needs `@rookery/core` imported alongside it in the consuming
    project's own `.typ` files, and that it is a built package.

12. **Update `/home/lox/code/_fcl/rookery/CLAUDE.md`.** It currently describes a
    seven-package repository, with counted claims in the opening paragraph ("Three
    of them (`search`, `todos`, `slipshow`) also ship JS") and an explicit dependency
    graph in a fenced block. Adding an eighth package makes both wrong. Add
    `pinboard` to the opening prose, correct the JS-shipping count from three to
    four, and add a `pinboard -> core` line to the dependency graph block. Do not
    rewrite anything else in that file.

## Non-goals

- **No dragging.** Cards sit where the flow layout puts them. Pointer handling is
  the next bird.
- **No collapsing.** Every card shows its body.
- **No persistence of any kind.** No `localStorage`, no storage module, no reading
  back a saved position. This repo contains zero browser-storage code today and this
  bird does not change that.
- **No export, no `.tldr`, no serialization.**
- **No `flake.nix`** in the package.
- **Do not touch any other package's directory.**
- **Do not edit `.github/workflows/publish-packages.yml`** — it discovers this
  package on its own.
- **Do not add a `parity` recipe.** That exists in `search` because a scoring rule is
  written twice, in Typst and in JavaScript. Nothing here is written twice.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/pinboard/0.1.0`:

1. `just build` succeeds and produces `dist/lib.js`.
2. `just test-js` passes.
3. `just check` succeeds: the demo compiles under `rheo compile demo/rheo` and
   `check.sh` exits zero.
4. `rg -c 'data-pinboard-id' demo/rheo/build/index.html` reports the same count as
   the number of `#idea(` calls in `demo/rheo/content/index.typ`.
5. From the repo root, `just check-versions` passes — it validates that every
   `@rookery/pkg:x.y.z` import spec in the tree matches a real `<pkg>/<version>/`
   directory, and the demo's new `@rookery/pinboard:0.1.0` import is exactly the
   kind of thing it catches.
6. `rg -n 'localStorage|sessionStorage' pinboard/` returns nothing.