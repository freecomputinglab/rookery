---
id: rk-documents-the-derived-id-ordering-caveat-2b3c62b2
short-id: 2b3
title: Documents the derived-id ordering caveat
priority: 1
labels:
- docs-derived-id-order
deps:
- blocked-by:rk-records-that-an-idea-s-return-value-is-1fda1f23
closed: true
---
Touches: core/0.1.0/readme.md

Document the one ordering caveat in `@rookery/core`'s title-derived note ids: which of
two colliding notes gets the bare slug and which gets `-1` depends on document order,
and a title that itself ends in a number can take the id a collision would otherwise
have produced.

## The caveat

An unnamed `#idea` with a title takes a slug of it, probing a document-wide set for the
first free `<slug>`, `<slug>-1`, `<slug>-2`. Ids are therefore always unique. But the
`-<n>` suffix is not a reserved namespace — it is ordinary slug text — so:

```typ
#idea(title: [My Title])[a]    // idea:my-title
#idea(title: [My Title 1])[b]  // idea:my-title-1
#idea(title: [My Title])[c]    // idea:my-title-2, NOT my-title-1
```

Reverse the order of the last two and the third note takes `my-title-1` while the "My
Title 1" note takes `my-title-1-1`. The probe keeps every id unique in both cases —
this is a predictability caveat, not a correctness bug, and it needs saying so an
author who cares about a stable URL knows to pin a name instead.

The same ordering rule governs `#ideate`'s heading-derived ids.

## Steps

1. Find the section documenting derived ids:

   ```
   rg -n -i 'ids derived from title|derived from its title' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   A section added by earlier work, near the material on flat ids. If the heading has
   been reworded, find it with `rg -n -i 'my-title' readme.md` instead — that worked
   example is in it.

2. Add a short paragraph there with the three-line example above, stating: ids stay
   unique whatever the order; which note gets which id depends on document order; a
   title ending in a digit can occupy a suffix slot; pin a name with `#idea(<x>, title:
   [..])` when a specific stable id matters.

   Keep it to a paragraph and the example. Match the readme's register (`CLAUDE.md`,
   "Comment style" — present tense, describe what is, no changelog voice).

## Non-goals

- Do NOT change any behaviour, and in particular do NOT change the `-<n>` separator to
  something that cannot collide. That is a real option and a real decision, but it
  changes minted URLs again and nobody has chosen it — this bird only documents what
  the code does now.
- Do NOT touch `core/0.1.0/src/`.
- Do NOT rewrite the surrounding derived-ids material; add to it.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `rg -i -F 'my-title-2' readme.md` returns at least one hit — the worked example
   showing the skipped slot is present.
3. `rg -i 'document order' readme.md` returns at least one hit.