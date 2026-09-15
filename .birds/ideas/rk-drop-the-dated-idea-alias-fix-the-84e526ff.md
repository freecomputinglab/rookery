---
id: rk-drop-the-dated-idea-alias-fix-the-84e526ff
short-id: '84'
title: Drop the dated-idea alias, fix the readme's first example
priority: 2
labels:
- chore-timeline-api
deps: []
closed: false
---
Two small things in the package's front door, both of which mislead a reader
arriving cold.

`dated-idea` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ:112`) is a
bare alias of `idea` (line 98). Two exported names for one function, and the
readme's own migration table lists it as a thing that "keeps its name" — from a
release where it was the ONLY way to get a dated `#idea`, which it no longer is.
Nothing outside this package uses it: the only references are
`timeline/0.1.0/test/units.typ` and two comments in `todos/0.1.0/src/`.

The readme's opening example
(`/home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md:6-13`) imports `dates`, a
name that does not exist in this package, and then calls `entries` — so the first
code block a reader sees cannot compile.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ

## Steps

1. Delete `#let dated-idea = idea` and its one-line comment from `lib.typ:111-112`.
2. Delete the `dated-idea` assertions from `timeline/0.1.0/test/units.typ` (the
   two lines asserting it is a function and that it equals `idea`), keeping the
   ones that cover `idea` and `dated` themselves.
3. Fix `readme.md`'s opening example: the import line names `entries`, matching the
   call below it. Check the whole file for the same slip — `rg -n '\bdates\b'
   /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md` — and fix every instance
   EXCEPT the prose in the "renamed from `@rookery/core-dates`" section, where the
   old name is the subject of the sentence.
4. Remove `dated-idea` from the migration table's "everything else keeps its name"
   list (`readme.md:53-56`), and add one line to that section saying the alias is
   gone and `idea` is the name.
5. `todos/0.1.0/src/todo.typ:58` and `todos/0.1.0/src/skin.typ` mention
   `dated-idea` in PROSE about how the skin works. Reword to name `idea`, or drop
   the mention — do not leave a comment pointing at a name that no longer exists.

## Non-goals

- **Do not touch `idea`, `tagged-idea` or `dated`.** The skin's two overrides and
  the decorator are the API; this only removes a redundant third name for one of
  them.
- **Do not rewrite the readme.** Fix the example, the list entry, and any other
  stale `dates` reference. A prose pass is a different bird.
- **No renames.** Two later birds rename `entries` and the merged reader; this one
  deliberately lands first and alone, so their diffs do not include this noise.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`.
2. `rg -n 'dated-idea' /home/lox/code/_fcl/rookery` returns nothing.
3. Copy the readme's opening example into a scratch file, add
   `#import "@rookery/core:0.1.0": rookery` and `#show: rookery`, and compile it
   with `typst compile --features html --format html <file> /dev/null` — it
   succeeds. (The package resolves from the cache symlink at
   `~/.cache/typst/packages/rookery/timeline/0.1.0`, which is already in place.)
4. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes.