---
id: rk-query-outline-edges-by-label-682d6913
short-id: '68'
title: Query outline edges by label
priority: 4
labels:
- chore-core-review
deps: []
closed: false
---
The outline's document walk queries EVERY `metadata` element in the bundle in
order to find its own edge markers. Label the markers and query the label.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ

## What is wrong

`_ideas-outline-data` walks the document at
`/home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ:307`:

```typ
  for el in query(selector(metadata).or(selector(figure.where(kind: IK)))) {
```

It wants two things in document order: the `figure(kind: IK)` markers (one per
note) and the open/close edge markers `_bracket` emits around every note and
every window. The edges are `metadata`, so the selector asks for all metadata —
and then the loop throws most of the results away, at
`src/outline.typ:309-318`, by testing for a `rookery-edge` key.

Everything else in the bundle that is a `metadata` element is fetched and
discarded on every call: every `#footnote` payload (`src/idea.typ:639`), every
`#window` announce marker and every WK marker (`src/window.typ:222` and
`src/window.typ:300`), every `#hyperlink` marker (`src/hyperlink.typ:141`),
every per-page `<rookery-page-links>` beacon (`src/outline.typ:130`), the
`#metadata` payload inside every IK figure (`src/idea.typ:197`), plus whatever
metadata the consuming project and any other `@rookery` or `@rheo` package
emits — `@rheo/feeds` beacons, `@rookery/todos` and `@rookery/timeline` data.
The waste grows with the site, not with the outline.

The edges are emitted in exactly one place, `_edge` at
`/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ:44`:

```typ
#let _edge(edge, container) = metadata((rookery-edge: edge, rookery-container: container))
```

so giving them a label is a one-line change with one reader to update.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **A label, not a narrower element selector.** There is no way to select
  `metadata` by the shape of its value, and the walk genuinely needs these
  elements in document order interleaved with the IK figures, so the two-part
  `.or(..)` selector has to stay a selector.
- **A repeated label is fine here and is already the house pattern.** This
  package labels many elements with one shared name and queries them back:
  `<rkfn>` on every footnote (`src/idea.typ:639`, queried through a show rule),
  `<rookery-window-mark>` on every window announce marker
  (`src/window.typ:222`, queried at `src/outline.typ:151`), and
  `<rookery-page-links>` once per vertebra (`src/outline.typ:130`, queried at
  `src/outline.typ:167`). A label is only required to be unique for `ref` to
  resolve it, and nothing refs these.
- **Keep the `type(v) != dictionary` guard** in the loop. It costs nothing and
  keeps the walk total if anything else ever wears the label.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ`, label the
   marker. Line 44 becomes:

   ```typ
   #let _edge(edge, container) = [#metadata((rookery-edge: edge, rookery-container: container))<rookery-edge>]
   ```

   Add one sentence to the comment block above it (lines 36-43) saying that the
   label is what lets `_ideas-outline-data` query the edges without fetching
   every `metadata` element in the bundle, and that it is deliberately shared by
   every edge because nothing refs it.

2. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ:307`, narrow the
   query:

   ```typ
   for el in query(selector(<rookery-edge>).or(selector(figure.where(kind: IK)))) {
   ```

3. Leave the loop body alone. `el.func() == metadata` still identifies an edge,
   because a labelled metadata element is still a metadata element.

4. One unrelated one-liner in the same file, included here so no second flight
   has to open it. `_flatten`'s WK arm reads the nested window's presentation
   arguments off its marker, and every one of them is read with a default —
   `v.at("show-tags", default: false)`, `v.at("show-frame", default: true)`,
   and six more (`src/transclusion.typ:459-469`) — except `show-date`, which is
   a bare `v.show-date` at `src/transclusion.typ:458`. A WK marker written by an
   older version of this package carries no such key and the read panics.
   Change it to `v.at("show-date", default: false)` — `false` is `#window`'s own
   default for the argument (`src/window.typ:66`). Then delete the two comment
   lines that record the inconsistency instead of fixing it (`src/transclusion.typ:449-451`,
   "NOTE: `v.show-date` just above is a bare field access with no such guard — a
   pre-existing risk this bead does not touch.") and keep the rest of that
   comment, which explains why the defaults differ in direction.

## Honest uncertainty, and the fallback

`selector(<rookery-edge>)` as an operand of `.or(..)` is the one step here that
is not already demonstrated elsewhere in this package — the existing label
queries are bare `query(<label>)` calls. If Typst rejects it, try
`query(selector(<rookery-edge>).or(figure.where(kind: IK)))` (passing the
element selector without the redundant `selector(..)` wrapper), and if that
fails too, revert both files to exactly their current state, report in the
flight that the selector combination is not available on this Typst version,
and do not invent a third approach — the current code is correct, only wasteful.

The second thing to watch is that `_edge` now returns a markup block rather than
a bare element. Every other reader walks content structurally and descends into
children (`_page-outbound` at `src/outline.typ:85`, `_outbound` at
`src/links.typ:39`, `_cite-scan` at `src/bib.typ:53`, `_footnotes` and
`_std-footnotes` in `src/pure.typ`), so a wrapping sequence is transparent to
them — `#footnote` already ships exactly this shape at `src/idea.typ:639`. The
demos below are what prove it; if `demo/rheo`'s `check.sh` reports a failure
about backlinks, citations, footnote numbering or `limit:` truncation, that is
this change and it must be reverted rather than patched around.

## Do NOT

- Do not change the marker's dictionary keys (`rookery-edge`,
  `rookery-container`) or their values (`"open"`/`"close"`, `IK`/`WK`).
- Do not touch `_bracket`, or any of the five structural walks listed above.
- Do not add a second label, and do not label the IK or WK figures.
- Do not reword comments beyond the one sentence in step 1 — separate birds
  cover the comment prose in both files.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`. All four are green today.

`demo/rheo`'s `check.sh` is the decisive one: among the assertions it prints are
`outline forms: the page form is local, the rookery-wide form is not` and
`prune and promote: the untagged parent is pruned, its tagged child promoted`,
both of which read the outline this query builds, plus the window-depth,
backlink and sweep-block assertions that the edge markers feed.