# Generating an idea's name

The design `@rookery/core` uses to name a note that was not explicitly named.
Working notes, 20 September 2026. Supersedes the algorithm described in
`naming.md`, which documents the container-ordinal scheme this replaces, and
answers the failure recorded in `convergence-bug.md`.

## The rule

> A generated name is a pure function of what the note **is** — its own title,
> its own body, its own tags. Never of where it sits, when it was reached, or
> how many things preceded it.

No rung reads a counter or consults a container. A name is computed from values
the call site already fixed, so every rendering of a note computes the same
name, and there is nothing for Typst's convergence loop to settle.

One piece of state survives, and only on rung 2: `_slug-count`, which numbers a
second note deriving the same title slug. It is already idempotent per note —
it maps a slug to an array of occupants and returns a note's existing slot
rather than a fresh one — and it has never appeared in a non-convergence
warning. It stays because a conditional suffix cannot be computed without
knowing whether the slug collided, and paying for that knowledge everywhere
would mean suffixing every titled note's URL.

## Why position had to go

`#window` re-renders a note's body wherever it is placed, and a marrow-minted
page renders it again. Any value taken from the renderer's position therefore
answers for whichever copy won that pass. The container ordinal was that kind
of value, and it kept a real site from converging: with 103 titleless notes and
a five-attempt budget, the stack's innermost entry still differed between the
last attempt and final resolution.

Content cannot drift that way. A note's body is the same value at every
placement, so a name derived from it is the same string at every placement.

## The ladder

Four rungs, tried in order. A rung fires only when the rung above yields
nothing — never because the rung above collided, since whether a name is unique
is not knowable while the document is still being laid out.

| | source | example |
|---|---|---|
| 1 | the pinned name — `#idea(<etal>, ..)` | `idea:etal` |
| 2 | title slug, 60-char cap | `idea:joan-copjec-symposium` |
| 3 | body slug (16) + `-` + content hash (3) | `idea:lean-io-uring-4m3` |
| 4 | nothing derivable | **error** |

Rung 1 is the escape hatch, and the answer to every tradeoff below: an author
who needs a URL that never moves pins the name.

Rung 2 is unchanged. Rung 3 replaces the container ordinal.

## Rung 3, in detail

### The slug

Computed from `_plain(body)` — the pure plain-text projection, which renders
every `ref` as the empty string because it runs before the registry that could
resolve one.

1. **A body that begins with a bare URL slugs from the URL's tail, not its
   head.** Strip the scheme, split on `/`, `?` and `#`, drop file extensions
   (`.html`, `.pdf`, …), drop segments that are purely numeric, and take the
   last segment that survives.

   This is not a refinement, it is the difference between working and not. A
   reading list of bare links is a real and common shape, and a URL's
   distinguishing part is at its end:

   ```typ
   #todo[https://anil.recoil.org/papers/2024-hope-bastion]
   #todo[https://anil.recoil.org/projects/unikernels]
   #todo[https://anil.recoil.org/ideas/lean-io-uring-backend]
   ```

   Slugged left to right, all three read `https-anil-recoil`. Slugged from the
   tail they read `2024-hope-bastion`, `unikernels`, `lean-io-uring-backend`.

2. **Lowercase, collapse every run of non-alphanumerics to a single `-`,
   trim.**

3. **Drop leading stopwords** — a small closed list (`the`, `a`, `an`, `and`,
   `or`, `of`, `to`, `in`, `on`, `at`, `is`, `are`, `for`, `with`, `as`, `by`,
   `from`, …). Leading only: an interior stopword carries rhythm a reader uses,
   and dropping it makes `respond-to-finale` read `respond-finale` for no gain.

4. **Strip a leading `https-`, `http-` or `www-`.** Step 1 catches a body that
   *starts* with a URL; this catches everything else that reaches the slug with
   a scheme still attached — a URL further into the body, a tail extraction that
   found nothing usable, a link written as bare text. Two of a real site's notes
   still led with `https-` after step 1 alone. None do after this.

5. **Take whole words up to 16 characters.** Never truncate mid-word: a name cut
   to `could-we-just-ex` is worse than one cut to `could-we-just`, and the hash
   below is what carries uniqueness anyway.

An empty result falls to rung 4.

### The hash

Three base36 characters, appended after a `-`. The pair is 20 characters at
most.

```typ
#let _h3(s) = {
  let acc = 5381
  for b in array(bytes(s)) { acc = calc.rem(acc * 33 + b, 2147483647) }
  // acc * 33 stays under 2^36, so this never overflows i64
  _b36(acc, 3)
}
```

Typst ships no hash of its own — neither `std` nor `calc` has one — so this is
hand-rolled djb2 over the bytes of `repr(occupant)`, where `occupant` is the
note's own `(title, body, tags, level, display)`.

**The hashed string is capped at 4096 bytes, with the true length appended.**
Cost is linear in body size, and measured at roughly 1.5 MB/s: 103 notes of
~1.4 KB each cost 94 ms against an 8 ms baseline. Typst memoizes a call by its
argument, so attempts after the first are free — but one very long body would
otherwise pay on every note.

