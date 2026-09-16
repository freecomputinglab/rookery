---
id: rk-decide-one-today-contract-for-the-whole-fbbcc914
short-id: fbb
title: Require an explicit today everywhere
priority: 1
labels:
- chore-explicit-today
deps: []
closed: true
---
Every function that needs a reference date takes one explicitly. The fallback to
the document's own `#set document(date:)` is removed from `@rookery/timeline` and
`@rookery/cfps`, and with no `today:` given these functions panic.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ, /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ, /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md, /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ, /home/lox/code/_fcl/rookery/cfps/0.1.0/src/panel.typ, /home/lox/code/_fcl/rookery/cfps/0.1.0/readme.md

## The decision, and why

A document date and the reader's today are DIFFERENT QUANTITIES that happen to
share a type. `#set document(date:)` records when the document was written or
published; `today:` answers "what is now, for whoever is reading this". Resolving
the second from the first is wrong even when the document date is fresh, and a
document dated some months ago reports that month's overdue set as though it were
current.

So the fallback goes, in both packages, for every function that has it. This was
chosen over the two alternatives that were on the table:

- Making the two queue views (`#timeline-upcoming`, `#timeline-upcoming-rows`)
  accept the fallback like the predicates do — rejected, because it spreads the
  category error rather than removing it.
- Making the queue views take `today` POSITIONALLY so the requirement shows in
  the signature — rejected as unnecessary once the fallback is gone everywhere:
  the point of that device was to distinguish two contracts, and after this
  change there is only one. `today:` stays a keyword argument on every function.

**Nothing in this repository relies on the fallback.** Every predicate call in
`timeline/0.1.0/test/units.typ`, and every `#cfp` and `#panel` call in
`cfps/0.1.0/test/`, already passes `today:` explicitly. No `.typ` file in the
repository calls `#set document(date:)` at all. So no test or demo should need a
new argument — if one fails to compile after this change, that is a real finding
worth reporting, not a fixture to patch.

**A consuming project that did rely on it now fails to compile with a panic that
names the problem.** That is the intended outcome: loud rather than quietly wrong.

## A simplification that comes with it

`_today` currently reads `document.date`, and reading it requires context — the
comment at `timeline/0.1.0/src/when.typ:17-19` records that every caller must
therefore be inside a `#context` block. With the fallback gone, `_today` asserts on
its argument and reads nothing contextual. Do NOT go hunting for `#context` blocks
to remove elsewhere; just stop claiming the requirement in the comment.

It also collapses two functions into one. `timeline/0.1.0/src/upcoming.typ:117-125`
defines `_require-today`, whose whole job is asserting the argument is a datetime —
which is exactly what `_today` becomes. So `_require-today` goes and its callers
use `_today`. That import already works: `upcoming.typ:46` is
`#import "when.typ": *`, and a `*` import carries underscore-prefixed names
(`view.typ:30` imports the same way and calls `_today` at `view.typ:56`).

## Steps

1. In `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ`, rewrite `_today`
   (lines 24-41). Keep the datetime type assert on an explicit argument, delete the
   `let d = document.date` line and the `if d != auto and d != none { return d }`
   line after it, and make the `none` case panic. The result is one function that
   either returns a valid datetime or panics:

   ```typ
   #let _today(today) = {
     assert(
       type(today) == datetime,
       message: "@rookery/timeline: this view needs a reference date — pass one "
         + "explicitly, e.g. `today: datetime(year: 2026, month: 8, day: 25)`. "
         + "Typst has no wall clock (`datetime.today()` returns 1980-01-01 under a "
         + "reproducible build), so there is nothing to fall back to. Got "
         + repr(today),
     )
     today
   }
   ```

   The message MUST keep explaining the missing wall clock — that is the one thing
   a caller who hits it needs — and must NOT offer `#set document(date: ..)` as a
   fix, since that path no longer exists.

2. In the same file, rewrite `_today`'s header comment (lines 9-23) to describe
   what it now is: the reference date is always an explicit argument, and the
   absence of one is a panic rather than a guess. Drop the sentence about
   `document.date` yielding `auto` rather than `none` (nothing reads `document.date`
   here any more), and drop the sentence about callers needing to be inside a
   `#context` block (no longer true of this function). Keep the point that
   defaulting to an arbitrary date would make "overdue" a silent lie. Follow the
   project `CLAUDE.md` comment rules: present tense, no history, no mention of what
   this used to do.

3. In `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ`, delete
   `_require-today` and its comment (lines 117-125) entirely, and change its two
   call sites — line 212 and line 313, both reading `_require-today(today)` — to
   `_today(today)`.

