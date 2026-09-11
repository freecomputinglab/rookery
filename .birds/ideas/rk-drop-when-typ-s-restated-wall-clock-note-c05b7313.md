---
id: rk-drop-when-typ-s-restated-wall-clock-note-c05b7313
short-id: c0
title: Drop when.typ's restated wall-clock note
priority: 3
labels:
- chore-timeline-review
deps:
- blocked-by:rk-remove-unused-imports-in-when-typ-and-9d534a2a
closed: false
---
**Cut `when.typ`'s ten-line restatement of the no-wall-clock measurement down to the three lines that are local to the module.**

`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ` opens with a
ten-line comment block (lines 3-12) explaining that Typst has no wall clock:
`datetime` has no time of day, `datetime.today()` returns 1980-01-01 under
`SOURCE_DATE_EPOCH`, measured at typst 0.15.1 with
`SOURCE_DATE_EPOCH=315532800`, and it fails silently rather than erroring.

Every one of those facts is already stated, in the same words and with the same
measurement, in the package header at
`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ` lines 41-51, where it
belongs: it is a package-wide constraint, not a property of this module. The
repo's comment rubric (`/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment
style") names the same fact stated twice across two files as a defect, and asks
for terse comments generally.

What IS local to this module is the consequence: every predicate here needs a
reference date, so the date is a parameter and the last resort is a panic. That
part stays.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ

## Decisions already made — do not re-derive

- **`lib.typ` is where the measurement lives, and this bird does not touch it.**
  A separate bird tightens that header; it explicitly keeps the wall-clock
  paragraph. Do not move the measurement, do not delete it from `lib.typ`, and
  do not open `lib.typ` at all.
- **Do not replace the deleted text with a cross-reference.** A line saying
  "see `lib.typ`" is a line, and the reader of `when.typ` does not need the
  measurement to use these predicates — only the parameter rule.
- **The `_today` comment at lines 25-35 STAYS in full.** Its `MEASURED` note (a
  document with no date set yields `auto`, NOT `none`, so testing only for
  `none` lets `auto` through) is a Typst quirk the code cannot express and a
  trap a caller falls into. It is not a duplicate of anything.
- **The panic message at lines 48-54 STAYS untouched.** It is user-facing error
  text, not a comment, and it is what a build prints when no date is reachable.

## Steps

1. Open `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ`. Lines 1-12
   currently read:

   ```
   // Derived temporal predicates, each taking an explicit reference date.
   //
   // EVERY FUNCTION HERE NEEDS A "NOW", AND TYPST CANNOT SUPPLY ONE. `datetime`
   // has no time of day (MEASURED: `.hour()` is `none`), and `datetime.today()`
   // returns 1980-01-01 wherever `SOURCE_DATE_EPOCH` is set for reproducible
   // builds — MEASURED at typst 0.15.1 with `SOURCE_DATE_EPOCH=315532800`, which
   // is exactly what this repo's own devShell exports. It does not error; it just
   // answers wrongly. A predicate built on it would report every deadline in the
   // project as decades overdue and no build would complain.
   //
   // So the reference date is a PARAMETER, resolved by `_today` below, and the
   // last resort is a panic rather than a guess.
   ```

2. Replace all twelve of those lines with exactly these four:

   ```
   // Derived temporal predicates, each taking an explicit reference date.
   //
   // EVERY FUNCTION HERE NEEDS A "NOW", AND TYPST CANNOT SUPPLY ONE. So the
   // reference date is a PARAMETER, resolved by `_today` below, and the last
   // resort is a panic rather than a guess.
   ```

   (That is the one-line module header, a blank comment line, and the
   three-line statement of the local rule — five lines in total, replacing
   twelve.)

3. Leave line 13's blank line and everything from the imports at line 14
   onwards exactly as it is.

## Do NOT

- Do not change any Typst code in this file — no import, no `#let`, no function
  body, no panic message.
- Do not edit `lib.typ`, `read.typ`, `ladder.typ` or any other file. This bird
  touches one file.
- Do not delete or shorten the `_stamp` comment or the `_today` comment.
- Do not add a "see lib.typ" pointer in place of the deleted text.
- Do not go looking for other comments to trim in this file. The rest of
  `when.typ`'s comments are per-predicate contracts (which boundary is
  inclusive, what a deadline falling on `today` means) and they earn their
  place.

## VERIFY

1. The suite is green, printing the same `units OK` and `views OK` it prints
   today:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
   ```

2. The restated measurement is gone — both print nothing:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n 'SOURCE_DATE_EPOCH' when.typ
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n '1980-01-01' when.typ
   ```

   Note: `1980-01-01` also appears inside the panic message further down the
   file, at what is currently line 51. That occurrence is error text and MUST
   survive — so this grep is expected to print exactly ONE line, the panic
   message, and no comment line. If it prints two or more, a comment was left
   behind.

3. The local rule survives — prints the three-line statement:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n 'NEEDS A "NOW"' -A 2 when.typ
   ```

4. The `_today` quirk note survives — prints its `MEASURED` line:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n 'yields `auto`' when.typ
   ```

5. The file is seven lines shorter than it is today (215 lines now, 208 after):

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && wc -l < when.typ
   ```