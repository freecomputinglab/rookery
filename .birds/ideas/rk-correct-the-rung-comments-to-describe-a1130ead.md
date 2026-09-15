---
id: rk-correct-the-rung-comments-to-describe-a1130ead
short-id: a1
title: Correct the rung comments to describe the clamp
priority: 3
labels:
- priority-reversal
- type:task
deps: []
closed: true
---
Three comments in `@rookery/todos` describe a rung rule the code does not implement: they say a priority below the ramp's three rungs earns no band and keeps an empty cell. `priority-rung` CLAMPS instead — `calc.min(index-in-scale, rungs - 1)` — so every priority in use above 0 earns a rung, and everything from the third-hottest downward shares rung 2. Only priority 0 (unprioritised) and a priority absent from the scale get `none`.

Verified on the built demo, whose scale is `(9, 6, 4, 3, 2, 1)`: the priority-3 row is the FOURTH distinct priority and still renders `class="idea-row-when todo-when-priority todo-when-rung-2"` with the cell reading `P3`. A blank cell for it would be the documented behaviour and is not what happens.

The readme already states the true rule ("every priority beyond those three rungs shares the coolest one"), so this bird is only about the three code comments.

Files and exact text to fix, all under `/home/lox/code/_fcl/rookery/todos/0.1.0/`:

1. `src/panel.typ`, the `undated-priority:` parameter doc, lines 259-263. It currently ends:

   ```
   // A ROW EARNS A RUNG when its priority is among the THREE HIGHEST priorities in use
   // on the site — the ramp's fixed three steps, placed RELATIVE to the scale rather
   // than to an absolute number. An unprioritised row (priority 0) and any priority
   // below those three rungs keep an empty cell, though they still sort by their own
   // priority number, ahead of an unprioritised row.
   ```

   Rewrite the last sentence so it says what the code does: a row's rung is its priority's index among the priorities in use, clamped at the coolest of the three, so every prioritised row earns a rung and everything from the third-hottest priority downward shares the coolest one. Only an unprioritised row (priority 0) keeps an empty cell. Keep the first sentence's point that the ramp is three fixed steps placed relative to the scale.

2. `src/panel.typ`, the `pri-label` comment, lines 405-409. It currently says "only where the priority earns a rung, so an undated row below the ramp's three rungs (or unprioritised) leaves the column blank as before". Fix it the same way: the column is blank for an unprioritised row.

3. `src/todos.css`, lines 251-254 in the "SEVEN BANDS, ONE RAMP" comment. It currently says "The three priority bands are the THREE HIGHEST PRIORITIES IN USE ON THE SITE, not fixed numbers — a todo below them, or unprioritised, gets no rule". Fix: the three bands are the three rungs; a priority's rung is its index among the priorities in use, clamped, so the third band covers the third-hottest priority and everything below it, and only an unprioritised todo gets no rule. Keep the existing reasoning about a ramp of three having three steps.

Follow this repo's comment rule (`/home/lox/code/_fcl/rookery/CLAUDE.md`): describe the PRESENT. Do not write that the behaviour "changed", do not say "no longer"/"any more"/"used to", do not name a bird or a version. Note that the phrase "as before" in step 2's comment is also a reference to history and should go.

Do NOT change any code — this bird touches comments only. Do NOT change `priority-rung`'s clamp to match the old prose: the clamp is the intended design, since an unbounded scale must land on a fixed ramp. Do NOT edit the readme, which is already correct.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `rg -n 'below those three rungs|below the ramp|gets no rule|as before' src/panel.typ src/todos.css` returns nothing.
2. `just build` succeeds and `cd demo/rheo && rheo compile .` succeeds — proving the comment edits broke no syntax.
3. `git`-free sanity check that no code line changed: `jj diff --stat` shows only `src/panel.typ` and `src/todos.css`, and reading the diff shows every changed line begins with a comment marker (`//` or is inside the `/* ... */` block).