36³ = 46,656. That number only has to separate notes that already share a slug,
since two notes collide only when both halves collide. For a slug group of `k`
notes the collision probability is about `k²/(2 × 46656)`; the largest natural
group on a real site is 4, giving 0.017%.

### Why the hash is a suffix

`lean-io-uring-4m3`, not `4m3-lean-io-uring`. The readable half leads, ids sort
meaningfully, and a directory listing of `ideas/` stays scannable.

## Validation, and what it can prove

Naming is pure and local. Uniqueness is global, so it is checked separately,
once, at bundle root — where `query(figure.where(kind: IK))` returns every note
with its resolved id and its payload.

> Group the query hits by id. Within a group, compare payloads. **Payloads
> differ → two distinct notes took one name → error, naming both.**

The payload is the metadata dict each note's marker carries: `body`, `title`,
`label`, `named`, `base`, `id`, `level`, `tags`, `display`.

The comparison is not optional bookkeeping. A note legitimately appears in the
document more than once — its authoring vertebra, its minted page, every
`#window` transcluding it — so "this id occurs twice" is the normal case, and
only differing payloads distinguish a genuine collision from a replay.

### Typst's own label check does not do this

Every note emits `#label(id)`. Duplicate labels look like they should enforce
uniqueness, and they half do:

```
two #label("idea:dup") definitions, nothing referencing them
  →  compiles clean, exit 0, no warning

the same, plus one #link(label("idea:dup"))
  →  error: label `<idea:dup>` occurs multiple times in the document
     ┌─ lab2.typ:3:5     ← the REFERENCE, not either note
```

So the check fires only for an id something happens to reference, and when it
fires it points at the link rather than at either colliding note. The bundle-root
pass exists because that diagnostic is both incomplete and unactionable.

## What is guaranteed, and the one thing that is not

**Guaranteed.** Any two notes that differ in any payload field get distinct
names, or the build fails with an error naming both. There is no third outcome.

**Not guaranteed.** Two notes identical in body, title, tags, level and display
get the same name and merge into one.

This is not an implementation gap. Such a pair is indistinguishable from *one
note rendered twice*, and Typst offers nothing to separate them:

- `here()` exposes only `.position()` (page, x, y) and `.page()` — layout
  coordinates, which is the positional dependence being removed.
- `sys` is exactly `("version", "inputs")`. No file, no path, no line. Typst has
  no source-location introspection at all.
- A show rule that replaces an element **does not hide it from `query()`** —
  verified: a document with one plain marker and one whose show rule replaced it
  reports two hits. So the transcluded copies cannot be filtered out by
  querying alone.

A warning is still worth emitting, since an exact duplicate is rarely intended.
It requires counting genuine call sites rather than placements: `_flatten`'s IK
rule is the only path a replay takes, so having that rule stamp its output lets
the bundle-root pass compute *placements minus replays*. Two or more genuine
sites under one id, with identical payloads, is the warnable case — and the
advice it gives is to pin a name.

## Measured on a real rookery

114 titleless minting call sites (`#idea[`, `#todo[`, `#done[`, `#epic[` with
neither a name nor a title).

| scheme | colliding groups | notes affected |
|---|---|---|
| 20-char slug, no URL rule | 3 | 8 |
| 20-char slug, URL-tail rule | 1 | 2 |
| 16-char slug + 3-char hash | 1 | 2 |

Mean name length 16.6, maximum 20, no empty slugs. Every remaining collision is
the same pair, and it is a genuine authoring duplicate — the same line written
twice in one reading list:

```typ
#todo[Gillian Rose, _Hegel and Sociology_.]
```

Which is the case above that merges and warns rather than erroring.

A caveat on these numbers: they come from a harness that slugs the source text
directly rather than `_plain`'s projection of it, so treat the counts as
indicative. The URL finding and the duplicate are real either way.

## What this removes

The whole container-ordinal apparatus, and with it the only state the naming
path ever read:

- `_scope`, `_scope-peek`, `_scope-record` (`state.typ`)
- both `_scope.update` pairs in `idea.typ` — the push around a note's body and
  its matching pop
- the pair in `transclusion.typ`'s window wrapper
- the ordinal the exclusion gate consumed, so that dropping a note would not
  renumber its siblings
- the `state("rheo-handle")` read that keyed the ordinal per vertebra

Nothing replaces them. A pure function needs no accumulator, an excluded note
shifts nobody, and a note nested inside another is named by its own content
rather than by its parent's count.

## Tradeoffs taken knowingly

- **Editing a titleless note's body moves its URL.** The container ordinal had
  the opposite failure — inserting a sibling moved every later note. Neither is
  stable under editing; rung 1 is the answer to both.
- **`repr()` is not a documented stable format.** A Typst release that changes
  it re-slugs every rung-3 name. This is why rung 3 puts a readable,
  `_plain`-derived slug first and asks the hash only to separate ties: the
  readable half is computed by rookery's own walker and does not move.
- **A three-character hash reads as noise.** It buys the guarantee, and 16
  characters of prose in front of it is what keeps the name legible.
