---
id: rk-remove-unused-imports-in-when-typ-and-9d534a2a
short-id: 9d
title: Remove unused imports in when.typ and ladder.typ
priority: 2
labels:
- chore-timeline-review
deps: []
closed: false
---
**Remove unused module imports from `when.typ` and `ladder.typ`.**

`@rookery/timeline`'s files import each other with `#import "<file>.typ": *`
lines at the top. Checked (by grepping every non-comment line of each file
for every name the imported module defines) which of those star-imports are
actually used, and two files import modules whose names they never
reference:

1. `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ`, line 14:
   `#import "fragment.typ": *`. `fragment.typ` defines `LOG-KEY`,
   `SCHEDULED-STAGE`, `DEADLINE-STAGE`, `CLOSED-STAGE`, `entries`, `dated`,
   and the private helpers `_assert-stage`, `_day-of`, `_stamp-of`,
   `_norm-entry`, `_timeline-entries`, `_norm-tags`. None of these names
   appear anywhere in `when.typ`'s code (only `read.typ`'s re-exported names
   — `timeline-of`, `deadline-of`, `scheduled-of`, `entered-of` — are
   actually called, and `when.typ` already imports `read.typ` separately on
   line 15). The `fragment.typ` import on line 14 is dead weight.

2. `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/ladder.typ`, lines 22-23:
   `#import "fragment.typ": *` and `#import "read.typ": *`. `ladder.typ`'s
   only cross-module call is `stage-of(tags, today: today)` (used in
   `is-settled`, `rung`, and `next-stage`), and `stage-of` is defined in
   `when.typ` — which `ladder.typ` already imports on line 24. Neither
   `fragment.typ` nor `read.typ` is referenced anywhere else in the file.

Leaving an unused import makes a reader believe the file depends on more
than it does, and invites a future edit to "clean up" the wrong thing when
`fragment.typ` or `read.typ` genuinely changes.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ,
/home/lox/code/_fcl/rookery/timeline/0.1.0/src/ladder.typ

## Decisions already made — do not re-derive

- This was verified by checking EVERY name each candidate module exports
  against every non-comment line of the importing file — not just a
  sampling. The two deletions above are the complete list for these two
  files; do not go hunting for more in other files as part of this bird (see
  Do NOT below).
- Deleting the import lines is the whole fix. No other line in either file
  needs to change — Typst does not require an explicit re-import of a name
  that arrives transitively through another import in the same file (e.g.
  `ladder.typ` still gets everything it needs through its `when.typ` import).

## Steps

1. Open `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ` and delete
   line 14 (`#import "fragment.typ": *`) entirely, including its newline, so
   the import block becomes just:

   ```typ
   #import "read.typ": *
   ```

2. Open `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/ladder.typ` and
   delete lines 22-23 (`#import "fragment.typ": *` and `#import "read.typ":
   *`) entirely, so the import block becomes just:

   ```typ
   #import "when.typ": *
   ```

3. Leave every other line in both files untouched.

## Do NOT

- Do not remove or edit any import in any OTHER file in this package
  (`lib.typ`, `fragment.typ`, `read.typ`, `index.typ`, `view.typ`,
  `upcoming.typ`) — they were checked as part of the same review and every
  import there IS used (for example `index.typ` and `view.typ` and
  `upcoming.typ` each call `_day-of`/`_stamp-of` from `fragment.typ`
  directly, so removing that import from those files would break the
  build).
- Do not add any new import to compensate — nothing needs one.
- Do not reorder the remaining import line(s).

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
```

Must print exactly what it prints on the unmodified package: `units OK`,
then the two HTML exports (only the existing "html export is under active
development" warnings, no new warnings about unresolved names), then
`check.sh`'s summary lines ending `views OK`. Since these two imports were
unused, the build's output must be byte-for-byte identical to the baseline —
any new error or changed line means a name that was actually needed got
deleted, and the deletion should be reverted for that file.