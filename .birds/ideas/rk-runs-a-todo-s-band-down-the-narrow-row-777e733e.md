---
id: rk-runs-a-todo-s-band-down-the-narrow-row-777e733e
short-id: '77'
title: Runs a todo's band down the narrow row's rule
priority: 3
labels:
- mobile-row-hat
deps:
- blocked-by:rk-draws-a-narrow-row-as-a-hat-and-a-rule-bce277eb
closed: true
---
At narrow widths `#idea-row` now draws its date cell as a HAT at the row's
top-left corner with a rule running down the left edge beneath it (see the
bird this one depends on). The rule reads `--idea-row-rule-color`, which
@rookery/core sets nowhere — it is the hook a consumer uses to run its own
colour down the edge.

`#todo-table` is that consumer: it paints an urgency band or a priority wash
on the date cell, and at narrow widths that colour should continue down the
row's rule, so a phone-sized list reads as a column of cards each edged in
its own heat. Two things are in the way, and this bird fixes both:

1. **The band colour is not readable as a colour.** Each of the seven band
   rules writes its mix straight into `background-color`, so nothing can
   hand the same value to a second property. They gain a
   `--todo-band-color` custom property and read it back.
2. **The band's geometry is tuned for a full-height row cell.** It stretches
   and negates the row's vertical padding on BOTH sides (`todos.css` lines
   320-327), which is right for a table cell filling a wide row and wrong for
   a hat: the bottom negation paints the band down over the title line under
   it.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css only.

## Decisions already made — do not re-derive

**The colours themselves do not change.** Every mix below is copied from the
rule it replaces, character for character, including the two-level
`var(--todo-band-<name>, color-mix(... var(--rookery-heat-*) ...))` chain. A
site that has retuned `--rookery-heat-urgent` or a single
`--todo-band-soon` must see exactly what it sees today; this is a
refactor with one new property, not a re-palette.

**`--todo-band-color` is declared ON THE CELL, and that is why this works
at all.** A custom property reaches an element's descendants and never its
ancestors. The band classes are on the `row-when` span, the rule is drawn by
that span's own `::before`, and a pseudo-element inherits from its
originating element — so a property set beside the band's
`background-color` is visible to the bar and to nothing else.

**A priority cell takes its rule from the INK, not from the wash.** An
undated row's priority label carries `todo-when-priority` *and* a
`todo-when-rung-<n>` class, so it already has a wash (lines 369-388) and a
saturated ink of the same hue on top (lines 406-416). Two pixels of a
22%-alpha wash is invisible; the ink is the whole reason that cell reads. So
`.todo-when-priority` sets `--idea-row-rule-color: currentColor`, and
because `color:` on that cell is the rung hue, `currentColor` IS the rung
hue. It must come AFTER the `[data-countdown]` rule in the file — equal
specificity, later wins — and the two can never both match: `[data-countdown]`
is deliberately absent on a priority cell (see the comment at line 390).

**`core.css` IS UNLAYERED AND BEATS THIS FILE** on any property both
declare, whatever the specificity — everything here lives in `@layer todos`
(line 18). That is settled, not something to work around, and it decides
what this bird may touch:

- Core's narrow block declares `position`, `margin-left`, `padding-left`,
  `grid-row` and `grid-column` on the when cell. Do NOT declare any of those
  here, at any specificity; the declaration would simply lose. In particular
  the hat's reach to the row's left edge is already core's, and this file's
  existing `margin-left: -0.3em` / `padding-inline: 0.3em` keep supplying
  only the RIGHT side at narrow widths, which is correct.
- Core declares NOTHING about the cell's block-direction spacing or
  `align-self`, precisely so this file keeps owning the band's height. So
  the `margin-block` / `padding-block` retune below is uncontested and will
  bite.
- `--idea-row-rule-color` is READ by core and set by nobody, so setting it
  here wins by default rather than by luck.

