---
id: rk-repair-the-today-panel-row-pill-939c7b72
short-id: '93'
title: Repair the today-panel row-pill assertion
priority: 4
labels:
- fix-today-panel-row-pill
deps: []
closed: false
---
`just check` in `@rookery/todos` fails, and has been failing for some time, on a single
assertion:

```
today-panel: ['invoice', 'migrate', 'mirror', 'renew', 'ship']
FAIL: no today-panel row carries a tag pill
demo/rheo FAILED
```

The markup is correct. The assertion's regex is wrong, and it is wrong in a way that
makes it match NOTHING — so it does not merely misreport this one claim, it silently
switches off three assertions in a row.

Touches: todos/0.1.0/demo/rheo/check.sh

## Where it is, exactly

`/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/check.sh:267-271` gathers the pills
drawn inside each day-view row:

```python
row_pills = [
    p
    for r in today_rows
    for p in re.findall(r'<button type="button" class="panel-pill"[^>]*>', r)
]
```

That pattern requires the class attribute to be exactly `panel-pill` — the literal
closing quote comes immediately after `panel-pill`. The real markup carries a second
class:

```html
<button type="button" class="panel-pill idea-tag-frontend" data-panel-facet="tag" data-panel-value="frontend" aria-pressed="false">
```

so `re.findall` returns an empty list on every row, and `row_pills` is always `[]`.

## The markup is deliberate, so do NOT change it

The second class is written on purpose by `facet-pill` in the `search` package,
`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ:245-255`:

```typ
#let facet-pill(field, value, label: auto) = html.elem(
  "button",
  attrs: (
    type: "button",
    class: "panel-pill idea-tag-" + value,
    ...
```

and the comment directly above it at `search/0.1.0/src/panel.typ:233` states that
wearing `idea-tag-<value>` alongside `panel-pill` is the one line that gives the pill
its per-tag theming hook. `@rookery/todos` reaches it through
`todos/0.1.0/src/table.typ:29` (`#import "@rookery/search:0.1.0": facet-pill, panel`)
and emits it at `todos/0.1.0/src/table.typ:538`. Every layer here is behaving as
designed; the test is the only thing that is wrong.

## What the empty list silently disables

Three assertions read `row_pills`, and an empty list makes the first fail and the other
two vacuous:

1. `check.sh:272-273` — "no today-panel row carries a tag pill". This is the one that
   fails, and it fails for a false reason.
2. `check.sh:275-276` — a loop asserting every in-row pill ships `aria-pressed="false"`.
   Over an empty list it runs zero times and asserts nothing.
3. `check.sh:288` — the success line `row pills: {len(row_pills)} in today rows`, which
   would print `0` even on a correct build.

So the fix does not just turn one red assertion green: it restores coverage that has
been off.

## Steps

1. **Widen the class match** at `check.sh:270`. Replace:

   ```python
       for p in re.findall(r'<button type="button" class="panel-pill"[^>]*>', r)
   ```

   with:

   ```python
       for p in re.findall(r'<button type="button" class="panel-pill[^"]*"[^>]*>', r)
   ```

   `[^"]*` before the closing quote absorbs the ` idea-tag-<value>` suffix while still
   anchoring on `panel-pill` as the first class, so it cannot start matching some other
   button.

2. **Add a short comment above `row_pills` saying why the class is not matched
   exactly** — that a facet pill wears `idea-tag-<value>` beside `panel-pill` as its
   theming hook, so the attribute is matched by prefix rather than by equality. Without
   it the next reader tightens the pattern back and turns the block off again. Follow the
   repo's comment rule in `/home/lox/code/_fcl/rookery/CLAUDE.md`: present tense,
   describing the code as it stands, naming no bird, branch or history.

3. **Change nothing else in the file.** In particular, leave
   `check.sh:256-259` alone:

   ```python
   if any("panel-pill" in r for r in table_rows):
       note("a #todo-table row carries a panel-pill; badge-pills should default off")
   ```

   That one tests a plain substring, not the regex, so it is unaffected and already
   correct — it asserts the worklist draws no row pills, which is still true.

## Non-goals

- **Do not touch `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ`.** The
  `panel-pill idea-tag-<value>` class pair is the intended markup.
- **Do not touch `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`** or
  `src/today.typ`. No Typst source changes at all — `badge-pills: true` on the day view
  already works.
- **Do not touch the `search` package's JS test fixtures.** Several of them
  (`search/0.1.0/test/panelmulti.test.mjs:27`, `panelunion.test.mjs:27`, and others)
  hand-write `class="panel-pill"` with no `idea-tag-` class. They are simplified fixtures
  for `panel.js`, which selects on `.panel-pill` and is indifferent to extra classes, so
  they are not broken and are not this bird's business.
- **Do not rewrite the block to use an HTML parser.** This file greps on purpose —
  `check.sh:4-6` says so, and the repo's CI has no parser dependency to reach for.
- **Do not add new assertions.** Restoring the three that exist is the whole change.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just check` exits zero and prints `demo/rheo OK`. This assertion is currently the
   only failing one in the file, so a green run means the fix landed and broke nothing.
2. That run prints a line of the shape `row pills: N in today rows, none in #todo-table
   rows` with **N greater than zero**. At the time of writing the demo yields `9`; treat
   a non-zero count as the pass condition rather than that exact number, since it moves
   whenever a todo is added to the demo.
3. The same run still prints
   `today-panel: ['invoice', 'migrate', 'mirror', 'renew', 'ship']`.
4. Confirm the fix is load-bearing: temporarily put the old pattern back at
   `check.sh:270`, run `just check`, and confirm it FAILS with
   `FAIL: no today-panel row carries a tag pill`. Restore the new pattern and confirm
   `just check` passes again.
5. `just test` and `just test-js` still pass unchanged — `units OK` and 35 passing JS
   tests. Neither reads this file, so a failure in either means something outside the
   bird's scope was edited.