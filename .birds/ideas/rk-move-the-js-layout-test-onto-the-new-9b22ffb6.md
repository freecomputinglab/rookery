---
id: rk-move-the-js-layout-test-onto-the-new-9b22ffb6
short-id: 9b
title: Move the JS layout test onto the new priority scale
priority: 3
labels:
- priority-reversal
- type:task
deps: []
closed: false
---
The JS half of `@rookery/todos` sorts graph rows in `src/layout.js`'s `rows()`, and its unit test still encodes the OLD priority scale, so `just test-js` is RED: 27 tests, 26 pass, 1 fail.

File: `/home/lox/code/_fcl/rookery/todos/0.1.0/test/layout.test.mjs`, the single test at lines 40-53, titled `"rows order by priority then name, unprioritised last"`.

The contract it must now test, restated in full so you need no other file:
- Priority is a non-negative integer with no upper bound. BIGGER IS MORE IMPORTANT. There is no `none`/`undefined` priority in the Typst pipeline any more; an unprioritised todo is priority 0, and `rows()` still defaults a missing field with `?? 0`.
- `rows()` orders within a layer by priority DESCENDING, then by name ascending. Priority 0 therefore sorts last.
- This test is the JS half of a parity pair: `_rank` in `src/graph.typ` is its Typst counterpart and already carries the same ordering.

The fixture is `zebra` (priority 0), `apple` (no priority field at all), `mango` (priority 0), `kiwi` (priority 2). Under the new scale the correct order is `kiwi` first (it is the only node above 0), then `apple`, `mango`, `zebra` — the three priority-0 nodes alphabetically. The test currently asserts `mango, zebra, kiwi, apple`.

Steps:
1. Rewrite the assertion at lines 47-52 to expect `["kiwi", "apple", "mango", "zebra"]`.
2. Give the fixture more to say now that the scale is unbounded: add a node with a priority well above the old 0-4 cap, e.g. `n("ox", { priority: 12 })`, and put it first in the expected order. Keep `apple` with no priority field, since defaulting a missing one is exactly what `?? 0` is for.
3. Rename the test so the title states the present contract: priority descending, then name, with priority 0 last.

Do NOT change `src/layout.js` — its ordering is already correct and landed. Do NOT touch `test/units.typ`, which is the Typst half and has its own bird. Do NOT add a compatibility case for the old ascending order.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `just test-js` passes — the run reports `fail 0`.
2. `rg -n "priority" test/layout.test.mjs` shows no expectation that a smaller number sorts first.