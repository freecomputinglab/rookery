---
id: rk-format-a-row-date-once-in-todo-table-2f322ddd
short-id: 2f
title: Format a row date once in todo-table
priority: 4
labels:
- chore-todos-review
deps: []
closed: false
---
Format a row's date once instead of twice in `#todo-table`'s row renderer, in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ

## The defect

`_fmt-day` (this file, line 46) formats a `datetime` via `.display(..)`:

```
#let _fmt-day(d) = d.display("[day padding:none].[month padding:none].[year repr:last_two]")
```

Inside `todo-table`'s `draw` function (the `render:` fallback, currently
spanning lines 373-526), for the SAME row's SAME date `d`, `_fmt-day(d)` is
called TWICE on the markup (HTML) path:

- around line 449: `when: if d != none { _fmt-day(d) } else { pri-label },`
- around line 472, inside the `when-attrs:` dictionary:
  `"aria-label": _fmt-day(d) + ", " + phrase,`

`.display(..)` is not free, and this file's own comments elsewhere
(around lines 273-278, the `badge-pills:` parameter doc) describe
`#todo-table` explicitly as running "on a worklist of several hundred rows
carrying between one and six tags each" — so a per-row cost paid twice for
no reason is worth cutting.

## Steps

1. In the `draw` function, find where `phrase` is computed (currently just
   above the `idea-row-body(` call, around line 445-447):
   ```
   let phrase = if c != none { c.text } else if pri-band != none {
     "priority " + p.slice(1)
   } else { none }
   ```
   Immediately after that `let phrase = ...` block (still before the
   `idea-row-body(` call), add:
   ```
   let day = if d != none { _fmt-day(d) } else { none }
   ```

2. Replace the `when:` line (currently around line 449):
   ```
   when: if d != none { _fmt-day(d) } else { pri-label },
   ```
   with:
   ```
   when: if day != none { day } else { pri-label },
   ```

3. Replace the `"aria-label"` line inside `when-attrs:` (currently around
   line 472):
   ```
   "aria-label": _fmt-day(d) + ", " + phrase,
   ```
   with:
   ```
   "aria-label": day + ", " + phrase,
   ```
   This is safe with no extra `none`-guard needed: `when-attrs:` is only
   built when `phrase != none` (see the `when-attrs: if phrase == none { (:) }
   else { ... }` line just above it), and `phrase` is only ever non-`none`
   when either `c != none` (which requires `d != none`, since `c` is
   computed a few lines above as `if countdown and d != none and today != none
   { ... } else { none }`) or `pri-band != none` (which requires `d != none`,
   per the `pri-band` computation's own `d == none` check). So whenever this
   `"aria-label"` line runs, `d != none` already holds and `day` is
   therefore never `none` at that point.

## Do NOT

- Do not touch the paged/non-markup branch (the `if not _is-markup() { ... }`
  block, currently around lines 387-402) — it already calls `_fmt-day(d)`
  only once, inside `[#_fmt-day(d) — ]`.
- Do not touch `_iso(d)` (line 450) — it is already called only once, for
  the `iso:` argument.
- Do not change what is displayed anywhere — `day` must hold exactly the
  same string `_fmt-day(d)` already produced at both call sites.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before. `just check`'s
`./demo/rheo/check.sh` step prints a `todo-table` line summarizing rendered
rows (group counts, tag pills, row counts) — unchanged output there confirms
the date cell and its `aria-label` still read the same for every dated demo
row.