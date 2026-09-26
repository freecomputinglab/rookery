# Declared partitions

A rookery mixes material of different sensitivities in one compiled document.
Nothing today stops an idea in one part of a site referencing an idea in
another: `@idea:<name>` resolves against the whole document, wherever it was
written. A reference is not neutral — it leaks that the target exists, and it
renders the target's title into the page holding the reference. A private or
embargoed note is exposed the moment anything public links to it, and nothing
in the package would tell either author that had happened.

This document designs a **partition**: a set of ideas declared, at the top of
a vertebra, to be unable to reference ideas outside it. Getting this declared
rather than discovered matters on its own — `docs/spikes/watch-rebuild-latency.md`
in the rheo checkout records an attempt to find a compile boundary in
waterline's existing `@idea:` graph, and it failed: the graph has no small
cut. Narrowing the spine to one tree broke on a dangling label, and excluding
the two pages responsible produced eight further breaks elsewhere. A boundary
nobody declared is not there to find. A boundary an author declares and the
package enforces holds by construction, whatever the graph already looks
like — which is also, incidentally, the one thing that would make a
multi-bundle compile safe. That connection is real and is covered at the end
of this document, but it is not the reason to build this: security is.

## The declaration

A partition needs a name, a rule for which ideas are in it, and a default for
an idea that names none.

**Naming.** A partition is a string, the same shape as a tag name — no new
identifier syntax, no registry of partitions to maintain elsewhere. `"public"`,
`"private"`, `"team-only"` are all valid partition names, chosen by the
project the way tag names already are.

**Membership: per vertebra, not central.** `rookery.with(..)` is where
`prefix`, `idea-dir`, and every other project-wide default already live, and a
partition is exactly that shape — one project-wide choice a vertebra either
inherits or overrides. A central registry (a table somewhere mapping ids to
partitions) would need to be kept in sync with the content by hand, which is
exactly the kind of drift a declared boundary is meant to prevent. So:

```
#show: rookery.with(partition: "private")
```

sets every idea a vertebra using this template mints into `"private"`. This
mirrors `prefix:` and `css-prefix:` precisely — a document-wide default, read
the same way `_prefix` is today, with no per-`#idea` override proposed here.
A per-note override (`#idea(partition: "x", ..)`) is a plausible future
refinement once a project asks for mixed partitions inside one vertebra, but
nothing in the motivating case needs it: the operator's own example is public
versus embargoed pages, which are naturally whole vertebrae, not interleaved
notes within one file.

**Single membership.** An idea belongs to exactly one partition, never several.
Set membership is what makes "may not reference outside it" decidable at
all — an idea that is simultaneously in `"public"` and `"private"` makes every
enforcement question below ambiguous (does a `"public"` idea's reference to it
count as inside or outside?). If a project wants an idea visible from two
zones, that is better modeled as two ideas — public summary, private detail,
linked one way — than as one idea claiming membership in both.

**The default for a page that declares nothing is the whole security
posture, and it should be closed, not open.** Two options:

- *Unpartitioned ideas share one implicit "no partition" bucket, and
  references across the partition boundary are the only ones restricted* —
  meaning anything that never opts in works exactly as it does today, and
  restriction is opt-in per partition.
- *An idea with no declared partition is itself in a partition of one — its
  own vertebra's handle — until an author explicitly says otherwise* (e.g. a
  reserved default like `partition: none` meaning "isolated, not shared with
  any other undeclared vertebra").

The first is the right default. The security case here is specifically
**public content must not be able to leak private content**, not "every idea
everywhere must be walled off from every other by default." Waterline's
rookery, and most rookeries that will adopt this, are overwhelmingly one big
shared partition with a small number of genuinely sensitive corners cut out
of it — exactly the shape blog and weeknotes vertebrae have today, freely
cross-referencing each other, with something like `writing/private/` or
`writing/team/` the exception. Making the default closed would force every
existing vertebra in every existing project to declare a partition just to
keep working, for a threat model (accidental leak from ordinary content into
other ordinary content) nobody has described. Making the default open and
letting the sensitive corner opt into isolation is the change that matches
the motivating case, breaks no existing project, and puts the burden of
declaring where it belongs — on the material that actually needs walling off.