4. In the same file, replace the comment block at lines 188-200. It is headed
   "`today:` IS REQUIRED HERE, and only here" and argues that these two views
   refuse a document-date fallback the predicates accept. That distinction no
   longer exists, so the block cannot stay and cannot simply be deleted either — the
   surrounding comment describes the function's contract. Replace it with at most
   two sentences saying the reference date is named at the call site, where it can
   be seen. Do not reproduce the predicate-versus-queue argument; it was an argument
   for a split that is gone.

5. In `/home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ`, apply the same change to
   `_resolve-today` (lines 88-103) and its header comment (lines 84-87). Same shape
   as step 1: keep the datetime assert, delete the `document.date` lines, panic on
   absence, keep the wall-clock explanation, remove the `#set document(date: ..)`
   suggestion from the message at lines 99-101. Keep the message's `@rookery/cfps:`
   prefix and its mention of `#cfp` — a panic should name the function the caller
   called.

6. In `/home/lox/code/_fcl/rookery/cfps/0.1.0/src/panel.typ`, apply the same change
   to that file's own copy of `_resolve-today` (lines 24-39) and its header comment
   (lines 20-23). The message at lines 35-37 names `#panel`; keep that and remove
   its `#set document(date: ..)` suggestion. This is a genuine second copy, private
   to each module — leave it a second copy rather than exporting one from `cfp.typ`,
   which is a refactor this change does not need.

7. In `/home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md`, rewrite the paragraph
   at lines 642-649. It currently opens "**`today:` is required here**, and this is
   the one place in the package where it is" and then defends the split. Replace it
   with a statement that `today:` is required here as it is everywhere in the
   package — one rule, no exceptions — and keep the existing link to the
   `#every-date-is-author-supplied-and-here-is-why` section intact.

8. In the same readme, fix the bullet list at lines 899-906. The bullet at lines
   901-903 says every predicate falls back to the document's own
   `#set document(date: ..)`; it must say instead that every function taking a
   reference date requires it explicitly. The bullet at lines 904-906 says the
   function panics "naming the problem and both fixes" — there is one fix now, so
   say so.

9. In `/home/lox/code/_fcl/rookery/cfps/0.1.0/readme.md`, state the same rule. Add
   a short `### Every `today:` is explicit` subsection immediately after line 173
   (the end of the `## panel:` section, just before `## The four states, and why
   they are net of the reserved stages` at line 175): two or three sentences saying
   every function here that needs a reference date takes it as `today:`, there is no
   fallback to the document's own date, and a call omitting it panics. Match the
   readme's existing register.

## Non-goals

- **Do NOT touch `/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ:188-198`.**
  It resolves `#idea(created:)` from `document.date`, which is the document's date
  used as a CREATION date — correct semantics and a different quantity from
  "today". Leave it, its comment, and its `auto`-versus-`none` note exactly as they
  are.
- **Do NOT touch `timeline/0.1.0/readme.md:295-297`.** That passage is about
  `created` resolving from the document date, the same correct use as above.
- **No wall clock, ever.** `datetime.today()` returns 1980-01-01 under this repo's
  `SOURCE_DATE_EPOCH` and fails silently. Nothing here may call it.
- **Do not fold `days-until`'s positional `today` into the keyword style**
  (`timeline/0.1.0/src/when.typ:166`). It takes two dates, has no tag dictionary
  and no fallback to resolve.
- **Do not change any signature.** `today:` remains a keyword argument with a
  `none` default on every function that has it; the assert is what makes it
  required. No positional `today`, no removing the default.
- **Do not add a `today:` argument to any existing test or demo call.** They all
  pass one already. If something fails to compile for want of one, report it rather
  than patching it.
- **Do not export `_resolve-today` from `cfp.typ` for `panel.typ` to import.**
- **Do not create a new version directory.** These are fixes to the shipped
  `timeline/0.1.0` and `cfps/0.1.0`.
- **Do not add a changelog entry** — neither package has one.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — prints
   `units OK` and `views OK`.
2. `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` passes.
3. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes. This is the
   package with the heaviest `timeline` dependency (six files import it), so it is
   what catches a broken predicate contract.
4. `rg -n 'document\.date' /home/lox/code/_fcl/rookery/timeline/0.1.0/src /home/lox/code/_fcl/rookery/cfps/0.1.0/src`
   returns NOTHING.
5. `rg -n 'set document\(date' /home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ /home/lox/code/_fcl/rookery/cfps/0.1.0/src/panel.typ`
   returns NOTHING — no panic message still advertises the removed fallback.
6. `rg -n '_require-today' /home/lox/code/_fcl/rookery/timeline/0.1.0/src` returns
   NOTHING.