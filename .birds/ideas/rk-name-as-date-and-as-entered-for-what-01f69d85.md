---
id: rk-name-as-date-and-as-entered-for-what-01f69d85
short-id: 01f
title: Name as-date and as-entered for what they return
priority: 1
labels:
- chore-timeline-api
deps:
- blocked-by:rk-name-the-write-surface-and-the-queue-013fb075
closed: false
---
`index.typ`'s six extractors mostly return what their reader returns — `as-stage`
gives a stage name, `as-rung` an integer, `as-settled` a bool. Two do not:
`as-date` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/index.typ:45`) and
`as-entered` (line 51) return a zero-padded `[year][month][day]` STRING, not the
datetime their underlying readers (`stage-date`, `entered-of`) hand back. The
names give no hint, and a caller who expects a date and formats it gets `20261101`.

The conversion itself is right and should stay: `@rookery/core`'s `tag-index`
asserts that a projected value is a scalar (`core/0.1.0/src/data.typ:119-129`), so
a datetime cannot ride on a row, and a fixed-width numeric string is a free sort
key. What is wrong is only the name.

Rename to say what comes out:

```
as-date(stage)        -> as-day-stamp(stage)
as-entered(today: ..) -> as-entered-stamp(today: ..)
```

Worth knowing while here, and worth a line of comment rather than a change: core's
own `stamp: true` does the same conversion, and it is legal alongside `from:` —
`(from: .., stamp: true)` stamps whatever the extractor returned. Having these two
stamp internally is still the better default, because a naked extractor in a spec
that forgot `stamp: true` would trip core's scalar assert at build time. Say that
where the functions are, so the next reader does not "simplify" it away.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/index.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/core/0.1.0/readme.md

## Steps

1. Rename both in `index.typ`, keeping their bodies and their `_day-of` call
   unchanged. `as-stage`, `as-rung`, `as-settled` and `as-days-in-flight` keep
   their names — each returns exactly what its reader returns.
2. Replace the "Two reasons, and the second is the useful one" paragraph above
   `as-date` with the present-tense version: a projected value must be a scalar
   for core's assert to pass, the stamp is fixed width so string order is date
   order, and it is done here rather than left to core's `stamp: true` so a spec
   cannot forget it. Two or three lines, not the current seven.
3. Update the two assertions in `timeline/0.1.0/test/units.typ:260-262`.
4. Update `timeline/0.1.0/readme.md:444-452`, the `tag-index` example, and the
   migration table's "everything else keeps its name" list, which names the
   `as-*` extractors as a group.
5. `core/0.1.0/readme.md:1366-1367` names `as-stage`, `as-date` and `as-rung` as
   the cross-package pattern. Update `as-date` there.

## Non-goals

- **Do not change what either function returns.** A string, stamped here.
- **Do not delete the extractor family.** They are eta-expansions of the readers,
  and that is on purpose: `core/0.1.0/readme.md` documents them as how a package
  ships extractors for its own keys, and a spec built from named factories reads
  as data.
- **Do not rename the other four.**
- **Do not add a `stamp:` parameter.** One behaviour per extractor.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`.
2. `rg -n 'as-date|as-entered\b' /home/lox/code/_fcl/rookery` returns nothing.
3. `cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test` passes (the readme
   change is prose, but core's own `tag-index` fixtures should stay green).
4. `cd /home/lox/code/_fcl/rookery && just check-versions` passes.