**The countdown tooltip re-anchors, and that is accepted.** Core's narrow
block sets `position: static` on the when cell, so at narrow widths the
`::after` phrase (lines 444-462) is positioned against the ROW: it opens
above the row, centred on the row rather than on the date. It still points
at the right row and still reads. Do NOT add a narrow-width override to
re-anchor it, and do NOT give the cell `position: relative` back — that
would make the hat the containing block for the rule and break the bar.

**Same breakpoint as core's row block: `768px`.** Not this family's other
widths. The rules below exist only because core's own narrow block exists,
and a band retuned at a width where the row is still a table would be wrong.

## Steps

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css`, rewrite the
   seven band rules at lines 342-388 so each declares the colour as
   `--todo-band-color` and then reads it back. Keep every comment in that
   span exactly as it is, keep the rules in their current order, and keep
   `color` and `font-weight` on the overdue rule.

   ```css
   [data-rookery="row-when"].todo-when-overdue {
     --todo-band-color: var(--todo-band-overdue, var(--rookery-heat-urgent, #b3261e));
     background-color: var(--todo-band-color);
     color: var(--todo-band-overdue-fg, #fff);
     font-weight: 600;
   }

   [data-rookery="row-when"].todo-when-urgent {
     --todo-band-color: var(
       --todo-band-urgent,
       color-mix(in oklab, var(--rookery-heat-urgent, #b3261e) 38%, transparent)
     );
     background-color: var(--todo-band-color);
   }

   [data-rookery="row-when"].todo-when-soon {
     --todo-band-color: var(
       --todo-band-soon,
       color-mix(in oklab, var(--rookery-heat-soon, #b3611e) 30%, transparent)
     );
     background-color: var(--todo-band-color);
   }

   [data-rookery="row-when"].todo-when-later {
     --todo-band-color: var(
       --todo-band-later,
       color-mix(in oklab, var(--rookery-heat-later, #b38f1e) 24%, transparent)
     );
     background-color: var(--todo-band-color);
   }

   [data-rookery="row-when"].todo-when-rung-0 {
     --todo-band-color: var(
       --todo-band-rung-0,
       color-mix(in oklab, var(--rookery-heat-urgent, #b3261e) 34%, transparent)
     );
     background-color: var(--todo-band-color);
   }

   [data-rookery="row-when"].todo-when-rung-1 {
     --todo-band-color: var(
       --todo-band-rung-1,
       color-mix(in oklab, var(--rookery-heat-soon, #b3611e) 28%, transparent)
     );
     background-color: var(--todo-band-color);
   }

   [data-rookery="row-when"].todo-when-rung-2 {
     --todo-band-color: var(
       --todo-band-rung-2,
       color-mix(in oklab, var(--rookery-heat-later, #b38f1e) 22%, transparent)
     );
     background-color: var(--todo-band-color);
   }
   ```

2. Add a sentence to the comment that introduces the bands — the block
   ending `...along with `#timeline-upcoming`'s countdown chips in
   @rookery/timeline.` just above these rules (around line 308) — saying why
   the colour is now a property:

   ```
    * DECLARED AS `--todo-band-color` AND READ BACK, rather than written straight
    * into `background-color`: at narrow widths the row is a card and the band is
    * its hat, and the rule down the card's left edge has to be painted the same
    * colour. A pseudo-element inherits from the cell, so one property beside the
    * fill is all that bar needs (see the narrow block at the end of this file).
   ```

3. At the END of the `@layer todos` block — immediately before the file's
   final closing `}` at line 600, after the last existing rule — add the
   narrow block:

   ```css
   /* NARROW: THE ROW IS A CARD AND THE BAND IS ITS HAT. @rookery/core's own
    * narrow block turns `#idea-row` into a corner — the date at the top-left,
    * a rule down the left edge under it, the title indented past that rule —
    * and draws the rule from `--idea-row-rule-color`, which it reads and never
    * sets. Pointing that at the band is what makes a phone-sized list read as a
    * column of cards each edged in its own heat, rather than as a stack of
    * lines with a coloured chip on top of each.
    *
    * THE BAND'S HEIGHT IS RETUNED HERE, and it has to be. The wide-row
    * geometry above stretches the cell and negates the row's vertical padding
    * on BOTH sides so the wash meets the rules above and below it. As a hat
    * that is wrong below: the negative bottom margin paints the band down over
    * the title on the next line. So the top negation stays — that is what puts
    * the hat's fill on the row's own top edge, closing the corner — and the
    * bottom becomes a little breathing room under the date instead.
    *
    * Core declares nothing about this cell's block spacing, precisely so these
    * two declarations still bite from inside `@layer todos`. What it DOES
    * declare — `position`, `margin-left`, `padding-left`, `grid-row`,
    * `grid-column` — must not be restated here: this file is layered and would
    * lose. */
   @media (max-width: 768px) {
     [data-rookery="row-when"][data-countdown],
     [data-rookery="row-when"].todo-when-priority {
       margin-block: calc(-1 * var(--idea-row-pad-block, 0)) 0;
       padding-block: var(--idea-row-pad-block, 0) 0.15em;
     }

     [data-rookery="row-when"][data-countdown] {
       --idea-row-rule-color: var(--todo-band-color, currentColor);
     }

     /* AN UNDATED ROW'S PRIORITY RULES FROM ITS INK. The cell wears a
      * `todo-when-rung-<n>` wash too, but two pixels of a 22%-alpha mix is
      * nothing to see; the saturated rung hue this cell sets as `color` is the
      * whole reason it reads, and `currentColor` is that hue. After the rule
      * above on purpose — equal specificity, later wins — though the two can
      * never both match, since `[data-countdown]` is absent on these cells. */
     [data-rookery="row-when"].todo-when-priority {
       --idea-row-rule-color: currentColor;
     }
   }
   ```

## Do NOT

- Do NOT edit `core.css` or `search.css`. Core's half is a separate bird
  (this one's dep) and already done; the pill sizing is @rookery/search's.
- Do NOT edit any `.typ` or `.js` file, and do NOT add a parameter to
  `#todo-table`. The band classes already emitted are the whole input.
- Do NOT change a single colour value, alpha or variable name in the seven
  band rules. The only new name is `--todo-band-color`.
- Do NOT give `--todo-band-color` a rule of its own on some ancestor as a
  default. It is set per band and read with a fallback; a cell with no band
  must resolve the bar to core's border-colour chain, which is what happens
  when the property is simply absent.
- Do NOT document `--todo-band-color` in `readme.md`. It is internal
  plumbing between two rules in this file, not a knob a site sets — the
  seven `--todo-band-<name>` overrides remain the documented surface.
- Do NOT touch the tooltip rules, the `.soft[data-countdown]` muted-colour
  override (lines 431-433), or the stats rules.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just test` prints `units OK`, and `just test-js` is green. Both are
   Typst/JS fixtures that read no stylesheet; a CSS-only change must leave
   them untouched and passing.

2. `just check` ends by printing the demo's OK line. It compiles
   `demo/rheo` and runs `demo/rheo/check.sh`, whose band assertions read the
   `class="idea-row-when …"` values off the output (line 182) — the markup
   must be byte-identical, since nothing here touches emission.

3. `grep -c 'background-color: var(--todo-band-color)' src/todos.css`
   prints `7` — every band reads the property back, none of them still
   writes a colour straight into the fill. And
   `grep -c -- '--todo-band-color:' src/todos.css` prints `7` — one
   declaration per band, none anywhere else.

4. `grep -n 'max-width: 768px' src/todos.css` returns exactly one line, and
   it is the last rule block in the file, inside `@layer todos` — confirm
   with `tail -5 src/todos.css` showing two closing braces.