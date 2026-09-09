---
id: rookery-priority-css-7v3
title: Restyle the priority ramp onto rung classes
priority: 3
labels:
- priority-reversal
- type:task
deps:
- blocked-by:rookery-priority-rung-47g
closed: false
---
`@rookery/todos`' stylesheet paints the priority ramp with absolute-number selectors, which the unbounded scale from bead `rookery-priority-scale-48n` makes meaningless, and which bead `rookery-priority-rung-47g` has already stopped the Typst side from emitting. Move the stylesheet onto the rung classes.

File: `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css`.

The rung contract, restated so you need nothing else: a todo's rung is `0`, `1` or `2` — 0 is the most important priority in use on the site, 2 the third-most-important-or-lower. It arrives as the class `todo-when-rung-<i>` on the date cell, in place of the old `todo-when-p<n>`. A todo with priority 0 gets no rung and no class. The three rungs take the SAME three hues the old p0/p1/p2 rules took, in the same order, so the palette is unchanged — only what selects it changes.

Steps:
1. Lines 305-323: rename the three wash rules `[data-rookery="row-when"].todo-when-p0` / `.todo-when-p1` / `.todo-when-p2` to `.todo-when-rung-0` / `.todo-when-rung-1` / `.todo-when-rung-2`, keeping each rule's body exactly as it is.
2. Rename the per-band override custom properties to match: `--todo-band-p0` becomes `--todo-band-rung-0`, and likewise for 1 and 2. These are the names a consuming site sets, so they must move together with the selectors.
3. Lines 343-353: the same rename for the three ink rules `.todo-when-priority.todo-when-p<n>`, and for the `--todo-pri-fg-p<n>` overrides, which become `--todo-pri-fg-rung-<n>`.
4. Lines 233-241: the two weight rules select on `data-rookery-tags~="todo-p0"` and `~="todo-p1"`. Those attribute values are the RAW tag, which is still `todo-p<n>` and still unbounded, so an absolute selector there is now wrong for a different reason — it would bold a priority-0 row on a site whose real top priority is 7. Change both to select on the rung class instead: the row's title should be `font-weight: 700` at rung 0 and `600` at rung 1. This requires the rung to reach the ROW, not just the date cell — pass it through as a class on the row element in `panel.typ`'s `row-class`, alongside the tag classes already there. If wiring that turns out to need more than a class added to an existing list, drop step 4, leave those two rules keyed on `todo-p0`/`todo-p1` for now, and say so in the commit message rather than inventing a mechanism.
5. Update the long comment at lines 242-266. It says "SEVEN BANDS, ONE RAMP ... three from PRIORITY ... p3 and p4 get no rule". The true statement now: four bands from the countdown, three from priority, where the three priority bands are the three highest priorities in use on the site rather than fixed numbers, and a todo below them (or unprioritised) gets no rule. Keep the existing reasoning about the ramp being three steps deep on purpose and about the washes being lighter than the countdown bands of the same hue.
6. Update the comment at lines 326-335 the same way, in particular the sentence naming `--todo-pri-fg-p<n>`.

Do NOT change any colour value, any `color-mix` percentage, or the `--rookery-heat-*` fallbacks. Do NOT add rules for a fourth or fifth rung. Do NOT touch the countdown bands (`todo-when-overdue`, `-urgent`, `-soon`, `-later`).

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `rg -n 'todo-when-p[0-9]|todo-band-p[0-9]|todo-pri-fg-p[0-9]' src/` returns nothing.
2. `just build` succeeds and `cd demo/rheo && rheo compile` succeeds.
3. In a browser on the built demo page, the undated todo with the site's highest priority still shows a red `P<n>` in the date column, the next one down orange, and the third yellow — the same three colours as before the change.