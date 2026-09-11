---
id: rk-delete-orphaned-duplicate-comment-in-b67adb8a
short-id: b6
title: Delete orphaned duplicate comment in read.typ
priority: 3
labels:
- chore-timeline-review
deps: []
closed: false
---
**Delete an orphaned, duplicated comment block in `read.typ`.**

`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/read.typ` has a 23-line
comment block at lines 12-34 that sits between the file's single `#import`
(line 10) and the `---- The log, read back ----` section header (line 35).
That block does not describe the code immediately below it — the section
header and its own lead-in paragraph follow right after — and every fact in
it is restated, word for word, in the places later in the same file that
actually sit next to the function each fact describes:

- Lines 21-29 of the orphaned block ("`none` when the stage is absent... RE-SOURCED
  OVER THE LOG in 0.6.0... all still call these.") are IDENTICAL to lines
  84-92, which sit directly above `scheduled-of`/`deadline-of` (lines 93-94)
  — the functions that comment is actually about.
- Lines 31-34 of the orphaned block ("THE LATEST entry wins where a stage
  appears more than once... the last match is the latest.") are IDENTICAL to
  lines 66-69, which sit directly above `stage-date` (line 70) — the
  function that comment is actually about.
- Lines 12-19 of the orphaned block overlap the section header's own
  lead-in at lines 37-39 ("Every reader here is a pure function of a tag
  DICTIONARY... A caller walking the corpus does one `tag-data()` and calls
  these per row.") — the phrase "A caller walking the corpus does one
  `tag-data()` and calls these per row" appears in both places.

This is exactly the CLAUDE.md "Comment style" rubric's "the same fact stated
twice in one file" case (`/home/lox/code/_fcl/rookery/CLAUDE.md`): the block
at lines 12-34 contributes nothing a reader does not already get from the
section header right after it and the two correctly-positioned copies
further down. Deleting it removes pure duplication and loses no information
— every fact in it survives in its proper, better-positioned location.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/read.typ

## Decisions already made — do not re-derive

- Delete ONLY lines 12-34 (inclusive) of the CURRENT file. Do not touch lines
  66-69 or 84-92 — those are the correctly-positioned copies that stay
  exactly as they are; they are not "duplicates to also remove", they are
  the originals this bird is de-duplicating against.
- Do not touch the file's own header (lines 1-8), the `#import` line (line
  10), or the section header block (lines 35-45) that currently follows the
  block being deleted.
- After deletion, line 10 (`#import "fragment.typ": *`) should be followed
  by exactly one blank line and then the `---- The log, read back ----`
  section header — which is already the case one line further up (line 11
  is already blank), so no new blank line needs to be added or removed
  beyond deleting lines 12-34 as one contiguous span.

## Steps

1. Open `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/read.typ`.
2. Confirm the block to delete by reading lines 9-36: it starts at the first
   line after the blank line following `#import "fragment.typ": *` (line 12,
   `// This package's own dates, off a note's tag dictionary — the thing`)
   and ends at the line immediately before `// ---- The log, read back
   ----------------------------------------------------` (line 34, `// by
   date, so the last match is the latest.`).
3. Delete that entire span — lines 12 through 34 inclusive, 23 lines total —
   leaving the blank line at (old) line 11 immediately followed by the
   section header that was at (old) line 35.
4. Leave every other line in the file unchanged, including the two
   surviving copies at what are currently lines 66-69 and 84-92.

## Do NOT

- Do not edit, shorten, or rephrase lines 66-69 or 84-92 — they are correct
  as they stand and this bird is not asking for a second pass over them.
- Do not touch any other file in this package.
- Do not delete or edit any code line (only comment lines, and only within
  the specified span, are removed).

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
```

Comments carry no runtime behaviour in Typst, so this must print exactly
what it prints on the unmodified package: `units OK`, then the two HTML
exports (only the existing "html export is under active development"
warnings), then `check.sh`'s summary lines ending `views OK`. Any change to
that output means a non-comment line was accidentally touched, and the edit
should be reverted and redone more narrowly.