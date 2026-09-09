---
id: rk-move-the-demo-output-check-onto-the-9bc9eea2
short-id: 9bc
title: Move the demo output check onto the rung classes
priority: 3
labels:
- priority-reversal
- type:task
deps: []
closed: false
---
The `@rookery/todos` demo asserts on its own built HTML, and two of those assertions still speak the old priority vocabulary, so `just check` is RED with:

```
FAIL: a priority label carries no rung class: [' todo-when-priority todo-when-rung-2', ' todo-when-priority todo-when-rung-2', ' todo-when-priority todo-when-rung-2']
demo/rheo FAILED
```

File: `/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/check.sh`. Nothing else is in scope.

The contract being asserted, restated in full so you need no other file:
- An undated row in `#filter-panel` shows its priority in the date cell when that priority earns a RUNG. The cell carries `todo-when-priority` plus `todo-when-rung-<i>`, where `i` is 0, 1 or 2 — 0 for the highest priority in use on the site, 2 for the third-highest-or-lower. A priority-0 (unprioritised) row earns no rung and no label.
- The RAW tag key is unbounded and independent of the ramp: a priority-7 todo carries the tag `todo-p7`, a priority-12 one `todo-p12`. Rungs are a display ramp; tags are the stored fact.

Steps:

1. Line 186 currently reads:

   ```python
   elif not all(re.search(r"todo-when-p[012]\b", w) for w in labels):
   ```

   Change the pattern to `r"todo-when-rung-[012]\b"`. The failure message on line 187 already reads "a priority label carries no rung class" and needs no change.

2. Line 192 currently reads:

   ```python
   if "todo-when-priority" in r and re.search(r'data-rookery-tags="[^"]*\bp[0-9]\b', r):
   ```

   It catches a row that shows a priority label AND repeats it as a badge. The pattern matches a SINGLE digit only, so it misses `todo-p12` on an unbounded scale. Change `\bp[0-9]\b` to `\bp[0-9]+\b`.

3. Before changing line 192, confirm the assertion can fire at all: check whether a `<li class="panel-row ...">` in the built `demo/rheo/build/html/index.html` actually carries a `data-rookery-tags` attribute. If it does not, the check is dead against that markup — say so in your report and in the bank message, and leave the line as corrected in step 2 rather than deleting it.

4. The comment at lines 176-179 says an undated row "must carry its priority as a label at one of the ramp's rungs", which is true as written. Leave it unless it names an absolute priority number.

Do NOT change any other assertion in `check.sh`, do not touch `demo/rheo/content/`, and do not touch anything under `src/`. If `just check` still fails after these two changes, the remaining failure is NOT yours to fix: report the exact message and stop.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `just check` passes — it prints the `filter-panel: ...` summary line and exits 0.
2. `rg -n 'todo-when-p[0-9]' demo/rheo/check.sh` returns nothing.