So: `rookery.with(partition: none)` (the default) means "this vertebra's
ideas are unpartitioned, and may reference and be referenced by anything else
unpartitioned or in any partition that does not forbid it." Only an idea in a
*named* partition is restricted, and it is restricted symmetrically: it may
not reference outside its partition, unpartitioned material included.

## Enforcement

Four cases, each checked against the registry, since every idea's partition
is a field on its registry entry the same way its tags are.

**1. `@idea:x` in partition A naming an idea in partition B.** This is the
core case and the cheapest to check: `#hyperlink` (`hyperlink.typ`) already
resolves every `@idea:x` and `#hyperlink("x")[..]` call against the registry
before it renders anything, specifically so a typo'd name fails at the call
site rather than becoming a dangling link. The partition check rides on that
same resolution: once the target's registry entry is known, compare its
`partition` field against the referencing idea's own (available the same way
`state("rheo-handle")` locates the referencing page today). A mismatch — B
named, referencer's partition is A or none where A/B differ and neither is
`none`'s free-mixing case above — is a compile error naming both partitions
and both ids, the same register `_assert-tags` and the `display` key checks
already use elsewhere in the package. This is enforceable with certainty
because `#hyperlink` already refuses to resolve a name it cannot find; it is
one more condition on the same refusal path, not a new one.

**2. A `#window(tagged: ..)` in A whose tag selector matches notes in B.**
This is the case a naming rule alone misses, because the author of the
window never wrote B's ids — the selector matches them incidentally. Anchor 4
(`_registry.final()` in `outline.typ`) is also where `#window`'s own tag
resolution happens (`window.typ`), against the same final registry a
partition check would use. The fix is the same shape: a
`#window(tagged: ..)` call, at the point it resolves its predicate against
`reg`, filters candidates by the calling vertebra's partition first —
matches outside the caller's partition are dropped rather than raised as an
error, because a broad tag selector legitimately ranging over the whole
rookery is normal, and the point of a partition is that B's material must
never render on an A page, not that every author must enumerate partitions
in every selector. The alternative — erroring whenever a `tagged:` selector's
matches span a boundary — would break every existing wide selector the
moment one partition is declared, for no security benefit: the notes it drops
were never going to be shown anyway.

**3. The marrow's own derived pages, which query the whole document by
construction.** `.marrow.typ` mints one page per registered note
(`_note-page`) and builds the page-backlinks map by reading `_page-links()`
(anchor 3, `outline.typ`), which itself folds together every vertebra's
`<rookery-window-mark>` and `<rookery-page-links>` beacons — a document-wide
sweep by design, because that is the only way to answer "which pages mention
this note" at all.

The ideas index should stay **one index, made partition-aware**, not split
into N indices. Splitting the index per partition would need N separate
compiles to produce N physically separate outputs — which is exactly the
"advisory versus structural" distinction below, and a single-document compile
cannot deliver it regardless of how the index is organized. Short of that,
one partition-aware index is strictly better than one unaware index: each
minted page for a note in partition A lists only backlinks whose source is
also in A (or unpartitioned, symmetric with the rule above), and a minted
page for an unpartitioned note lists only unpartitioned or same-partition
backlinks reaching it — never a backlink from a note in a different named
partition, since that link could only exist if case 1 had already refused
it. In other words: if enforcement in cases 1 and 2 is airtight, the backlink
data the marrow reads is already clean, because no cross-partition edge was
ever allowed to enter `_registry`'s `tag-links`/named-link data in the first
place. The marrow needs no separate enforcement pass of its own — it is a
consumer of an already-partitioned graph, not a place partitioning has to be
re-derived.

