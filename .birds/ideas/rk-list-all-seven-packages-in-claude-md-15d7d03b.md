---
id: rk-list-all-seven-packages-in-claude-md-15d7d03b
short-id: '15'
title: List all seven packages in CLAUDE.md
priority: 4
labels:
- chore-repo-docs
deps: []
closed: false
---
The repo's own `CLAUDE.md` describes a five-package repository. There are seven.
Two packages — `bibtex` and `slipshow` — are not named anywhere in it, and four
of its counted claims are wrong because of them. It is the file every agent reads
before touching this repo, so its being wrong is the highest-leverage defect in
the tree.

Touches: /home/lox/code/_fcl/rookery/CLAUDE.md

## What is wrong

`grep -n "slipshow\|bibtex" /home/lox/code/_fcl/rookery/CLAUDE.md` returns
nothing. Both are real, complete packages:

```
bibtex/0.1.0/    typst.toml: "A BibTeX reader and a #citation note constructor
                 for @rookery/core notes". Pure Typst + CSS: src/lib.typ 184,
                 parse.typ 111, view.typ 84, format.typ 65, keywords.typ 27,
                 claim.typ 13, bibtex.css 111. Six test fixtures, a rheo demo,
                 a Justfile with a `test` recipe. No package.json.

slipshow/0.1.0/  typst.toml: "An endlessly scrolling presentation over
                 @rookery/core ideas". A BUILT package: package.json + vite,
                 src/slipshow.typ 543, select.typ 417, tags.typ 159, slip.typ 69,
                 marker.typ 46, lib.typ 11, slipshow.css 337, and three JS files
                 (slipshow.js 393, edges.js 198, camera.js 111). A test suite in
                 both languages, a negative panic suite, a rheo demo and five
                 example projects. It also has its own flake.nix.
```

The four wrong claims, each a line a reader will act on:

1. **Lines 3-10, the opening paragraph.** It lists `core`, `search`, `timeline`,
   `todos`, `meetings` and stops. It then says "Two of them (`search`, `todos`)
   also ship JS via `package.json`/vite — see 'Pure-Typst packages' below for the
   two that don't", which is wrong twice over: THREE packages ship JS
   (`search`, `todos`, `slipshow`), and FOUR do not (`core`, `timeline`,
   `meetings`, `bibtex`).
2. **Line 7-8, the layout claim**: "mirrors the same layout: `typst.toml`,
   `src/`, a `Justfile`, and `flake.nix`". Only two packages have a `flake.nix`
   — `search/0.1.0` and `slipshow/0.1.0` — which the "Local development" section
   at lines 100-107 already says correctly of `search`. The opening promise
   contradicts it.
3. **Line 102**: "skip this for `core`/`timeline`/`meetings`, the three dist-less
   pure-Typst packages". Four, with `bibtex`.
4. **Lines 201-211, the "Pure-Typst packages" section**: "`core`, `timeline` and
   `meetings` are pure Typst (+ CSS)" and "`search` and `todos` are ORDINARY
   built packages". `bibtex` belongs in the first sentence and `slipshow` in the
   second.

Line numbers are as of filing; match the quoted text if they have shifted.

## Decisions already made — do not re-derive

- **Two one-sentence descriptions, not two new sections.** The opening paragraph
  names each package with a phrase; `bibtex` and `slipshow` get the same
  treatment and nothing more. Their own `readme.md` files are where a fuller
  account belongs.
- **Take each description from the package's own `typst.toml`**, quoted above, so
  this file and the manifests agree. Do not invent a characterisation by reading
  the source.
- **Fix the counts rather than deleting them.** "Three of them ship JS" and "the
  four dist-less pure-Typst packages" are useful facts; a vague "some" would be a
  regression.
- **Say the `flake.nix` claim accurately** rather than dropping it: the shared
  layout is `typst.toml`, `src/`, a `Justfile`, and a `flake.nix` where the
  package pins a toolchain of its own — which today is `search` (node/pnpm) and
  `slipshow`.
- **The import graph in the file is incomplete, and that is the second half of
  this bird.** Lines 19-31 describe `search` importing `core`, and `todos`
  importing `search` in one file — "That edge was forbidden until it was needed"
  — which reads as an account of every cross-package edge there is. It is not.
  The real graph, taken from the `#import "@rookery/..."` lines in each package's
  `src/` (verified, not inferred):

  ```
  core      -> nothing
  search    -> core
  bibtex    -> core
  slipshow  -> core
  timeline  -> core
  meetings  -> core, timeline
  todos     -> core, timeline, search, slipshow
  ```

  `todos` is the one with real fan-out, and `timeline` is by far its heaviest
  edge — seven files import it: `src/today.typ:14`, `src/skin.typ:19-20`,
  `src/views.typ:21`, `src/graph.typ:8`, `src/table.typ:32,37`,
  `src/todo.typ:4`, `src/tags.typ:37`. Its `slipshow` edge is one file,
  `src/deck.typ:27`, and its `search` edge is one file, `src/table.typ:30`,
  which is the one the existing paragraph already describes. `meetings`'s
  `timeline` edge is `src/lib.typ:22`.

