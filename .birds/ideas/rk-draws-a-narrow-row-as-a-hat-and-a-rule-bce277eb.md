---
id: rk-draws-a-narrow-row-as-a-hat-and-a-rule-bce277eb
short-id: bc
title: Draws a narrow row as a hat and a rule
priority: 3
labels:
- mobile-row-hat
deps: []
closed: true
---
A narrow `#idea-row` currently stacks by flattening its grid: the date cell
spans the full width on its own line, the title and the badge strip share
the line under it, and nothing indents. Read on a phone that is three
left-aligned lines with no edge to hang them on — the date reads as a
heading for the row, and the badges are pushed hard right against the title.

It should read like a note card instead: the date becomes a HAT at the
top-left corner, a rule in the hat's colour runs down the row's left edge
beneath it, the badge strip joins the hat on that first line, and the
title (with any `cells:` entry) sits under both, indented past the rule by
`--idea-pad` — the same corner-and-rule shape `[data-rookery="box"]` and
`[data-rookery="tab"]` already draw for an idea.

This bird does the LAYOUT and the DEFAULT rule colour, in core. The band
colours that a todo row paints on that cell are @rookery/todos' and are
wired to the rule by a separate bird (deps).

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/core.css — one `@media`
block, nothing else in the repo.

## Decisions already made — do not re-derive

**The DOM order is when, title, cells, badges**, and it does not change.
`idea-row-body` in `src/row.typ` (lines 74-113) emits the `row-when` span,
then the title `<span>`/`<a>`, then one `row-cell` span per `cells:` entry,
then the `row-badges` strip. Do NOT touch `row.typ` — no reordering, no new
wrapper element. The first line is built by GRID PLACEMENT, which is what
lets the badges (last in the DOM) sit beside the hat (first in the DOM).

**Placement: two definite items, two auto ones.** Give `row-when`
`grid-row: 1; grid-column: 1` and `row-badges` `grid-row: 1;
grid-column: 2`. Both are then *definitely placed* and CSS grid positions
them before it auto-flows anything, whatever their DOM order. The title and
any `row-cell` get only `grid-column: 1 / -1` and auto-flow into rows 2 and
3 in DOM order. This is why nothing needs `grid-template-areas`: a named-area
template would have to declare a third row for `cells:`, and the row `gap`
applies between tracks even when one is empty — so every row without a
`cells:` entry would gain a phantom line of space.

**The rule is drawn by `[data-rookery="row-when"]::before`, absolutely
positioned against the ROW.** Not by a `border-left` on the row, and not by
a `::before` on the row itself. The reason is the colour: on a todo row the
hat's fill is painted on the WHEN CELL, and a downstream package can only
re-point a colour it can reach — the row is that cell's ancestor, and
neither a custom property nor a background reaches upward. Drawing the bar
from the cell's own pseudo-element puts it where @rookery/todos can recolour
it (which is exactly what the dependent bird does).

`::before` is free on this cell: @rookery/todos hangs its countdown tooltip
off `::after` (`todos.css` lines 444-462) and nothing in this repo uses
`::before` on it.

**The row therefore gets `position: relative`, and the when cell gets
`position: static`.** @rookery/todos sets `position: relative` on
`[data-rookery="row-when"][data-countdown]` (`todos.css` line 333) so its
tooltip anchors to the cell. Left alone, that cell would become the bar's
containing block and `top: 0; bottom: 0` would span the HAT rather than the
row. So the narrow block states `position: static` on the when cell: at
narrow widths the row is the containing block, for the bar and for todos'
tooltip alike. That is a layout fact about this block, which is why it is
declared here rather than left to the other package.

**THIS FILE IS UNLAYERED AND THEREFORE WINS.** `core.css` has no `@layer`
anywhere; `todos.css` wraps everything in `@layer todos` (line 18) and
`search.css` likewise. Unlayered author CSS beats layered author CSS whatever
the specificity, so every property declared below overrides the other
packages' rules for the same property on the same element. That cuts both
ways and is the reason the property list here is exactly what it is:

