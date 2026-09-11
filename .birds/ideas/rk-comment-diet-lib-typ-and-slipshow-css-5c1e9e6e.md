---
id: rk-comment-diet-lib-typ-and-slipshow-css-5c1e9e6e
short-id: 5c
title: 'Comment diet: lib.typ and slipshow.css'
priority: 3
labels:
- chore-slipshow-review
deps: []
closed: false
---
Trim two comments in `@rookery/slipshow` that violate this repo's own comment
rubric (`/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style" section):
"Describe the present ... Never what it used to be, what moved where, which
release changed it" and "No issue ids. Never name a beads issue, a bookmark
or a branch." Comment text only — no code, no behaviour, changes.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ, /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.css

## Fix 1 — `lib.typ`'s tracker reference

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ`, lines 4-6:

```typ
// THE ENTRYPOINT IS A MANIFEST, not a place for code. Every name this package
// exports lives in one of the modules below, imported here in dependency
// order — a later bead fills in the list.
```

"a later bead fills in the list" names the issue tracker (a "bead") as the
mechanism for a future change. Per the rubric, a reader with no access to the
tracker has nothing to act on here, and the argument for the line has to
stand on its own. The two facts worth keeping — this file is a manifest, not
a place for code, and every export lives in one of the modules imported below
in dependency order — already stand on their own with no tracker reference at
all.

Fix: drop the trailing clause, keeping the rest of the sentence unchanged:

```typ
// THE ENTRYPOINT IS A MANIFEST, not a place for code. Every name this package
// exports lives in one of the modules below, imported here in dependency
// order.
```

## Fix 2 — `slipshow.css`'s history paragraph

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.css`, the comment
above `.slip`, lines 86-92:

```css
/* ONE SLIP. No fixed height — see the file header — and, by default, no
   spacing of its own either: a slip is exactly its card, and the rhythm
   between two slips is whatever `@rookery/core` already gives two cards in a
   column. This package used to add `3rem 1.5rem` of padding and another
   `3rem` between slips, which on a deck the reader walks into one slip at a
   time reads as a page of empty space with a note somewhere in it — the
   generous frame was sized for a deck that showed everything at once.
```

"This package used to add `3rem 1.5rem` of padding and another `3rem`
between slips ... the generous frame was sized for a deck that showed
everything at once" describes a PAST value this stylesheet no longer has —
exactly the "what it used to be" case the rubric names. The paragraphs that
follow this one (lines 94-124, covering the two custom properties, the
padding/background interaction, `scroll-margin-top`, and the border-rule
channel) all explain the PRESENT rule and are unaffected — only this one
historical paragraph is in scope.

Fix: replace the four sentences with one that gives the present-tense reason
for zero default spacing, with no reference to a prior value:

```css
/* ONE SLIP. No fixed height — see the file header — and, by default, no
   spacing of its own either: a slip is exactly its card, and the rhythm
   between two slips is whatever `@rookery/core` already gives two cards in a
   column. A deck the reader walks into one slip at a time has no use for a
   wide frame around each one — that reads as a page of empty space with a
   note somewhere in it.
```

Keep the blank-comment-line structure and every OTHER paragraph in this
comment block (starting at "TWO CUSTOM PROPERTIES RATHER THAN TWO LITERALS"
on line 94) exactly as they are — only the sentences quoted above change.

## Do NOT

- Do not touch any other comment in `slipshow.css` — in particular, leave
  the "TWO CUSTOM PROPERTIES", "`padding` IS WHAT A BACKGROUND FILLS",
  "`scroll-margin-top` stays a real number", and "A FOURTH, OPT-IN AXIS"
  paragraphs (lines 94-124) exactly as written; none of them describe past
  behaviour.
- Do not touch `lib.typ`'s first two lines (the file's own one-line
  description and the `github.com/panglesd/slipshow` credit) or the five
  `#import` lines below the comment — only the trailing clause named in Fix
  1 changes.
- Do not add a new comment explaining what changed — the point is fewer
  words, not a replacement note about the edit itself.

## VERIFY

1. Typst suite green (comment-only change to `lib.typ`, but confirm nothing
   else broke):

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
   ```

   Expect `units OK`.

2. Full build check — `slipshow.css` ships via `typst.toml`'s
   `css_stylesheet` key with no build step, so a syntax mistake in the
   comment edit (an unclosed `/* */`) would surface here as a broken or
   unstyled page rather than a compile error:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`.