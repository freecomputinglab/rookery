---
id: rk-document-where-unnamed-ids-come-from-8df515e3
short-id: 8df
title: Document where unnamed ids come from
priority: 2
labels:
- fix-idea-auto-id-drift
deps:
- blocked-by:rk-make-unnamed-idea-ids-survive-re-render-94c027fb
closed: true
---
Touches: core/0.1.0/readme.md

## Why

`@rookery/core`'s readme documents an auto-id scheme that the package no longer
implements. The blocking bird replaces it: an unnamed note's id is now a pure
function of its authored call site, because the old scheme minted a different id
every time a stored body was re-rendered by a `#window` or a minted page.

What the readme must now say, in one sentence: an unnamed note with a title
mints `idea:<slug of title>` and nothing else; an unnamed note without one mints
`idea:<container>-<k>`, where `<container>` is the enclosing note's bare id (or
the vertebra's handle with `:` replaced by `-` when the note is top-level) and
`<k>` counts unnamed notes within that container from 1; and two unnamed notes
that slug to the same id are now a build error telling the author to pin one,
not a silent `-<n>` suffix.

Do NOT re-derive that scheme from the source. If a detail is missing here, read
`core/0.1.0/src/idea.typ`'s minting `context` block and say what it does, rather
than inventing a rule.

## Steps

1. Rewrite the section headed `## Unnamed notes: ids derived from title`.

   ```
   rg -n 'Unnamed notes: ids derived from title' /home/lox/code/_fcl/rookery/core
   ```

   Two hits, both in `core/0.1.0/readme.md` — the heading itself (line 972 as of
   filing) and a forward reference to it near the top of the file (line 9). The
   section runs from that heading to the next `## ` heading, `## Two modes`
   (line 1022 as of filing).

   Inside it, three claims are now wrong and must go:

   - `A colliding slug gets a `-<n>` suffix counting from 1: a second note
     titled "My Title" mints `idea:my-title-1`.` — replace with the build
     error, and with the instruction to pin one of the two.
   - The whole passage beginning `Which note gets the bare slug and which gets`
     and the `My Title` / `My Title 1` / `My Title 2` code block under it, down
     to `#ideate`'s heading-derived ids follow the same rule.` — this documents
     the removed suffix behaviour and its ordering hazard. Replace it with the
     new guarantee: an unnamed note's id no longer depends on document order at
     all, so the same note keeps the same id when sections are reordered, and
     keeps it when the note is shown inside a `#window` or on a minted page.
   - `A note with no title at all still takes a counter id, exactly as before.
     Titled notes still step that counter and discard the value, so an untitled
     note's ids can have gaps (`1`, `4`, `7`, ...)` — the counter is gone.
     Replace with the container-ordinal rule, and state that a titled note does
     NOT consume an ordinal, so the numbers are contiguous within a container.

   Keep the slug rules that still hold: lowercased, runs of non-alphanumerics
   collapsed to a single `-`, trimmed, capped at 60 characters; a title that
   slugs to nothing or to digits only falls back to the ordinal form; a pinned
   name always wins.

   Rename the heading, since the section is no longer only about titles. Use
   `## Unnamed notes: where their ids come from`. Update the forward reference
   at the top of the file (the line reading `(see "Unnamed notes: ids derived
   from title")`) to match.

2. Fix the top-of-file summary. Anchor:

   ```
   rg -n 'one takes a sequential id, and a TITLED one takes a slug' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `core/0.1.0/readme.md` line 8 as of filing. `sequential id` and the
   `[idea:1]`-style permalink example two lines below it both need to become the
   container-ordinal form. Pick a concrete example and use the same one in both
   places.

3. Fix the `#ideate` passage that names the counter. Anchor:

   ```
   rg -n 'unlike the auto' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `core/0.1.0/readme.md` line 702 as of filing, in the paragraph
   beginning `The one note this mode mints has no heading of its own`. It argues
   that `slug(document.title)` is preferable to `the auto counter it would
   otherwise fall to, which shifts whenever a page is added or removed elsewhere
   in the bundle`. That reason is now obsolete — the fallback no longer shifts.
   Keep the preference for `slug(document.title)` (it is readable, which the
   ordinal is not) and replace the shifting argument with the readability one.
   Three lines further down, `the note mints titleless, under the counter, as
   always` needs the same treatment.

4. Fix the `#ideate` argument table. Anchor:

   ```
   rg -n 'the package counter \(today.s behaviour\)' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `core/0.1.0/readme.md` line 756 as of filing, in the `name:` row of
   the `none`/`auto` column. Below the table, the sentence beginning `An id
   minted from a heading survives inserting or reordering sections — unlike the
   package counter, which renumbers everything after the insertion point` states
   a contrast that no longer exists; the default no longer renumbers either. Keep
   the recommendation to use a `name:` function for anything worth linking to,
   and rest it on readability rather than on renumbering.

   Search the rest of the file for `package counter` and `counter` and fix every
   remaining mention the same way:

   ```
   rg -n 'package counter|auto counter|the counter' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

5. The section `**This changes existing URLs.**` near the end of the unnamed-ids
   section already warns that titled unnamed notes moved from `ideas/3.html` to
   `ideas/my-title.html`. Extend it in the same register: untitled notes have now
   moved off bare numbers too, so `ideas/1.html` becomes
   `ideas/<container>-1.html`, and an external bookmark to the old page breaks
   silently. Keep the existing advice — pin a name on any note whose old id must
   keep resolving.

## NON-GOALS

- Do not touch any file but `core/0.1.0/readme.md`.
- Do not restructure the readme, move sections, or change its heading levels
  beyond the one rename in step 1.
- Do not document the internals — no state names, no `_scope`, no
  `state("rheo-ideas-taken")`. The readme is the author-facing surface.
- Do not name a bird, a bookmark or a branch anywhere in the prose; the project's
  `CLAUDE.md` forbids issue ids in comments and the same holds here.
- Do not write a migration guide or a compatibility table.

## VERIFY

1. The removed behaviour is gone. Each of these must print nothing:

   ```
   rg -n 'gets a `-<n>` suffix' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n 'my-title-1-1' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n 'package counter' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

2. The new rule is stated. This must print at least one hit:

   ```
   rg -n 'container' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Read the hits and confirm one of them actually states how an untitled note's
   id is formed, rather than using the word incidentally.

3. The readme's own claims still match the package. Build the demo:
   `cd /home/lox/code/_fcl/rookery/core/0.1.0 && just build`. It must succeed.

4. Any `typst` example block the rewrite touches must still be valid Typst by
   inspection — the readme is not compiled, so read each changed block once and
   confirm the syntax and the argument names match `src/idea.typ`'s signature.