**4. A backlink from B to A — the inverse of a reference A never made.**
This is where the recently-added `backlinks:` switch on `rookery.with(..)`
(`rookery.with(backlinks: false)`, distinct from `display-backlinks:`, which
only hides the rendered section without stopping harvesting) is directly
relevant, and worth stating precisely: `backlinks: false` stops the whole
graph being harvested for a vertebra, which is a blunter tool than a
partition needs. A note in partition A should still show backlinks *from
other A notes* — it is only a backlink arriving from B that must not exist.
Since case 1 refuses B->A links at the point B tries to make them, no such
edge is ever recorded in `_backlinks` (state.typ) or in `_page-links`'
data — so case 4 needs no enforcement code of its own, in exactly the way
case 3 doesn't: it falls out of case 1 holding. The one thing worth being
explicit about is that this is enforcement-by-absence, not
enforcement-by-filtering — a partition violation is caught once, at the
point the forbidden reference is written, and every downstream backlink,
index, and window-derived list is clean as a consequence rather than each
needing its own check. That is also why case 1's check has to be
correct and total: any leak there becomes an unenforced backlink everywhere
downstream, silently.

## What a structural boundary would take, and what it would be worth

Everything above is enforcement **inside one compiled document**. That is
advisory: Typst compiles a rookery as a single document with one
introspector, so partitioning here can *detect and refuse* a forbidden
reference, but the forbidden material is still physically present in the
same document being compiled, reachable by anything that queries broadly
enough (a raw `query()` outside the package's own accessors, a future
package that isn't partition-aware, an author's `#context` block). Declaring
a partition is a promise the package enforces at every path it controls, not
a guarantee that private content never entered the compiler's working set.

Making the boundary **structural** — a partition's introspector genuinely
never containing the other partition's content — means compiling each
partition as a **separate bundle**. That is a rheo change, not a
`@rookery/core` one: today rheo compiles one project as one document with one
spine, and a multi-bundle compile means an author's project splits into
several documents that share a `core` template but never share a Typst
compilation. `docs/spikes/watch-rebuild-latency.md` is the record of the
narrower version of this same idea already being measured — under the
sibling spike `wl-spike-a-leaf-vertebra-fast-path-21d77821` — with concrete
numbers: 92-95ms per rebuild against 13 pages, versus 626-658ms against the
full 812-page rookery. If a declared partition is also what a multi-bundle
compile keys its split on, the security feature becomes the input the
performance feature needs to be safe at all — the earlier attempt to find a
cut failed because nothing declared one, not because bundling itself doesn't
help.

This document does not design that compiler change. It states only that
`partition:` is the one primitive both features would share: security can
ship as advisory-only enforcement inside one document now, and if the
operator later wants the structural version, the same declaration a security
feature already requires is what a multi-bundle compile would partition on —
no second scheme to invent.

## Decisions requested from the operator

1. **Naming and membership.** Confirm: a partition is a string; membership is
   declared per vertebra via `rookery.with(partition: "name")`; an idea is in
   exactly one partition. Any of these worth revisiting before this becomes a
   bird?

2. **The default.** This document argues for `partition: none` (unpartitioned,
   freely cross-referencing) as the default, with only explicitly-named
   partitions restricted, over a closed-by-default scheme where every
   undeclared vertebra is isolated until it opts out. Confirm the open
   default, or say why the stricter one is worth the migration cost to every
   existing rookery.

3. **Enforcement scope.** Confirm the four cases above are the complete list
   worth enforcing at this stage — named references, tag-selector windows,
   the marrow's derived index and backlinks (both argued to need no
   independent check, only a correct case 1) — or name a fifth case this
   document missed.

4. **Advisory now, structural later — or wait?** This document treats
   in-document enforcement as worth shipping on its own, with the
   multi-bundle compile as a distinct, later, rheo-level decision. Confirm
   that split, or say if the operator only wants this built once the
   structural version is ready, in which case this bird's `partition:`
   primitive should be designed jointly with that rheo change rather than
   ahead of it.

No implementation bird has been filed. It should not be, until the above is
settled — in particular decision 2, since it is the one choice that would be
expensive to reverse once vertebrae start relying on it.
