---
id: rk-derives-an-unnamed-idea-s-id-from-its-ac04e549
short-id: ac0
title: Derives an unnamed idea's id from its title
priority: 3
labels:
- feat-title-derived-ids
deps:
- blocked-by:rk-adds-id-slug-for-title-derived-note-ids-d9206148
- blocked-by:rk-carries-a-note-s-resolved-id-on-its-ik-0525b40f
closed: false
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/state.typ

Derive an unnamed `#idea`'s id from its title. A note with a `title:` and no explicit
name gets a slug of that title as its id instead of a sequence number; a note with
neither keeps the counter as it is today.

Colliding slugs are disambiguated with a `-<n>` suffix counting from 1, so three notes
titled "My Title" mint `idea:my-title`, `idea:my-title-1`, `idea:my-title-2`.

## Prerequisites this bird relies on

- `_id-slug(s, limit: 60)` exists in `core/0.1.0/src/pure.typ`. It returns a URL-safe
  lowercase slug, or `none` when the title cannot name a note (empty after stripping
  punctuation, or purely numeric — which would collide with the counter's namespace).
  Find it: `rg -n -F '#let _id-slug' /home/lox/code/_fcl/rookery`. It is reachable from
  `idea.typ` already, via `#import "base.typ": *` which re-exports `pure.typ`.
- `#idea` resolves its id ONCE in a `context` block wrapping the `figure(kind: IK, ..)`,
  and puts it on the metadata payload as `id`. Find it:
  `rg -n -F 'id: id,' /home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ`.

If either is missing, stop and report it rather than building it here.

## Design, already decided — implement exactly this

**A shared taken-ids state, not a counter per slug.** Add to
`core/0.1.0/src/state.typ`, next to the existing counter (find it with
`rg -n -F '#let _seq = counter(' /home/lox/code/_fcl/rookery`, one hit, line 307 as of
filing):

```typ
#let _taken-ids = state("rheo-ideas-taken", (:))
```

A dictionary used as a set of full ids already minted. A counter keyed per slug was
rejected: it cannot see PINNED names, so `#idea(<my-title>)` and
`#idea(title: [My Title])` would both mint `idea:my-title` and collide. One shared set
sees both.

**Resolution order in `#idea`.** In the `context` block that wraps the figure, replace
the current `if named { .. } else { .. }` id binding with:

1. A named note keeps `_pfx() + base` unconditionally and probes nothing. A pin is a
   promise about the id and must never be silently moved.
2. Otherwise, if `title != none`, compute `_id-slug(_plain(title))`. `_plain` is already
   imported here and is what the neighbouring `note-label` binding uses — find it with
   `rg -n -F 'let note-label = if title != none' /home/lox/code/_fcl/rookery`.
3. If that slug is `none`, fall through to the counter: `_pfx() + str(_seq.get().first())`.
4. If it is a string, probe `_taken-ids` for the first free id in the sequence
   `<pfx><slug>`, `<pfx><slug>-1`, `<pfx><slug>-2`, … and take it.
5. Claim whichever id was taken: `_taken-ids.update(t => t + ((id): true))`.
   Note the parenthesised key — `(id): true` — which is how Typst uses a variable as a
   dictionary key. `id: true` would insert the literal key `"id"`.

Claim the id for a NAMED note too (step 1 still ends with the same `.update`), so a
later derived slug probes past a pin that came before it.

Probe loop shape, since `while` with a mutable counter is the clearest form here:

```typ
let taken = _taken-ids.get()
let candidate = _pfx() + s
let n = 1
while candidate in taken {
  candidate = _pfx() + s + "-" + str(n)
  n = n + 1
}
```

**`_seq` still steps for every unnamed note, titled or not.** Do NOT make the counter
step conditional on the note being untitled. The reason is the one already recorded in
this file's exclusion-gate comment (find it: `rg -n -F 'THE COUNTER STILL STEPS'
/home/lox/code/_fcl/rookery`): if the counter only stepped for untitled notes, then
adding a title to one note would renumber every later untitled note, changing their
permalinks and their minted-page filenames. A titled note steps the counter and
discards the value. Untitled ids therefore have gaps (1, 4, 7) — that is correct and
intended; say so in a comment.

## Known limits — write these into the comments, do not try to fix them

- **A pin that appears LATER in the document than a derived note with the same slug
  still collides.** `_taken-ids.get()` only sees what has been claimed so far, and
  there is no second pass. The collision surfaces as the existing duplicate-note-id
  panic at registration, which is loud and names both origins. That is the accepted
  outcome; do not attempt a two-pass fix.
- **`-<n>` is not a reserved namespace.** A second note titled "My Title" mints
  `idea:my-title-1`, and so would a first note titled "My Title 1". The probe catches
  this — whichever comes second walks on to the next free candidate — so ids stay
  unique, but which note gets which id depends on document order. Note it and move on.
- **`#ideate` does something different on purpose.** Its heading-derived naming rejects
  a duplicate slug with a panic telling the author to retitle (find it:
  `rg -n -F 'two sections in this body slug to the same name'
  /home/lox/code/_fcl/rookery`, three hits, all in `ideate.typ`). This bird does NOT
  change `#ideate`. The two policies differ, and reconciling them is a separate
  decision that has not been made.

## Non-goals

- Do NOT touch `core/0.1.0/src/ideate.typ`. Its duplicate-slug panics stay as they are.
- Do NOT change `_slug`, `slug` or `_id-slug`.
- Do NOT change the duplicate-note-id panic message — a separate bird does that.
- Do NOT update the readme — a separate bird does that.
- Do NOT add a `rookery(..)` option to turn this on or off. The new behaviour is
  unconditional.
- Do NOT change the exclusion-gate early return, other than leaving its `_seq.step()`
  exactly as it is.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. Write a scratch fixture and compile it to confirm the ids, then DELETE it (it must
   not be left in the tree):

   ```
   typst compile --features html --root . --format html /tmp/ids.typ /tmp/ids.html
   ```

   with a body importing `/src/lib.typ` that mints, in order: `#idea(title: [My Title])[a]`,
   `#idea(title: [My Title])[b]`, `#idea[c]` (no title), `#idea(title: [!!!])[d]`.
   Grepping `/tmp/ids.html` must show ids `idea:my-title`, `idea:my-title-1`, and two
   counter ids for the third and fourth notes. Report the ids you observed.
3. `rg -n -F '_taken-ids' src/state.typ` returns exactly one hit (the declaration), and
   `rg -c '_taken-ids' src/idea.typ` reports at least 2 (a read and an update).
4. `rg -c '_seq.step()' src/idea.typ` still reports 2 — both existing step sites intact.
5. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`. That
   recipe compiles `root.typ`, `root-prefix.typ` and `excluded.typ` and runs its own
   `check` — it is the pure-Typst demo's real entrypoint.
   report the command you used.