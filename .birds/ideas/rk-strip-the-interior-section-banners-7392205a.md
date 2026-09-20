---
id: rk-strip-the-interior-section-banners-7392205a
short-id: '739'
title: Strip the interior section banners
priority: 2
labels:
- strip-section-banners
deps:
- blocked-by:rk-rename-note-dir-to-idea-dir-79af1377
closed: true
---
This project's `CLAUDE.md` states the rule plainly: "**One header per file, no
interior banners.** The first comment block says what the file is. A
`// ---- Some Section ----` divider restating it is forbidden: the module is
the section, and a file needing dividers is a file wanting to be two."

`core/0.1.0/src/` currently carries 48 such dividers across 16 of its 19 Typst
files. This is the convention a first reader of the package will take away, and
it is the opposite of the one the project intends.

Touches: core/0.1.0/src/state.typ, core/0.1.0/src/pure.typ, core/0.1.0/src/base.typ, core/0.1.0/src/ideate.typ, core/0.1.0/src/idea.typ, core/0.1.0/src/urls.typ, core/0.1.0/src/outline.typ, core/0.1.0/src/data.typ, core/0.1.0/src/bib.typ, core/0.1.0/src/window.typ, core/0.1.0/src/hyperlink.typ, core/0.1.0/src/links.typ, core/0.1.0/src/permalink.typ, core/0.1.0/src/theme.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/src/template.typ

## Find them

```
rg -n '^// ----' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

48 hits as of filing, distributed as: `state.typ` 9, `pure.typ` 8, `base.typ` 4,
`ideate.typ` 4, `idea.typ` 3, `urls.typ` 3, `outline.typ` 3, `data.typ` 3,
`bib.typ` 2, `window.typ` 2, and one each in `hyperlink.typ`, `links.typ`,
`permalink.typ`, `theme.typ`, `transclusion.typ`, `template.typ`.

## What a divider looks like here, and what to do with it

A divider is a comment line of the form:

```
// ---- #idea — the note itself: validation, registration, rendering ---------
```

and it is almost always the FIRST line of a longer comment block that continues
underneath it with real explanation. The explanation stays. Only the divider
line goes.

Three cases, in order of how often they come up:

1. **The divider names the thing directly below it, and the block underneath
   already explains that thing.** Delete the divider line and, if it is followed
   by a blank comment line (`//`), delete that too so the block starts on its
   first real sentence. This is the common case.

2. **The divider carries information the block underneath does not.** For
   example a divider reading `// ---- TITLE vs LABEL, and the distinction is
   the whole point ----` sits above a block that explains the distinction but
   never states that framing. Fold the divider's claim into the block's first
   sentence, then delete the divider line. Do not lose the claim.

3. **The divider stands alone with no comment block under it.** Delete it
   outright.

## Steps

1. Work through the files one at a time, largest first (`state.typ`,
   `pure.typ`), applying the three cases above.

2. After each file, re-run the search scoped to that file to confirm it is
   clear.

3. When all sixteen are done, run the whole-directory search once more and
   confirm it prints nothing.

## Non-goals

- Do NOT delete or shorten the explanatory comment blocks themselves. This bird
  removes 48 divider LINES. The volume of commentary in these files is a real
  and separate concern with its own bird; conflating the two makes this change
  unreviewable.
- Do NOT touch the FILE HEADER comment at the top of each file — the block that
  says what the file is. That is the one comment the rule explicitly keeps.
  A header is the block before the first `#import`; it is not a divider even
  when it is long.
- Do NOT reflow, rewrap, or reformat surrounding comment text beyond what
  folding a case-2 divider requires.
- Do NOT change any code. No `#let`, no expression, no import order. The import
  order in `src/lib.typ` in particular is load-bearing — a Typst closure
  captures the scope visible at definition time, so reordering imports produces
  unknown-variable errors.
- Do NOT touch `core.css`, the demos, the tests, or any sibling package.

## VERIFY

1. `rg -n '^// ----' /home/lox/code/_fcl/rookery/core/0.1.0/src` prints nothing.
2. From `core/0.1.0`, `just test` passes (prints `units OK`).
3. From `core/0.1.0/demo/pure`, `just build` passes (prints `demo/pure OK`).
4. `rg -c '^//' /home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ` prints a
   number no more than 10 lower than it was before this bird — confirming
   dividers were removed and explanation was not.