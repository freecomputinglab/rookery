---
id: rk-adds-id-slug-for-title-derived-note-ids-d9206148
short-id: d92
title: Adds _id-slug for title-derived note ids
priority: 3
labels:
- feat-title-derived-ids
deps: []
closed: false
---
Touches: core/0.1.0/src/pure.typ, core/0.1.0/test/units.typ

Add `_id-slug`, a pure helper that turns a note's title into a string safe to use as
that note's id. It is the first piece of a larger change (deriving an unnamed
`#idea`'s id from its title instead of from a counter); this bird adds the helper and
its unit tests ONLY, and wires it to nothing.

## Why a new helper rather than reusing `_slug`

`@rookery/core` already has a slug function, and it is nearly right:

```
rg -n -F '#let _slug(s) = {' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/pure.typ` (line 814 as of filing), in the block whose header
comment begins "A URL-safe slug from a heading's plain text". It lowercases, collapses
every run of characters outside `[a-z0-9]` to a single `-`, and trims leading and
trailing `-`.

Three things make it unusable as-is for an id, and all three are reasons to ADD a
helper beside it rather than change it:

1. **It panics on an empty result.** A string of nothing but punctuation aborts the
   compile. That is correct for its current caller but wrong here: a note whose title
   slugs to nothing must quietly fall back to the counter, not kill the build.
2. **It has no numeric guard.** `_slug("42")` returns `"42"`, which collides with the
   namespace an unnamed note's counter mints into (ids `1`, `2`, `3`, …).
3. **It has no length cap.** A 200-character title becomes a 200-character id, and an
   id becomes a filename (`ideas/<id>.html`).

`_slug` must keep its exact current behaviour, panic included. Two existing callers
depend on it: the public `slug` function one line below it
(`rg -n -F '#let slug(content) = _slug' /home/lox/code/_fcl/rookery`, one hit, same
file), which is part of this package's public API; and `#ideate`'s heading-derived
naming in `core/0.1.0/src/ideate.typ`, which relies on the panic to reject an
unnameable section.

## Steps

1. Find the site:

   ```
   rg -n -F '#let slug(content) = _slug' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/pure.typ` (line 828 as of filing). Add `_id-slug`
   immediately AFTER that `slug` definition, so the three slug functions sit together.

2. Write it:

   ```typ
   #let _id-slug(s, limit: 60) = {
     let out = lower(s).replace(regex("[^a-z0-9]+"), "-").trim("-")
     if out == "" { return none }
     if out.match(regex("^[0-9]+$")) != none { return none }
     if out.len() > limit { out = out.slice(0, limit).trim("-", at: end) }
     if out == "" { none } else { out }
   }
   ```

   Note the trailing `.trim("-", at: end)` after slicing: cutting mid-word can leave a
   dangling `-`, and an id must not end in one. Re-check for emptiness after the trim.

   Do NOT call `_slug` from inside `_id-slug` — `_slug` panics on the empty case, which
   is the one case this function exists to handle gracefully. Duplicating the one-line
   regex is correct here; say so in the comment.

3. Comment it to this package's house style (see `CLAUDE.md`, "Comment style"): describe
   the present, no history, and give the reason for each of the three rules. The
   non-obvious facts a reader needs are that `none` means "this title cannot name a
   note, use the counter instead", that a purely-numeric slug is refused because it
   would collide with the counter's own namespace, and that the cap exists because an
   id becomes a filename. Keep it to a short paragraph plus the rules; do not restate
   what the code says.

4. Export it for the test fixture. `core/0.1.0/test/units.typ` imports an explicit list
   of names from `/src/lib.typ`. Find it:

   ```
   rg -n -F '_no-content, _slug, _ideate-tag-value' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/test/units.typ` (line 23 as of filing), inside the
   `#import "/src/lib.typ": (` list. Add `_id-slug` to that list, next to `_slug`.

   No other export work is needed: `lib.typ` re-exports `base.typ` with `*`, and
   `base.typ` re-exports `pure.typ` with `*`, so a new top-level `#let` in `pure.typ` is
   already reachable.

5. Add unit assertions. Find the existing slug section:

   ```
   rg -n -F "_slug — a heading's plain text as a URL-safe name" /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/test/units.typ` (line 670 as of filing). Add a new
   `// ---- _id-slug — ...` section AFTER the existing `slug` section that follows it
   (the one containing `#assert.eq(slug([Waterline]), "waterline")`). Assert at least:

   ```typ
   #assert.eq(_id-slug("My Title"), "my-title")
   #assert.eq(_id-slug("Fuzzy search: ranking & scoring"), "fuzzy-search-ranking-scoring")
   #assert.eq(_id-slug("!!!"), none)
   #assert.eq(_id-slug(""), none)
   #assert.eq(_id-slug("42"), none)
   #assert.eq(_id-slug("Chapter 42"), "chapter-42")
   #assert.eq(_id-slug("a" * 80).len(), 60)
   #assert.eq(_id-slug("abc", limit: 2), "ab")
   ```

   Match the fixture's existing convention: a short comment above each assertion saying
   what rule it pins. Note the file's own header describes it as a regression suite —
   these are new-contract assertions rather than regressions, so say in the section
   header that they pin `_id-slug`'s contract.

## Non-goals

- Do NOT change `_slug` or the public `slug` in any way, including its comment.
- Do NOT touch `core/0.1.0/src/idea.typ`, `ideate.typ`, `state.typ` or
  `transclusion.typ`. Nothing calls `_id-slug` after this bird, and that is correct —
  a separate bird wires it in.
- Do NOT add `_id-slug` to any public export list, readme, or documentation. It is
  internal (leading underscore) and the readme is a separate bird's job.
- Do NOT change how ids are currently generated anywhere.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`. This is the whole harness — `assert.eq`
   failures abort the compile with a line number.
2. `rg -n -F '#let _id-slug' src/pure.typ` returns exactly one hit.
3. `rg -n -F '#let _slug(s) = {' src/pure.typ` still returns exactly one hit, and
   `rg -n -F 'could not be slugged to a name' src/pure.typ` still returns exactly one
   hit — proving `_slug`'s panic is untouched.
4. `rg -c '_id-slug' src/` reports hits in `pure.typ` only.