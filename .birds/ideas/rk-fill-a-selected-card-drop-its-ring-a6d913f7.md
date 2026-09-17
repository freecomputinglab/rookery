---
id: rk-fill-a-selected-card-drop-its-ring-a6d913f7
short-id: a6d
title: Fill a selected card, drop its ring
priority: 3
labels:
- feat-pinboard-select-fill
deps: []
closed: true
---
A card selected by a marquee drag across the board currently wears a ring —
a 2px `outline` offset 2px from the card's edge — and is otherwise
untouched, so a selection reads as an extra border drawn around an
unchanged card. It should instead read as a filled block: the note window's
own background goes to the project's border colour, and the ring disappears
entirely.

This is a CSS-only change to one stylesheet. No JavaScript, no Typst, no
new package parameter.

Touches: /home/lox/code/_fcl/rookery/pinboard/0.1.0/src/pinboard.css

## Decisions already made — do not re-derive

**The selection flag is `data-selected` on the card.** `src/select.js`
sets it with `card.toggleAttribute("data-selected", selected)` (line 51-53)
on the `<article class="pinboard-card">` element, and nothing else in the
package styles that attribute. Do not change `select.js` — the flag, where
it lands, and when it is set and cleared are all already correct.

**The fill goes on the WINDOW, not on the card.** This is the one decision
most likely to be got wrong, so it is spelled out. The colour wanted is
`--idea-border-color`, which `@rookery/core` writes as an *inline style on
the window element itself*, not on the card. The real emitted DOM of one
card is:

```html
<article class="pinboard-card" data-pinboard-id="idea:foo"><figure><div
  class="idea-window" data-rookery="window"
  style="--idea-link-color: ...; --idea-id-color: #54655a; --idea-border-color: #26637f">
```

A CSS custom property reaches an element's descendants and never its
ancestors. `.pinboard-card` is the window's *ancestor*, so a rule written as
`.pinboard-card[data-selected] { background: var(--idea-border-color, ...) }`
cannot see the project's colour and silently resolves the chain to its last
fallback — the hardcoded `rgba(128, 0, 255, 0.12)` purple. It would look
like it worked and be the wrong colour in every project.

So the selector must descend to the window. That DOM shape is not a guess:
`demo/rheo/check.sh` line 20 already asserts it, matching
`data-pinboard-id="[^"]*"><figure><div [^>]*--idea-border-color`.

**Select core's internals by `[data-rookery="..."]`, not by class.** Both
exist on the element, but `core.css` styles by the attribute and
`pinboard.css` already follows that at line 85
(`.pinboard-card [data-rookery="window-body"]`). Stay consistent with the
file.

**Mirror core's own two-level fallback chain.** Every `core.css` rule that
reads this colour writes it as
`var(--idea-border-color, var(--idea-link-color, rgba(128, 0, 255, 0.12)))`
(for example lines 535 and 739). `border-color` has no default of its own
and falls back to `link-color` — see the note at `core.css` line 77. Use
the full chain, not a bare `var(--idea-border-color)`.

**The text has to flip to a light colour, and needs TWO rules, because of
inline-style precedence.** Every border colour a project actually sets is
dark — `#26637f` in the `waterline` project, `#3366ff` in this package's own
`demo/rheo/content/index.typ` line 7 — so the body's ordinary dark ink and,
worse, the permalink hat's grey would sit on a dark fill. The hat's grey is
`--idea-id-color`, consumed at `core.css` line 105, and in `waterline` it is
`#54655a` against a `#26637f` fill: about 1.4:1, unreadable.

Core publishes no foreground variable to pair with the border colour —
there is no `--idea-*-foreground` anywhere in the package. So this
introduces one pinboard-local knob, `--pinboard-select-fg`, defaulting to
`#fff`, matching how `--pinboard-select` is already used
(`var(--pinboard-select, currentColor)`) — a bare `var()` with a fallback
and no definition, left for a consuming project to override.

