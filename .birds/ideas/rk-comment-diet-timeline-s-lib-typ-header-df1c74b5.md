---
id: rk-comment-diet-timeline-s-lib-typ-header-df1c74b5
short-id: df
title: 'Comment diet: timeline''s lib.typ header'
priority: 3
labels:
- chore-timeline-review
deps: []
closed: false
---
**Cut the version history, the interior banner and the lab notebook out of `@rookery/timeline`'s `lib.typ` header.**

`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ` is 117 lines, 100 of
them comments. Much of the header describes how the package got here rather
than what it is: which core release removed a field, what the package owned
before 0.6.0, that a shape "survives" a past change. The repo's own comment
rubric — the "Comment style" section of
`/home/lox/code/_fcl/rookery/CLAUDE.md` — forbids exactly that, and also
forbids the `// ---- Section ----` banner this file carries at line 75.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ

## Decisions already made — do not re-derive

- **The wall-clock block at lines 41-51 STAYS.** It is a constraint the code
  cannot express (Typst silently answers with a wrong date rather than
  erroring) and it is the package-wide rule three other modules depend on.
  Keep the rule, keep one statement of the measurement. The only change there
  is to stop saying `MEASURED` twice in one paragraph — say it once.
- **The numbered list at lines 87-93 STAYS.** Those three facts are Typst
  import semantics a reader cannot infer (star-import re-exports; an aliased
  import keeps the original reachable; a later top-level `#let` shadows a
  star-imported name), and the file's design rests on all three. Only the
  lab-notebook framing on line 85 goes.
- **Do not renumber or reword the package's actual behaviour.** This bird
  changes comments only. Not one line of Typst code changes.
- **`0.6.0` is not this package's version and not core's pinned version.**
  Lines 98-99 import `@rookery/core:0.1.0`. A header that names `0.6.0` three
  times therefore points at nothing a reader can check. Drop the number
  wherever it appears rather than trying to correct it.

## Steps

Line numbers are as the file stands today. Work top to bottom so earlier
deletions do not shift a line you have not read yet — or re-find each block by
its quoted text.

1. **Line 3.** `// A note's temporal planning, contributed through @rookery/core 0.6.0's TAG`
   — drop the version: `@rookery/core's TAG DICTIONARY`.

2. **Lines 10-17.** The paragraph opening `// THAT SHAPE IS THE POINT, and it
   survives 0.6.0's `#dated-idea` intact.` — delete the clause `, and it
   survives 0.6.0's \`#dated-idea\` intact`, leaving `// THAT SHAPE IS THE
   POINT.` and the rest of the paragraph (about the absent import relationship,
   `dated(mint)`, and the single `dated-idea` binding) unchanged.

3. **Lines 19-24.** Currently:

   ```
   // WHAT IT OWNS: a note's DATED EVENTS, as one ordered log. Until 0.6.0 it owned
   // two independent slots and both were plans — `scheduled` (when you mean to work
   // on it) and `deadline` (a hard date), the org-mode pair. A log is the third
   // thing, org-mode's LOGBOOK to those two: what happened, and when. Both of the
   // old slots are RESERVED STAGE NAMES inside it now, so one mechanism carries
   // arbitrarily complex lifecycles without this package naming any of their states.
   ```

   Replace with a present-tense statement of the same shape, keeping the
   org-mode analogy (which explains the design) and dropping the history:

   ```
   // WHAT IT OWNS: a note's DATED EVENTS, as one ordered log — org-mode's LOGBOOK.
   // `scheduled` (when you mean to work on it) and `deadline` (a hard date) are
   // RESERVED STAGE NAMES inside that log rather than slots beside it, so one
   // mechanism carries arbitrarily complex lifecycles without this package naming
   // any of their states.
   ```

4. **Line 38.** `// \`updated\` is neither owned nor read — core removed that
   field in 0.6.0.` — replace with `// \`updated\` is neither owned nor read;
   core ships no such field.`

5. **Lines 42-45.** Two `MEASURED` parentheticals in one paragraph. Collapse to
   one, keeping both facts and the typst version:

   ```
   // THERE IS NO WALL CLOCK, and this constrains the whole package. MEASURED at
   // typst 0.15.1: `datetime.today().hour()` is `none`, and `SOURCE_DATE_EPOCH`
   // (which this repo's own devShell sets, to 315532800) makes `datetime.today()`
   // return 1980-01-01 rather than the real date.
   ```

   Lines 46-51 — `IT FAILS SILENTLY` and the three bulleted rules — stay
   exactly as they are.

6. **Line 53.** `// This package reads no rheo context, no \`sys.inputs\` and no
   state, and there is` / `// still no JavaScript.` — drop `still`: `...and no
   state, and ships no JavaScript.` The word argues with a change the reader
   has not made.

7. **Lines 75-76.** Delete the banner line
   `// ---- The SKIN over @rookery/core ------------------------------------------`
   and the bare `//` under it. The paragraph beginning `// THE PATTERN.` at
   line 77 becomes the start of that comment block. Interior banners are
   forbidden by the repo rubric; the prose under it is a caller contract and
   stays.

8. **Line 85.** `// HOW IT WORKS, and all three facts were verified before this
   was written:` — replace with `// HOW IT WORKS:`. The three numbered items
   below it are unchanged.

9. **Lines 115-117.** Currently:

   ```
   // KEPT AS AN ALIAS, and it is now the same function as `idea` above rather than the
   // only way to get one. Call sites written before the skin keep working.
   #let dated-idea = idea
   ```

   Replace the two comment lines with one: `// An alias for \`idea\` above.`

## Do NOT

- Do not change any Typst code — no import, no `#let`, no function body. The
  only lines that change are comment lines.
- Do not delete the wall-clock paragraph (lines 41-51) or the three numbered
  import facts (lines 87-93).
- Do not touch any other file in the package. `when.typ` restates the same
  wall-clock measurement and a separate bird owns that; leave it alone here.
- Do not add a new section banner anywhere, and do not "helpfully" convert the
  header into doc-comments or another format.
- Do not rewrite comments that are already terse and present-tense just because
  they sit next to one you are editing.

## VERIFY

1. The suite is green, printing the same `units OK` and `views OK` it prints
   today:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
   ```

2. No version history survives — each of these prints nothing:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n '0\.6\.0' lib.typ
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -niE 'Until 0|used to|removed that|still no|verified before' lib.typ
   ```

3. No interior banner survives — prints nothing:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n '^// ----' lib.typ
   ```

4. The comment count has dropped well below its current 100:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && echo "$(grep -c '^[[:space:]]*//' lib.typ)/$(wc -l < lib.typ)"
   ```

   Expect roughly 80/97 or fewer. A count still at or near 100 means steps were
   skipped.

5. The wall-clock rules are still there — prints the three bulleted rules:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && grep -n 'THERE IS NO WALL CLOCK' -A 12 lib.typ
   ```