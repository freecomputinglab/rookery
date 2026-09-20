---
id: rk-rename-idea-id-color-in-consumers-7a2d21ea
short-id: 7a2
title: Rename idea-id-color in consumers
priority: 2
labels:
- fix-idea-name-terminology
deps: []
closed: false
---
`@rookery/core` has renamed the CSS custom property `--idea-id-color` to
`--idea-name-color`, as part of standardising on one word — **name** — for the
thing that names a note. Four packages read that property and one of them also
sets it; all of them keep working, silently and wrongly, because a CSS
custom property that nobody defines falls through to its fallback rather than
erroring. Until this lands, every one of those sites quietly renders `gray`
instead of the theme's colour.

Touches: todos/0.1.0/src/todos.css, cfps/0.1.0/src/cfps.css, pinboard/0.1.0/src/pinboard.css, search/0.1.0/src/search.css, search/0.1.0/readme.md

## Prerequisite — fly this on a line that carries the packages

The core rename landed on a line that does not carry the sibling packages at
all. Before starting, confirm both that core has the new property and that this
flight's tree actually has the consumers:

```bash
ls todos/0.1.0/src/todos.css search/0.1.0/src/search.css
rg -n 'idea-name-color' core/0.1.0/src/theme.typ
```

If the first command errors, **stop and report that** — the flight was slipped
from the wrong base. If the second prints nothing, core's rename is not on this
line; stop and report that too, rather than renaming consumers to read a
property that does not exist yet.

## Why this is silent, and why there is no alias

CSS custom properties have no compile step and no undefined-variable error.
`var(--idea-id-color, gray)` against a core that no longer sets
`--idea-id-color` simply yields `gray`. So none of the builds below will fail
if you miss a site — the failure is visual, on a rendered page, which is why
the VERIFY section leans on `rg` rather than on a green build.

Core deliberately ships no back-compat alias. **Do not add one here either** —
no `var(--idea-name-color, var(--idea-id-color, …))` chain, and no duplicate
declaration keeping the old spelling alive.

## Rename A — core's property, in all five files

Sixteen occurrences. Anchor, run at the repo root so a moved file still
resolves:

```bash
rg -n 'idea-id-color' .
```

As of filing that printed sixteen hits:

1. **`todos/0.1.0/src/todos.css`** — 10, at lines 29, 57, 89, 126, 171, 196,
   300, 535, 612 and 617. Eight read `color: var(--todo-muted-color,
   var(--idea-id-color, gray));`; line 300 is
   `--slip-rule-color: var(--todo-muted-color, var(--idea-id-color, gray));`,
   line 612 is `--todo-graph-line: …` and line 617 is `fill: …`, all with the
   same inner `var()`. Every one is a plain textual rename of the inner
   property; the `--todo-muted-color` outer fallback and the `gray` final
   fallback are unchanged.
2. **`cfps/0.1.0/src/cfps.css`** — 1, at line 119:
   `color: var(--idea-tag-color, var(--idea-id-color, GrayText));`.
3. **`pinboard/0.1.0/src/pinboard.css`** — 1, at line 110. **This one is a
   setter, not a reader**: `--idea-id-color: var(--pinboard-select-fg, #fff);`.
   It becomes `--idea-name-color: var(--pinboard-select-fg, #fff);`. Renaming
   the reader and forgetting the setter, or vice versa, is the failure mode
   this bullet exists to prevent.
4. **`search/0.1.0/src/search.css`** — 2, at lines 247 and 344, both inside
   `var()` chains.
5. **`search/0.1.0/readme.md`** — 2, at lines 954 and 1147, in the
   fallback-chain column of two theme tables.

## Rename B — search's own parallel property

`search` declares a property of its own whose name parallels core's, and it has
to move with it or the pair stops reading as a pair. Anchor:

```bash
rg -n 'rookery-search-id-color' .
```

As of filing, five hits, all in `search`:

