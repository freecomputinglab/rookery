---
id: rk-import-timeline-s-normalize-tags-in-cb3e93ab
short-id: cb3
title: Import timeline's normalize-tags in todos
priority: 1
labels:
- chore-timeline-api
deps: []
closed: true
---
Touches: todos/0.1.0/src/tags.typ

## Background

`todos/0.1.0/src/tags.typ:111-121` defines a private `_norm-tags-local(v)`,
called once at `todos/0.1.0/src/tags.typ:240`. Its own comment (lines
102-110) explains why it was written as a local copy rather than an import:

> A local copy of rookery's four-form tag normalizer, so this module stays a
> pure function of its arguments and the merge below cannot depend on which
> form the caller wrote. Deliberately NOT an import of rookery's private
> `_norm-tags`: this is six lines, and a package reaching into another
> package's underscore names to save them is a dependency on an internal
> that can move without notice.

That reasoning no longer holds: `timeline/0.1.0/src/fragment.typ`'s
`_norm-tags` was renamed to public `normalize-tags` earlier today (it has
the identical four-branch shape: `none`, a string, an array, a dictionary),
so importing it is no longer "reaching into an underscore name that can move
without notice" — it's importing a stable, exported name. `todos` already
imports `@rookery/timeline:0.1.0` at `todos/0.1.0/src/tags.typ:37` (currently
`CLOSED-STAGE, SCHEDULED-STAGE, has-stage, stage-date`), so this needs no new
package dependency — `todos -> timeline` is already a declared edge in this
repo's `CLAUDE.md` dependency graph.

## Fix

1. At `todos/0.1.0/src/tags.typ:37`, add `normalize-tags` to the existing
   import list:
   ```typ
   #import "@rookery/timeline:0.1.0": CLOSED-STAGE, SCHEDULED-STAGE, has-stage, normalize-tags, stage-date
   ```
2. Delete the `_norm-tags-local` definition and its two comment blocks
   (`todos/0.1.0/src/tags.typ:102-121`, adjust exact line range to match
   what's actually there once you've made edit 1 — re-`rg -n
   '_norm-tags-local'` to find the current lines before deleting).
3. Replace the one call site at line 240, `out + _norm-tags-local(tags)`,
   with `out + normalize-tags(tags)`.

## Do NOT

- Do not touch `slipshow/0.1.0/src/tags.typ`, which has its own, separate
  `_norm-tags-local` with the identical shape and comment. `slipshow`
  currently imports only `@rookery/core` (see `slipshow/0.1.0/typst.toml`
  and this repo's `CLAUDE.md` dependency graph: `slipshow -> core`, not
  `timeline`). Importing `normalize-tags` there would add a NEW
  `slipshow -> timeline` edge to that graph, which this repo's own
  `CLAUDE.md` treats as a deliberate decision each existing edge required
  ("That edge was forbidden until it was needed") — not something to add as
  a side effect of a tag-normalizer dedup. Leave `slipshow` as-is.
- Do not touch `core/0.1.0/src/pure.typ`'s own `_norm-tags` — that is a
  distinct, differently-shaped normalizer core owns (a four-shape
  normalizer with different semantics), not the same function.
- Do not rename or change `normalize-tags`'s signature in `timeline` —
  only change how `todos` reaches it.

## VERIFY

1. `rg -n '_norm-tags-local' todos/0.1.0/src/tags.typ` — must return
   nothing after the fix.
2. `cd todos/0.1.0 && just test` — must print `units OK`.
3. `cd todos/0.1.0 && just check` — must print `demo/rheo OK`.
4. `rg -n 'normalize-tags' todos/0.1.0/src/tags.typ` — must show the new
   import and the new call site.
5. `bd status <this-bird's-id>` — `in_flight` until you alight, `retired`
   after.