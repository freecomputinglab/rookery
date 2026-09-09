---
id: rookery-priority-rung-47g
title: Derive a rank-relative priority rung and band the panel with it
priority: 4
labels:
- priority-reversal
- type:feature
deps:
- blocked-by:rookery-priority-scale-48n
closed: false
---
The priority colour ramp in `@rookery/todos` is keyed to ABSOLUTE numbers: `p0` takes the urgent red, `p1` soon-orange, `p2` later-yellow, and `p3`/`p4` get nothing. That only works because the old scale was capped at 0-4. Bead `rookery-priority-scale-48n` removes the cap, so an absolute key is no longer possible — a site using priorities 0, 2 and 7 has no rung called `p0`.

Replace it with a RANK-RELATIVE ramp: a todo's rung is decided by where its priority sits among the priorities actually in use, not by the number itself. With three rungs and a site using 0, 2, 7: 7 is rung 0 (hottest), 2 is rung 1, and 0 gets no rung at all. With a site using 0 and 1: 1 is rung 0, 0 gets none. Priority 0 NEVER takes a rung — it is the default, meaning unprioritised, and a colour on every row says nothing.

This bead adds the derivation and switches `#filter-panel` over to it. Restyling the stylesheet is the separate bead `rookery-priority-css-7v3` and is NOT in scope here.

All paths under `/home/lox/code/_fcl/rookery/todos/0.1.0/`.

Steps:
1. Add a PURE function `priority-rung(p, scale, rungs: 3)` to `src/tags.typ`, beside `priority-of`. `scale` is an array of the distinct priorities in use, hottest (largest) first. Return `none` when `p == none` or `p <= 0`; otherwise find `p`'s index in `scale` and return `calc.min(index, rungs - 1)`, or `none` if `p` is not in `scale`. Clamping at `rungs - 1` is what makes an unbounded scale land on a fixed ramp: everything past the third-hottest priority shares the coolest rung. Keep it pure and parameterised — the caller supplies both `scale` and `rungs`, because the consuming site `/home/lox/code/waterline` renders a different row set with a five-rung ramp of its own.
2. Add a CONTEXT function `priority-scale()` to `src/graph.typ`, beside `todos()`. It returns `todos().map(r => r.priority).filter(p => p > 0).dedup().sorted().rev()` — the distinct in-use priorities, largest first. It goes in graph.typ rather than tags.typ because it needs `todos()`, and tags.typ must not depend on graph.typ.
3. No export step is needed: the entry point `src/lib.typ` already does `#import "tags.typ": *` (line 20) and `#import "graph.typ": *` (line 22), so both new names leave the package automatically. Confirm this rather than adding an explicit export list.
4. In `src/panel.typ`, compute the scale once. The panel's row-building already sits inside a context block; call `priority-scale()` there and close over the result — do NOT call it per row.
5. panel.typ:327 currently projects the facet value as `if r.priority == none { none } else { "p" + str(r.priority) }`. Keep projecting the RAW number, since a `p7` pill is a true and filterable fact, but the `none` case is now `r.priority == 0`: `if r.priority == 0 { none } else { "p" + str(r.priority) }`. Update the comment above it accordingly.
6. panel.typ:393-396 computes `pri-band` by testing `p not in ("p0", "p1", "p2")` against the projected STRING. Replace that with the rung: `let rung = priority-rung(r.priority, scale)`, and `pri-band` is `none` when `band != none` or `d == none` or `rung == none`, else `"todo-when-rung-" + str(rung)`.
7. panel.typ:401-403 computes `pri-label` the same way. Replace the string test with `rung == none`, and keep the label itself as the raw priority: `"P" + str(r.priority)` (so a priority-7 todo reads `P7`). Update the comment at 397-400, which currently promises `P0` and "only at the ramp's three rungs".
8. panel.typ:405-408 builds the tooltip phrase as `"priority " + p.slice(1)`. Make it `"priority " + str(r.priority)`.
9. panel.typ:420-425 sets `when-class`. The `pri-band` branch already carries the right string from step 6. The `pri-label` branch must become `("todo-when-priority", "todo-when-rung-" + str(rung))`.
10. Rewrite the `undated-priority:` parameter documentation at panel.typ:249-261. It currently explains the p0/p1/p2 rungs and says an undated p3 or p4 keeps an empty cell. The new statement: an undated row shows its priority in the date cell when its priority earns a rung, i.e. when it is one of the three highest priorities in use on the site; an unprioritised row (priority 0) and any priority below the ramp's three rungs keep an empty cell, and still sort below the prioritised ones.

Do NOT emit any `todo-when-p<n>` class any more — the rung classes replace them entirely. Do NOT change `src/todos.js`, which puts the raw `idea-tag-todo-p<n>` class on a graph node; that is a tag class, not a ramp rung, and it stays raw and unbounded. Do NOT change the number of rungs from the default 3 in this package.

Uncertainty to check while implementing: `panel.typ` builds `rows` and `draw` in the same scope, but confirm that scope is inside the `#context` that `#filter-panel` opens before calling `priority-scale()` there. If it is not, hoist the call to the nearest enclosing context block and pass `scale` down — do not wrap `draw` in a second `#context`.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `priority-rung(7, (7, 2, 1))` is `0`; `priority-rung(2, (7, 2, 1))` is `1`; `priority-rung(1, (7, 2, 1))` is `2`; `priority-rung(1, (9, 7, 5, 3, 1))` is `2` (clamped); `priority-rung(0, (7, 2))` is `none`.
2. `just build` succeeds and `cd demo/rheo && rheo compile` succeeds.
3. `rg -n 'todo-when-p[0-9]' src/*.typ` returns nothing.
4. On the built demo page, an undated todo with the site's highest priority carries `class="... todo-when-priority todo-when-rung-0"` on its date cell and the cell reads `P<its number>`.