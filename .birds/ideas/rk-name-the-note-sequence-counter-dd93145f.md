---
id: rk-name-the-note-sequence-counter-dd93145f
short-id: dd
title: Name the note-sequence counter
priority: 2
labels:
- chore-core-review
deps:
- blocked-by:rk-resolve-visible-tags-once-in-idea-0c57019f
- blocked-by:rk-cache-bib-keys-drop-dead-cite-walk-871b6099
- blocked-by:rk-destructure-pair-maps-across-core-de56c4bd
closed: false
---
The counter that gives an unnamed note its id is addressed by its string key in
three places in `idea.typ`, while every other piece of document-wide state in
this package is a named binding in `state.typ`.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ

## What is wrong

`/home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ` exists to hold "the
document-wide state this package publishes and reads back" — its own header,
line 1 — and it does hold all of it: `_prefix`, `_note-dir`, `_css-prefix`,
`_window-depth`, `_bib`, `_idea-page-template`, `_syndicate`, `_index-page`,
`_show-context`, `_show-backlinks`, `_show-title`, `_page-titles`,
`_invisible-tags`, `_registry`, `_excluded-ids`, and the two footnote counters
`_fn-block` (line 374) and `_fn-seq` (line 379).

The note-sequence counter is the exception. It is written as
`counter("rheo-ideas-seq")` inline, three times, in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ`:

- line 112 — `if not named { counter("rheo-ideas-seq").step() }`, the excluded path
- line 200 — `#if not named { counter("rheo-ideas-seq").step() }`, the normal path
- line 205 — `let n = counter("rheo-ideas-seq").get().first()`

Three copies of one string key, in the one place a typo would be silent: a
misspelling produces a second, independent counter, so ids would restart at 1
somewhere in the middle of a document and collide with earlier ones.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **The state key string does not change.** It stays `"rheo-ideas-seq"`. A
  Typst counter is global per key, and changing it would renumber every unnamed
  note's id — which is every minted page URL for a titleless note.
- **The binding goes next to `_registry`**, in the same block of `state.typ`,
  because an unnamed note's id and the registry it lands in are one subject. The
  comment at `src/state.typ:329-338` already describes the counter's behaviour
  there without owning the binding.
- **Name it `_seq`.** Short, matches `_fn-seq`/`_fn-block` beside it, and no
  such name exists in the package today (grep for `_seq` before adding it if
  you want to confirm).

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ`, immediately above
   `#let _registry = state("rheo-ideas", (:))` (line 339), add:

   ```typ
   // An unnamed note's id is this counter's value at its call site. Stepped by
   // `#idea` for every unnamed note, INCLUDING one the exclusion gate dropped,
   // so a note's id does not depend on which build variant it was compiled in.
   #let _seq = counter("rheo-ideas-seq")
   ```

2. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ`, replace all three
   inline `counter("rheo-ideas-seq")` expressions with `_seq`:
   - line 112 → `if not named { _seq.step() }`
   - line 200 → `#if not named { _seq.step() }`
   - line 205 → `let n = _seq.get().first()`

   `idea.typ` already imports `state.typ` with `*` (line 9), so the name is in
   scope with no import change.

## Do NOT

- Do not change the counter's key string, and do not add a second counter.
- Do not move the `.step()` calls, change where they sit relative to the
  `figure(kind: IK)`, or alter the `if not named` conditions. Both step sites
  are load-bearing and documented: the comment at `src/idea.typ:87-110`
  explains why the excluded path still steps, and the comment at
  `src/idea.typ:198-199` explains why `.step()`'s return value must be emitted
  rather than bound.
- Do not touch `_fn-block` or `_fn-seq`.
- Do not reword comments beyond the new one in step 1. Separate birds cover the
  comment prose in both files.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`. All four are green today.

`demo/rheo` is the decisive one: it contains unnamed notes and its build mints
`build/html/ideas/1.html` and `build/html/ideas/2.html` from this counter, so a
broken key shows up as a missing or renumbered page. `demo/pure`'s
`excluded.typ` pair covers the other half — that an excluded unnamed note still
steps the counter, so the ids of later notes do not shift between the two
builds.

Also confirm the string key is gone from `idea.typ`:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -n 'counter("rheo-ideas-seq")' *.typ
```

Expected: one hit only, the `_seq` binding in `state.typ`.