- DO declare `margin-left` and `padding-left` on the when cell. They
  intentionally beat todos' `margin-left: -0.3em` / `padding-inline: 0.3em`
  (lines 334-335 and 400-401) on the left side, so the hat reaches the row's
  own left edge. Todos' `padding-inline` still supplies the RIGHT side; that
  is fine and wanted.
- DO NOT declare `align-self`, `padding-block`, `margin-block`,
  `margin-top`, `margin-bottom` or `display` on the when cell. Todos uses
  all of those to make a band the row's full height (lines 320-327), and the
  dependent bird retunes them for the hat. A declaration here would freeze
  that package out of its own band geometry.
- DO NOT hardcode the bar's colour. Declare it as
  `var(--idea-row-rule-color, <the usual chain>)` — core never SETS
  `--idea-row-rule-color`, only reads it, so a layered package can set it on
  the cell without losing to this file. That is the whole hook the dependent
  bird hangs on.

**Mirror the package's two-level fallback chain for the default colour**:
`var(--idea-border-color, var(--idea-link-color, rgba(128, 0, 255, 0.12)))`,
exactly as lines 535 and 739 write it. `--idea-rule-width` (default `2px`)
is the bar's width and `--idea-pad` (default `0.5em`) the indent, the same
two variables `[data-rookery="tab"]::before` composes at line 189. A row is
not inside a `[data-rookery="box"]`, so `--idea-pad` resolves to its
fallback — write the fallback, do not introduce a new variable.

