# The rookery convergence bug

Working notes, 20 September 2026. Why `waterline` stopped building, what has
been fixed, what is still broken, and — as much as it matters — which
diagnoses turned out to be wrong.

**Status:** seven fixes landed (six in `@rookery/core`, folded into its `0.1.0`
commit which `dev` inherits; one in `@rookery/meetings`). The site still does
not build. Two causes remain, both now understood.

## The symptom

`just build` in `/home/lox/code/waterline` fails. Typst gives a document five
layout attempts to reach a fixed point; this one does not. With all seven
fixes in, the site reports:

```
47 x  value of `counter("rheo-idea-fn-<N>")` did not converge
 1 x  value of `state("rookery-idea-scope")` did not converge
 4 x  did not stabilize   (document path, elem path, link anchor, footnote container)
      failed to determine link anchor
```

The fatal error is **downstream**, not a cause. Three warnings fire on the same
span as the error (`rheo_spine.typ:68`, rheo's own link rule): the document
path is unstable, the element path is unstable, and the link anchor "did not
stabilize" (`(no anchor)` on all five runs, `loc-1` on the final one). rheo
cannot resolve an anchor for a link whose page never settles. Fix the
convergence and the error goes with it.

This is not new. The bird filed before any of this work already recorded the
same non-convergence on this site. What changed is which wall the build hits
first: it used to abort earlier, at `duplicate note id idea:4`, during registry
finalisation — before rheo's link rule ever ran.

## The one bug underneath all of it

Every instance is the same mistake:

> A value is derived from **where or when** something is rendered instead of
> from **what it is**.

`@rookery/core` transcludes: `#window` re-renders a note's body wherever it is
placed. Typst collapses every copy of a replayed context read to one shared
value, and a counter stepped during a replay is stepped twice. So any value
taken from the renderer's position answers for whichever copy won, not for the
note. Each pass can differ, so the document never looks the same twice.

## What auto-generated names have to do with it

The bug concentrates here, because **every automatic name is positional**, and
position is exactly what replay destroys. A note that pins its own name
(`#idea(<some-name>, ..)`) is never affected.

### Two id shapes

Worth stating precisely, because confusing them cost a full misdiagnosis:

- **Container ordinal** — a note with neither name nor title takes
  `<container>-<n>`. At a page's top level the container is the vertebra
  handle (`grad-3`); nested inside another note it is the **parent note's own
  id** (`meeting-with-on-4-9-26-1`). `n` counts titleless notes within that
  container.
- **Title slug** — a titled note takes `_id-slug(_plain(title))`, and a second
  note deriving the same slug is numbered `<slug>-2`.

Both can produce a trailing `-2`. They are different machinery with different
failure modes.

### 1. Titleless notes — the container ordinal

`key` comes from `state("rheo-handle")`, `n` from a stack in
`core/0.1.0/src/state.typ`. The stack's top-level accumulator was appended once
and never popped, so it became a single document-global slot: its key froze to
whatever the handle was at the first titleless mint anywhere in the spine —
often `""`, because the handle is not a string that early — and every later
note on every later page counted against it. Two notes then landed on the same
ordinal, which is where `duplicate note id idea:4` came from: a bare number,
no page prefix, because the key was empty.

It was also ruinously slow to settle. Before the fix:

```
run 2: ((key: "", n: 1),)
run 3: ((key: "", n: 2),)
run 4: ((key: "", n: 3),)
run 5: ((key: "", n: 4),)
```

One note settling per attempt, against a budget of five, on a site with 103
titleless notes.

### 2. Untitled meetings — a title made of references

`@rookery/meetings` gives an untitled meeting a derived title:
`[Meeting with #_refs(who)]`, or `[Meeting with #_refs(who) on #stamp]` when it
has a date. `_refs` builds Typst `ref` elements.

The id is slugged from the title's **pure** plain-text projection
(`core/0.1.0/src/idea.typ`, `_id-slug(_plain(title))`), and `_plain` renders
every `ref` as the empty string by design — it runs before the registry that
could resolve one. So the reader sees "Meeting with Holly Case, William Joseph
Stewart" while the id sees `Meeting with `, slugged to `meeting-with`.

Every dateless untitled meeting in a project therefore took the *same* id. A
dated one escapes only by accident: the literal date survives the projection,
giving `meeting-with-on-10-9-26` — which carries no participant, so two
untitled meetings on one day still collide.

### 3. Duplicate slugs — the numbering counter

Two notes whose titles derive the same slug now get `<slug>` and `<slug>-2`
rather than a panic, counted in document order. The counter was stepped on
every render, so a transcluded note recorded its slug twice and could mint
`<slug>-2` for itself. Fixed by making the record idempotent per note (below),
and verified in the demo — though, see "Wrong turns", this was **not** what
was wrong on this site.

## Fixes landed

All in `@rookery/core` unless noted, folded into the `0.1.0` commit.

| what | change |
|---|---|
| scope accumulator | per-vertebra (`top: true`), keyed by the current page's handle, starting a fresh count when the handle changes instead of continuing a frozen one |
| scope updater | made a pure function of its own argument. Measured: an updater closing over a separately-read value costs one extra attempt *per note sharing the key*; a pure one costs none |
| `_note-href` | gained a `handle:` parameter so callers holding a known handle stop re-reading state; redundant reads removed from `idea.typ`'s card and `data.typ`'s row builder |
| `_permalink` | renders through rheo's own per-`#document` link rule (native `link()`) instead of resolving a destination with a context read. `link()` emits a bare `<a>`, so `class`/`data-rookery`/`title` moved to a wrapping span, with CSS to match |
| `_page-href` | gained `here:`; `.marrow.typ`'s Context and Backlinks callers now pass the handle of the page they are minting |
| duplicate slugs | numbered (`<slug>`, `<slug>-2`) instead of panicking; `_slug-count` maps a slug to an array of occupants, an occupant being the note's own `(title, body, tags, level, display)`, so re-rendering one note returns its existing position |
| footnote numbering | each `_footnoted` call mints a counter named for that one rendering (`"rheo-idea-fn-" + str(b)`) instead of sharing one document-wide counter |
| untitled meetings (`@rookery/meetings`) | a dateless meeting is named after its participants — `idea:meeting-with-case-holly-stewart-william-joseph` — intrinsic to the note and stable wherever rendered |

### Effect, measured on this site

- Titleless-note cost is no longer linear: `n` reached **103 in a single pass**,
  where it had advanced by one per pass.
- Both `state("rheo-handle")` non-convergence warnings are **gone**.
- The vertebra-level scope **settles at run 3**, byte-identical at run 4: 21
  entries, `n` summing to 103.
- `duplicate note id` no longer aborts the build.

## What is left

### 1. The container ordinal is not idempotent under replay

The site's scope trace ends:

```
run 5: (key: "meeting-with-on-4-9-26", n: 2), (key: "writing-remarks-joan-symposium-1", n: 0)
final: (key: "meeting-with-on-4-9-26", n: 2), (key: "meeting-with-on-4-9-26-2",         n: 0)
```

`clusters/digitaltheory/pragma/meetings.typ:376-419` is the sole meeting dated
4 September, and it contains **exactly one** nested `#idea[` (line 398). Yet
its container shows `n: 2` — two nested notes minted under a parent that has
one. The second is the same note minted again on a replay, taking ordinal 2
instead of 1, so it resolves to the id `meeting-with-on-4-9-26-2`.

This is the container-ordinal path (`_scope-peek`/`_scope-record`), not the
slug path. The fix needed is the same shape already applied to `_slug-count`:
recording an occurrence must be idempotent, so that a note rendered twice takes
the ordinal it already has rather than the next one.

### 2. Footnote numbering: correct numbers, 47 non-converging counters

Replacing one shared counter with one counter per rendering produces correct
numbering — its demo assertion (three footnotes, two identical, numbering 1, 2,
3 on both a note's own page and inside a `#window`) genuinely passes — but on a
real site:

```
warning: value of `counter("rheo-idea-fn-65")` did not converge
  bib.typ:202   context _fn-ref(b, seq.get().first())
  run 1: 0   run 2: 0   run 3: 0   run 4: 0   run 5: 0   final: 1
```

A counter whose NAME is minted fresh carries nothing from the previous pass, so
it reads `0` through every attempt and its true value only at final resolution.
One non-converging counter became 47.

The direction still untried: number footnotes **at construction**, not at
render. `_footnotes(body)` already walks the body; if that walk returned a body
with each number baked into the element, no counter and no show-rule read would
be needed. Both previous attempts derived the number from when the renderer
reached it.

## Wrong turns, recorded so they are not repeated

- **The `-2` was diagnosed as the slug counter double-counting.** It is a
  container ordinal. A bird was written and landed for the slug counter; a
  control build with and without it produced byte-identical logs on this site.
  The fix is defensible on its own terms — it does fix a real replay bug in the
  demo — but it was not this symptom. The tell that should have caught it
  sooner: `state("rookery-idea-slug-count")` never appears in a single
  non-convergence warning, so the slug numbering was stable all along.
- **"A second note must be authored somewhere."** Ruled out exhaustively:
  every `#meeting`'s `on:` is a literal `datetime(..)`, only one is 4 Sept, and
  no hand-written title or label anywhere derives that slug.
- **"Refs and context closures don't compare equal across evaluations."**
  Falsified by direct test: `ref(<bob>) == ref(<bob>)`, content built from a
  ref, a fresh `context{}`, and even `@rookery/timeline`'s `timeline-view`
  output (which contains a raw `context()` node) all compare equal.
- **"Fixing the handle reads will settle the scope."** Half right. The 21
  vertebra-level entries settle at run 3; the note-level entries do not, for
  the reason in "What is left" (1).
- **Small reproductions converge.** A solo `#meeting`, a `#meeting`
  transcluded cross-vertebra, the same content value placed twice, two
  argument-identical calls, and a verbatim copy of the entire real
  `pragma/meetings.typ` all converge cleanly with one occupant. The defect
  needs the full spine's scale to appear, which makes bisection expensive and
  is worth knowing before someone spends an hour trying to shrink it.

## What Typst will not let you do

Refuted while fixing the footnote counter; both look reasonable on paper.

- **A plain mutable binding in a show rule.** `let n = 0` outside, `n += 1`
  inside `show FNK: it => ..`. Typst rejects it at compile time: `variables
  from outside the function are read-only and cannot be modified`. A show rule
  cannot count its own matches without state.
- **Matching an element against a precomputed list by content equality.**
  `notes.position(n => n == it)` returns the FIRST index for two equal
  elements, so a note with two identical footnotes numbers them `1, 2, 2`.
  Confirmed by a negative test reproducing exactly that.

## The rule worth keeping

A generated name may only be derived from what the note *is* — its own title,
its participants, its pinned name — never from where it sits, when it was
reached, or how many things preceded it. Anything positional will be replayed,
and a replayed value is whichever copy won that pass.

Where a positional value is unavoidable — a container ordinal genuinely is —
recording it must be **idempotent**, so that rendering the same thing twice is
indistinguishable from rendering it once. That is the single test to apply to
any remaining fix here.