## Steps

1. In `/home/lox/code/_fcl/rookery/CLAUDE.md`, extend the opening paragraph's
   package list with both packages, each with its one-phrase description drawn
   from its manifest: a BibTeX reader and `#citation` note constructor
   (`bibtex`), and an endlessly scrolling presentation over notes (`slipshow`).
2. In the same paragraph, correct the JS count to three (`search`, `todos`,
   `slipshow`) and the pure-Typst count to four.
3. Correct the layout sentence so `flake.nix` is described as per-package where a
   package pins its own toolchain, naming `search` and `slipshow`, rather than as
   part of the layout every package mirrors.
4. Line 102: "the three dist-less pure-Typst packages" becomes four and names
   `bibtex` alongside `core`/`timeline`/`meetings`.
5. The "Pure-Typst packages" section (from line 201): add `bibtex` to the
   pure-Typst sentence and `slipshow` to the built-package sentence. Leave the
   paragraph about what a built package's `dist/` holds and the
   `[tool.rheo.source.html]` block alone — it is true of all three built
   packages as written.
6. Add the import graph as a short block after the existing import-edge
   paragraphs (lines 19-31), in the shape given above under "Decisions already
   made". Keep those paragraphs: the `todos`-imports-`search` story and the
   reason for it are worth their length. What the block adds is that they are
   not the whole graph — `todos` also imports `timeline` in seven files and
   `slipshow` in one, and `meetings` imports `timeline`. Say it as the present
   arrangement; do not narrate when any edge was added.
7. Re-read the whole file once for any other count or enumeration that assumed
   five packages, and fix what you find. The sections most likely to carry one
   are "Build", "Local development against a live rheo project" and the closing
   paragraph about `.github/workflows/publish-packages.yml` — that last one
   describes a generic per-package loop, which is correct and needs no change,
   but check it rather than assuming.

## Do NOT

- Do not add a new top-level section for either package.
- Do not document either package's API, arguments or behaviour here. This file is
  about how the repo is arranged.
- Do not touch any package source, any `readme.md`, any `typst.toml`, or the
  workflows.
- Do not change the "Comment style" section, the `rheo-context` patterns, or the
  beacon-protocol section.
- Do not describe `slipshow`'s CI coverage or `bibtex`'s absence from it. A
  separate bird owns `.github/workflows/check.yml`.

## VERIFY

1. Both packages are named, and the counts are right:

   ```sh
   cd /home/lox/code/_fcl/rookery && grep -n "slipshow\|bibtex" CLAUDE.md
   cd /home/lox/code/_fcl/rookery && grep -n "Two of them\|three dist-less\|the two that don" CLAUDE.md
   ```

   The first must print several lines, including hits in the opening paragraph
   and in the "Pure-Typst packages" section. The second must print nothing.

2. Every package named in the file exists, and every package that exists is
   named. Check both directions by hand against:

   ```sh
   cd /home/lox/code/_fcl/rookery && ls -d */0.1.0 | cut -d/ -f1
   ```

   which prints exactly: `bibtex`, `core`, `meetings`, `search`, `slipshow`,
   `timeline`, `todos`.

3. The JS/pure split in the file matches the tree:

   ```sh
   cd /home/lox/code/_fcl/rookery && ls */0.1.0/package.json
   cd /home/lox/code/_fcl/rookery && ls */0.1.0/flake.nix
   ```

   The first prints three paths (`search`, `slipshow`, `todos`), the second two
   (`search`, `slipshow`). The file's claims must agree with both.

4. The import graph in the file matches the tree:

   ```sh
   cd /home/lox/code/_fcl/rookery && for p in bibtex core meetings search slipshow timeline todos; do printf "%-9s " $p; grep -rhoE '#import "@rookery/[a-z]+' $p/0.1.0/src | sort -u | grep -o '[a-z]*$' | tr '\n' ' '; echo; done
   ```

   Each line lists the package itself (from its own internal imports) plus every
   package it depends on. Today: `bibtex core`, `core`, `meetings core meetings
   timeline`, `search core`, `slipshow core`, `timeline core timeline`, `todos
   core search slipshow timeline todos`. The block you added must agree with it.

5. Nothing else changed: no package source, no workflow, no readme. This bird
   edits one file.