**Keep the 768px breakpoint.** It is where the fixed 7.5em date track stops
paying for itself, which has not changed. Do not align it with
@rookery/search's own `40em` block (`search.css` line 723) — that one is
about a preview pane, not about a row.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/core.css`, replace the
   comment and block at lines 1250-1263 — the comment beginning `/* NARROW:
   the date column stops paying for itself` and the whole
   `@media (max-width: 768px)` block under it — with the following. Nothing
   else in the file changes.

   ```css
   /* NARROW: the date column stops paying for itself — a fixed 7.5em beside a
      title leaves the title two words per line — so the row stops being a
      table and becomes a CARD: the date is a hat at the top-left corner, a
      rule in the hat's colour runs down the left edge under it, the badges
      join the hat on that line, and the title sits below both, indented past
      the rule. The same corner `[data-rookery="tab"]` and `[data-rookery="box"]`
      draw for a note, at the size a row can afford.

      THE FIRST LINE IS BUILT BY PLACEMENT, not by DOM order: the badge strip
      is emitted LAST (see `idea-row-body`) and grid places definitely-positioned
      items before it flows anything, so naming a row and a column for the hat
      and the strip is enough. The title and any `cells:` entry take a column
      span only and flow into the lines beneath, in the order they were written.

      NAMED AREAS WERE REJECTED for the same reason: a template would need a
      third row for `cells:`, and `gap` applies between empty tracks — every
      row without one would gain a phantom line. */
   @media (max-width: 768px) {
     [data-rookery="row"] {
       position: relative;
       grid-template-columns: auto 1fr;
       gap: 0.15rem 0.5rem;
       align-items: center;
       padding-left: calc(var(--idea-rule-width, 2px) + var(--idea-pad, 0.5em));
     }

     /* THE HAT. `margin-left` cancels the row's indent and `padding-left`
        pays it back inside the cell, so a cell that paints a background
        paints it right out to the row's left edge — over the rule below,
        which closes the corner — while the date's glyphs stay on the
        content margin the title keeps.

        `position: static` is load-bearing: @rookery/todos makes this cell
        `relative` to anchor its countdown tooltip, and that would make the
        HAT the containing block for the rule below rather than the row. At
        this width the row is the containing block for both. */
     [data-rookery="row-when"] {
       grid-row: 1;
       grid-column: 1;
       position: static;
       margin-left: calc(-1 * (var(--idea-rule-width, 2px) + var(--idea-pad, 0.5em)));
       padding-left: calc(var(--idea-rule-width, 2px) + var(--idea-pad, 0.5em));
     }

     /* THE RULE, drawn from the hat's own pseudo-element and not from a
        `border-left` on the row. The colour is the point: a consumer paints
        the hat on THIS cell, and a custom property reaches descendants only —
        a bar belonging to the row could never read what was set on the cell
        inside it. `--idea-row-rule-color` is read and never set here, so a
        layered stylesheet can re-point it (@rookery/todos runs its urgency
        band down this bar) without losing to this unlayered file. */
     [data-rookery="row-when"]::before {
       content: "";
       position: absolute;
       left: 0;
       top: 0;
       bottom: 0;
       width: var(--idea-rule-width, 2px);
       background-color: var(
         --idea-row-rule-color,
         var(--idea-border-color, var(--idea-link-color, rgba(128, 0, 255, 0.12)))
       );
     }

     /* Beside the hat, and LEFT-aligned: the strip's `justify-content:
        flex-end` is right when it terminates a wide row and wrong here,
        where it is the second thing on a line rather than the last thing
        in a table. */
     [data-rookery="row-badges"] {
       grid-row: 1;
       grid-column: 2;
       justify-content: flex-start;
       align-items: center;
     }

     [data-rookery="row-title"],
     [data-rookery="row-cell"] {
       grid-column: 1 / -1;
     }

     /* A chip sharing a line with the date has to be smaller than one that
        had a column to itself, or the hat's line is the tallest thing in
        the row and the title reads as its caption. */
     [data-rookery="row-badges"] > [data-rookery="tag"] {
       font-size: var(--idea-tag-size, 0.72em);
     }
   }
   ```

## Do NOT

- Do NOT edit `src/row.typ` or any other `.typ` file. No new element, no
  reordering, no new parameter: this is one `@media` block in one stylesheet.
- Do NOT touch the desktop `[data-rookery="row"]` rule at lines 1183-1190,
  its `--idea-row-pad-block` declaration, or the `[hidden]` rule at 1202.
  Wide rows are unchanged by this bird.
- Do NOT touch `@media (max-width: 600px)` at the end of the file — that is
  `#ideas-outline`'s indent and unrelated.
- Do NOT add `--idea-row-rule-color` to the variable table in this file's
  header comment (lines 22-70) or to `readme.md`. Neither documents
  `--idea-row-pad-block` either, and one file with two conventions is worse
  than either; the rule's own comment is where this package explains itself.
- Do NOT try to make the plain (unbanded) hat a filled block. With no
  consumer painting it, a narrow row shows a thin rule in the project's
  border colour and an unfilled date above it. That is the intended
  baseline.
- Do NOT edit `todos.css` or `search.css`. They have their own birds, which
  depend on this one.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/core/0.1.0`:

1. `just test` prints `units OK`. This is the pure-Typst fixture; a
   CSS-only change must leave it green untouched. Do not add a test — there
   is no CSS harness in this package.

2. `grep -c 'idea-row-rule-color' src/core.css` prints `1`. Read, never set.

3. `grep -n 'max-width: 768px' src/core.css` returns exactly one line.

4. `grep -n 'grid-column: 1 / -1' src/core.css` shows the title/cell rule
   and no longer shows a `row-when` selector above it — the old block's
   `[data-rookery="row-when"], [data-rookery="row-cell"] { grid-column: 1 / -1 }`
   is gone.

Eyeballing it in a real project is a separate step and NOT part of this
bird: `waterline` resolves `@rookery` from this repo by git ref
(`rookery/rheo.toml`, `[packages.rookery] branch = "0.1.0"`), so an
uncommitted edit here is invisible to its build. Do not attempt to build
`waterline` to verify.