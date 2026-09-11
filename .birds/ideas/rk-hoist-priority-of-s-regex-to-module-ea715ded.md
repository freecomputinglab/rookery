---
id: rk-hoist-priority-of-s-regex-to-module-ea715ded
short-id: ea7
title: Hoist priority-of's regex to module scope
priority: 4
labels:
- chore-todos-review
deps: []
closed: false
---
Hoist `priority-of`'s regex to module scope in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ

## The defect

`priority-of` (this file, lines 251-257) builds a fresh `regex(..)` object
on every single call:

```
#let priority-of(tags) = {
  let digits = regex("^[0-9]+$")
  let hits = tags.keys()
    .filter(k => k.starts-with("todo-p") and k.slice(6).match(digits) != none)
    .map(k => int(k.slice(6)))
  if hits.len() == 0 { 0 } else { calc.max(..hits) }
}
```

`priority-of` is called once per todo row inside `todos()`
(`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ`, line 38:
`priority: priority-of(tags),`, inside that function's per-row `.map(..)`).
So a rookery with N todos compiles the identical `regex("^[0-9]+$")` N
times over the course of one build, for a pattern that never changes. This
is the same defect category as `@rookery/search`'s tokenizer, which built
its regex once per token instead of once at module scope.

## Fix

Bind the regex once at module scope, the same way this file already binds
`TODO-KEY`, `TYPES`, `STATUSES`, `DEPS-KEY`, etc. at its top level.

## Steps

1. In `tags.typ`, directly above `#let priority-of(tags) = {` (currently
   line 251), add:
   ```
   // Matches a plain non-negative integer. Bound once here rather than
   // rebuilt inside `priority-of`, which runs once per todo in the site.
   #let _PRIORITY-DIGITS = regex("^[0-9]+$")

   ```
2. Inside `priority-of`, replace the line
   ```
   let digits = regex("^[0-9]+$")
   ```
   with
   ```
   let digits = _PRIORITY-DIGITS
   ```
   (Leaving the local name `digits` in place, rather than renaming every use
   of `digits` below it to `_PRIORITY-DIGITS`, keeps this a one-line change
   inside the function body.)

## Do NOT

- Do not touch the two other `regex(..)` call sites in this package:
  `search.typ` line 150 (inside `todos-search`'s `sync:` validation) and
  `todo.typ` line 238 (inside `epic`'s name validation). Both of those run
  once per widget call or once per epic-factory call, not once per todo row,
  so they are not the hot-path case this bird addresses.
- Do not change `priority-of`'s behavior or return value for any input.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before —
`/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ` asserts
`priority-of`'s results directly on several fixtures, so a mistake in this
change (e.g. a typo'd pattern) fails `just test` immediately.