Two rules are needed rather than one because **core emits
`--idea-id-color` as an inline style on the window element**, and an inline
declaration beats a stylesheet rule for the same property on the same
element. Redefining `--idea-id-color` on `[data-rookery="window"]` would
therefore do nothing. Redefine it one level down instead, on
`[data-rookery="window-details"]`, where the inline value merely inherits
and a stylesheet rule wins normally. `background` and `color` are safe on
the window itself, since the inline style sets only custom properties.

## Steps

1. In `/home/lox/code/_fcl/rookery/pinboard/0.1.0/src/pinboard.css`, delete
   lines 90-98 entirely — the comment beginning `/* A selected card is
   marked for the group drag` together with the whole
   `.pinboard-card[data-selected]` block, whose three declarations are
   `outline`, `outline-offset` and `border-radius`. All three go; the
   `border-radius` existed only to round the outline and has nothing left to
   round.

2. In their place write the two rules below. The comment replaces the old
   one, which argued for a ring and now documents the opposite decision.

   ```css
   /* A selected card is marked for the group drag a press on it will
      start. A fill rather than a ring: the window's ground goes to the
      project's own border colour, so a selection reads as a block of that
      hue and the left rule merges into it.

      The fill lands on the window and not on the card because core writes
      `--idea-border-color` as an inline style on the window, and a custom
      property reaches descendants only — a rule on the card, which is that
      window's ancestor, would resolve the chain to its final fallback
      instead of the colour the project set. */
   .pinboard-card[data-selected] [data-rookery="window"] {
     background: var(--idea-border-color, var(--idea-link-color, rgba(128, 0, 255, 0.12)));
     color: var(--pinboard-select-fg, #fff);
   }

   /* The hat's id and an idea's date carry their own colours, which core
      emits inline on the window — where a stylesheet cannot outrank them.
      One level down it can, and a grey minted to read against the page
      would otherwise sit unreadable on the fill. */
   .pinboard-card[data-selected] [data-rookery="window-details"] {
     --idea-id-color: var(--pinboard-select-fg, #fff);
     --idea-date-color: var(--pinboard-select-fg, #fff);
   }
   ```

3. Leave the `.pinboard-marquee` rule that follows (lines 100-112, the
   comment and block) exactly as it is. The rubber band is a separate
   transient `<div>` that `select.js` appends for the duration of the drag
   and removes at the end; it is the drag's own affordance, not the card's
   selected state, and it keeps its dashed `--pinboard-select` border and
   8% tint.

## Do NOT

- Do NOT edit `src/select.js`, `src/drag.js`, `src/board.typ`, or any other
  file. One stylesheet changes.
- Do NOT restyle the marquee, or unselected cards, or the card's hover tint.
- Do NOT add a parameter to `#pinboard()` or a Typst-side theme key for the
  selected colour. The border colour a project already sets is the input.
- Do NOT add a `--pinboard-select-fg` section to `readme.md`. The existing
  `--pinboard-select` knob is documented only in this stylesheet's own
  comments, and one package with two conventions is worse than either.
- Do NOT chase the semi-transparent tints core paints inside a window — the
  link tint at 0.14 alpha and the fold tint at 0.07 will now sit over a dark
  fill and read faintly. That is accepted here, not a thing to fix
  per-element in this change.
- Do NOT run `just build` expecting it to matter for the CSS. `typst.toml`
  line 16 sets `css_stylesheet = "src/pinboard.css"`, pointing at the source
  file directly; only `dist/lib.js` is bundled, and it carries JS only.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/pinboard/0.1.0`:

1. `just test-js` is green. These are the geometry, drag, collapse and store
   tests; none of them reads a class or a stylesheet, so a CSS-only change
   must leave all of them passing untouched. Do not add a test here — there
   is no CSS harness in this package to add one to.

2. `just check` ends by printing `demo/rheo OK`. This builds, compiles
   `demo/rheo` and runs its assertions, including the one at `check.sh` line
   20 that every card still carries the project's `--idea-border-color` on
   the window inside its `<figure>` — the shape the new selector depends on.

3. `grep -n 'outline' src/pinboard.css` returns nothing. The ring is gone.

4. `grep -c 'data-selected' src/pinboard.css` prints `2` — one selector per
   new rule.