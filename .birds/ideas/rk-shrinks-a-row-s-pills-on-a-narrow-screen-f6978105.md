---
id: rk-shrinks-a-row-s-pills-on-a-narrow-screen-f6978105
short-id: f6
title: Shrinks a row's pills on a narrow screen
priority: 3
labels:
- mobile-row-hat
deps:
- blocked-by:rk-draws-a-narrow-row-as-a-hat-and-a-rule-bce277eb
closed: false
---
`#panel` / `#filter-panel` draw a tag as a `.panel-pill` button in two
different places: in the filter bar at the top of the panel, and inside a
row's own badge strip when the caller asked for pills there
(@rookery/todos' `badge-pills:`, `#filter-panel`'s `chip-pills:`). One rule
sizes both — `font-size: 0.85em`, `line-height: 1.4`, `padding: 0.1em 0.6em`
(`search.css` line 871).

At narrow widths @rookery/core now turns `#idea-row` into a card: the date
is a hat at the top-left corner, and the badge strip sits beside it on that
first line (see the bird this one depends on). At 0.85em with 1.4 leading a
pill is TALLER than the hat it shares the line with, so the first line is the
tallest thing in the row and the title under it reads as a caption. In a row
the pills want to be the small print next to the hat, the way a chip on a
note's hat is small print next to its id.

So: at narrow widths, a pill INSIDE A ROW gets smaller. The pills in the
filter bar do not change at any width.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/search.css only.

## Decisions already made — do not re-derive

**Only the row's pills shrink, and the selector is what enforces that.**
`[data-rookery="row-badges"] > .panel-pill` — a pill drawn as a badge is
always a direct child of @rookery/core's strip (`idea-row-body` in
`core/0.1.0/src/row.typ` emits the pills straight into that span). The
filter bar's pills live in `.panel-pills` and are a reader's primary tap
target on a phone; they must keep their current size. Do NOT write the rule
against a bare `.panel-pill` inside a media query.

**The pill stays a real button.** It is pressable — a tap filters the list —
so the shrink takes the font down and the vertical padding out, but keeps
`line-height` near 1.3 rather than collapsing the box to the glyphs. The
horizontal padding stays generous enough to read as a pill (0.45em against
0.6em). Do NOT reduce this to a bare label, do NOT drop the border or the
999px radius, and do NOT set `padding: 0` on both axes.

**`768px`, matching @rookery/core's row block** — that is the width at which
the row becomes a card and the strip moves up beside the hat, and this rule
exists only for that shape. NOT this file's own `40em` block (line 723),
which is about hiding the search modal's preview pane and has nothing to do
with a row.

**Where the rule goes.** Inside `@layer search` (opened at line 102), with
the pill it modifies rather than at the end of the file: immediately after
the `.panel-pill[aria-pressed="true"]` rule that closes at line 898, before
`.panel-count`. The file groups by object, not by breakpoint.

**No layer conflict to manage here.** `core.css` is unlayered and so beats
this file on any property both declare, but core's narrow block sizes only
`[data-rookery="row-badges"] > [data-rookery="tag"]` — its own chip element,
which a `.panel-pill` button is not (`panel.typ` line 244 explains why a
pill deliberately does not wear `idea-tag`). The two selectors never match
the same element, so this rule bites as written.

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.css`, after the
   `.panel-pill[aria-pressed="true"]` block (lines 894-898) and before the
   `.panel-count` rule, insert:

   ```css
   /* NARROW: A PILL IN A ROW IS SMALL PRINT. @rookery/core's narrow block
      makes `#idea-row` a card — the date a hat at the top-left corner, the
      badge strip beside it on that line, the title indented underneath — and
      at the size a pill takes in the filter bar it is taller than the hat it
      now sits next to, which makes the first line the tallest thing in the
      row and the title read as its caption.

      ONLY IN A ROW. The bar's own pills are the reader's primary tap target
      on a phone and keep their size at every width, which is why this hangs
      off core's badge strip rather than off `.panel-pill` alone.

      STILL A BUTTON: the leading stays near 1.3 and the horizontal padding
      near two thirds of the bar's, so the box keeps a pressable area and
      still reads as a pill rather than as a bare word. */
   @media (max-width: 768px) {
     [data-rookery="row-badges"] > .panel-pill {
       font-size: 0.72em;
       line-height: 1.3;
       padding: 0 0.45em;
     }
   }
   ```

## Do NOT

- Do NOT edit `core.css` or `todos.css`. Core's layout half is this bird's
  dep and already done; the urgency band's own narrow tuning is
  @rookery/todos'.
- Do NOT edit any `.typ` or `.js` file. `facet-pill` and `tag-pill`
  (`panel.typ` lines 245-274) emit exactly the markup this rule needs; no
  new class, no `badge-pills`-specific variant.
- Do NOT change the `.panel-pill` rule at line 871, the hover rule, or the
  `[aria-pressed="true"]` rule. Wide rows and the filter bar are untouched
  by this bird.
- Do NOT fold this into the existing `@media (max-width: 40em)` block at
  line 723. Different width, different reason; see above.
- Do NOT add a `--panel-pill-*` size variable. One narrow-width size, stated
  once, in the file that owns the pill.
- Do NOT document this in `readme.md`. No knob is added.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `just test` is green and `just parity` passes. Both are JS/Typst
   fixtures that read no stylesheet; a CSS-only change must leave them
   untouched and passing. Do not add a test — there is no CSS harness here.

2. `grep -c 'max-width: 768px' src/search.css` prints `1`, and
   `grep -c 'max-width: 40em' src/search.css` still prints `1` — the old
   block is intact.

3. `grep -n 'row-badges' src/search.css` returns exactly one line: this
   file had no rule naming core's badge strip before.

Eyeballing it in a real project is NOT part of this bird: `waterline`
resolves `@rookery` from this repo by git ref (`rookery/rheo.toml`,
`[packages.rookery] branch = "0.1.0"`), so an uncommitted edit here is
invisible to its build. Do not attempt to build `waterline` to verify.