- `search/0.1.0/src/search.css:35` — a comment line in the theme block,
  `--rookery-search-id-color    the `idea:etal` id beside a row's title`.
  Rename the property AND reword the description, which still says *id* where
  it means the note's name: the `idea:etal` name beside a row's title. Keep the
  comment block's column alignment.
- `search/0.1.0/src/search.css:247` and `:344` — both inside the same `var()`
  chains touched by rename A. Note line 344 nests four deep
  (`--rookery-search-tag-color`, `--idea-tag-color`,
  `--rookery-search-id-color`, `--idea-id-color`, `gray`) and needs two
  substitutions on one line.
- `search/0.1.0/readme.md:954` and `:1147` — table cells, the first naming the
  property itself, the second naming it inside a fallback chain.

Line numbers throughout are as of filing and will drift. Resolve every site by
re-running the two `rg` commands inside the flight. If either prints nothing at
all, widen to the whole flight path; if still empty, report that upward rather
than guessing.

## Sequencing with the documentation site

`/home/lox/code/_fcl/rookery.ohrg.org/style.css` sets
`--rookery-search-id-color` (line 346 as of filing) and so depends on rename B.
That site has its own tracker and its own bird for it —
`rkdoc-update-reference-for-the-name-renames-3a0d0b50`, which already names
that exact line and replacement. **Do not edit that repo from this flight**;
just be aware the two want to land close together, and say in your flight
report that rename B has shipped so the docs bird can follow.

## The steps

1. Run the prerequisite checks above.
2. Apply rename A at all sixteen sites.
3. Apply rename B at all five sites, including the comment reword at
   `search/0.1.0/src/search.css:35`.
4. Check no other package has grown a reader since filing:

   ```bash
   rg -n 'idea-id-color|rookery-search-id-color' .
   ```

   This should now print nothing anywhere in the flight. As of filing, no
   package other than the five files listed above mentions either property —
   in particular `bibtex`, `meetings`, `timeline` and `slipshow` do not.

## Non-goals

- Do not add a back-compat alias or fallback chain for either property.
- Do not touch `core/`. Core's half of this rename has already landed.
- Do not touch `display-id` / `display-name` anywhere — that is a separate
  rename with its own bird, covering `slipshow` only.
- Do not rename `--idea-tag-color`, `--todo-muted-color`,
  `--pinboard-select-fg`, `--rookery-search-tag-color` or any other custom
  property. Only the two named above move.
- Do not rename a note's own `id` — `idea:<name>` anchors, HTML `id=`
  attributes, `.id` fields in JavaScript, or `data-*` attributes.
- Do not edit `/home/lox/code/_fcl/rookery.ohrg.org`.
- Do not retune any colour value, reorder a fallback chain, or restructure the
  readme tables. Only the property names change.

## VERIFY

1. `rg -n 'idea-id-color|rookery-search-id-color' .` prints nothing.
2. `rg -c 'idea-name-color' todos/0.1.0/src/todos.css` prints `10`, and
   `rg -n 'idea-name-color' cfps/0.1.0/src/cfps.css pinboard/0.1.0/src/pinboard.css`
   prints one hit in each.
3. `rg -n 'rookery-search-name-color' search/0.1.0/src/search.css` prints three
   hits and `search/0.1.0/readme.md` two.
4. Each built package still builds: `just build` in `todos/0.1.0`,
   `search/0.1.0` and `pinboard/0.1.0`. `cfps` is pure Typst with no build step
   — run `just test` there instead.
5. `just check` in `todos/0.1.0` and `search/0.1.0` succeeds. These compile a
   real rheo demo, which is the only step that exercises the stylesheet
   alongside the renamed core.

Remember that a missed site cannot fail a build. If any VERIFY step cannot run
because `rheo` resolves `@rookery/core` from outside this tree, say so in your
flight report rather than reporting a build you did not perform.