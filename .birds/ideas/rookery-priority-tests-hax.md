---
id: rookery-priority-tests-hax
title: Move the unit tests onto the new priority scale
priority: 3
labels:
- priority-reversal
- type:task
deps:
- blocked-by:rookery-priority-rung-47g
- blocked-by:rookery-priority-sort-3ta
closed: false
---
Bring `@rookery/todos`' unit tests onto the reversed, unbounded, default-0 priority scale introduced by bead `rookery-priority-scale-48n` and the rank-relative ramp from bead `rookery-priority-rung-47g`, and add the cases the new scale makes possible.

File: `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ`.

The contract being tested, restated in full so you need no other file:
- `priority:` is a non-negative integer with no upper bound. Bigger is more important. A float (including `float.inf`) or a negative integer panics.
- `todo-tags(priority: n)` emits the tag key `todo-p<n>` only when `n > 0`. `priority: 0` emits no priority key.
- `priority-of(tags)` decodes the largest `todo-p<digits>` key present, and returns `0` when there is none.
- `priority-rung(p, scale, rungs: 3)` returns `0`, `1`, `2` or `none`, where `scale` is the distinct in-use priorities largest-first, `none` is returned for `p <= 0` or a `p` absent from `scale`, and the index is clamped at `rungs - 1`.
- Sibling and list ordering is by priority DESCENDING, then name ascending; priority 0 therefore sorts last.

Steps:
1. Lines 20-25: `todo-tags(priority: 1).keys()` still yields `("todo", "todo-p1")` and needs no change, but `todo-tags(priority: 0).keys()` at line 21 currently asserts `("todo", "todo-p0")` and must become `("todo",)`.
2. Line 59 (`todo-tags(priority: 1, tags: ("todo-p1": "mine"))`) is unaffected; leave it.
3. Lines 66-67: `priority-of(todo-tags(priority: 3))` stays `3`; `priority-of(todo-tags())` becomes `0`, not `none`.
4. Add assertions for the new behaviour: `priority-of(todo-tags(priority: 12))` is `12`; `priority-of(("todo-p2": none, "todo-p9": none))` is `9`; `priority-of(("todo": none, "todo-closed": none, "todo-bug": none))` is `0`.
5. Add `priority-rung` assertions: `priority-rung(7, (7, 2, 1))` is `0`, `priority-rung(2, (7, 2, 1))` is `1`, `priority-rung(1, (7, 2, 1))` is `2`, `priority-rung(1, (9, 7, 5, 3, 1))` is `2`, `priority-rung(0, (7, 2))` is `none`, `priority-rung(4, (7, 2))` is `none`.
6. Lines 299-303 and 384: the `rowp` helper takes `priority: none` as its default. Change that default to `0`, since `none` is no longer a value the pipeline produces.
7. Lines 299-303: the `tied` fixture is `rowp("lo", priority: 3)`, `rowp("hi", priority: 1)`, `rowp("none-pri")`. On the new scale those names are backwards. Renumber so the intent survives: make `hi` the larger number and `lo` the smaller, keep `none-pri` unprioritised, and update the assertion below it to expect `hi`, then `lo`, then `none-pri`. Fix the comment at line 299 ("priority ascending, then name, unprioritised last") to say descending.
8. Line 335 and line 384: the same two fixes for the sibling-ordering comment and the `samelayer` fixture, whose node is literally named `p3`. Rename it and renumber it so the higher-priority node sorts first.

Do NOT add tests for a compatibility path with the old scale — there is none. Do NOT change any test unrelated to priority.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `rg -n 'priority: none' test/units.typ` returns nothing.
2. The test file compiles clean with no assertion failure — run it the way this repo's `Justfile` runs it (`just test` if that recipe exists, otherwise `typst compile test/units.typ`, and if neither works, `rheo compile` the demo project and report which command you used).