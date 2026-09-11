---
id: rk-hoist-tag-data-out-of-the-all-sweep-767de9e4
short-id: '76'
title: Hoist tag-data() out of the all() sweep
priority: 4
labels:
- chore-bibtex-review
deps:
- blocked-by:rk-store-claimed-keys-as-a-dictionary-ec9241ef
closed: false
---
Compute the "existing tags" lookup once per `all()` sweep instead of once per
unclaimed bibliography entry.

Touches: /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ

## The problem, located exactly

`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ`, the `kw-tags-for`
closure at lines 108-118:

```typst
let kw-tags-for(key) = {
    if keywords == none { return (:) }
    let slugs = keyword-tags(entry(key).at("keywords", default: none))
    let kept = if keywords == "existing" {
      let known = tag-data().values().map(t => t.keys()).flatten().dedup()
      slugs.filter(s => s in known)
    } else {
      slugs
    }
    kept.fold((:), (d, t) => { d.insert(t, none); d })
  }
```

`tag-data()` (defined in `@rookery/core`,
`/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ` lines 397-403) resolves
`_registry.final()` — core's own doc comment on that function calls this out
directly: "BULK, and that is the point... walking N notes through [the
single-note accessors] pays N registry reads." `.final()` is a document-wide
fixed-point resolution, not a cheap read.

`kw-tags-for` is called from two places, both further down in the same file:

- `citation:` (lines 145-153) calls it once per hand-written `#citation(..)`
  call — each is a distinct, individually-authored call, so one `tag-data()`
  read per call is the right cost.
- `all:` (lines 163-182) calls it once PER KEY in the sweep, via `note(key,
  [])` at line 179, for every bibliography key not already claimed. On a
  large bibliography (the `waterline` project's is 1416 entries, four of
  them individually cited — see the retired bird
  `rk-add-only-to-bibtex-for-a-subset-e4dfea67`, `bd show` it for the
  numbers) with `keywords: "existing"` set, this is up to ~1412 separate
  `tag-data()` calls — ~1412 separate document-wide `.final()` resolutions —
  to answer a question ("what tags already exist") whose answer cannot
  change partway through one sweep.

This is the exact shape flagged against `core` in this same review pass: "A
`state` read repeated per element. `.final()` is a document-wide resolution;
a helper that reads one and is called four times for one answer pays four."
Here it is N times, not four, where N is the sweep size.

## Decisions already made — do not re-derive

**The known-tag set is safe to compute once per sweep.** The file's own
comment at lines 53-57 already establishes this: `"existing"` mode only ever
ADDS a tag that already exists somewhere else, so the known-tag set is "a
fixed point under its own writes" — reading it once before the sweep starts
gives the same answer as reading it fresh before every entry.

**Add an optional `known:` parameter, do not memoize globally.** A
module-level cache would leak across separate `bibtex(..)` factory calls (a
project can construct more than one); a parameter threaded through
`kw-tags-for` and `note` keeps the fix scoped to one sweep, closes over
nothing extra, and leaves `citation`'s per-call cost exactly as it is today
(it passes no `known:`, so `kw-tags-for` falls back to computing it itself —
correct, since a hand-written citation isn't part of a loop).

**Do not change what `all()` mints or its ordering.** This is a cost fix
only: same tags, same keys, same order, computed with fewer `tag-data()`
calls.

## Steps

All edits are in `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ`.

1. Lines 108-118, `kw-tags-for` — add a `known:` parameter defaulting to
   `none`, and use it when given instead of recomputing:

   ```typst
   let kw-tags-for(key, known: none) = {
     if keywords == none { return (:) }
     let slugs = keyword-tags(entry(key).at("keywords", default: none))
     let kept = if keywords == "existing" {
       let known = if known != none {
         known
       } else {
         tag-data().values().map(t => t.keys()).flatten().dedup()
       }
       slugs.filter(s => s in known)
     } else {
       slugs
     }
     kept.fold((:), (d, t) => { d.insert(t, none); d })
   }
   ```

2. Lines 128-134, the `note` closure — add the same `known:` parameter,
   named explicitly (not folded into `..args`, so it never reaches
   `tagged-idea(tag)(..)`), and forward it to `kw-tags-for`:

   ```typst
   let note = (key, title: auto, tags: none, show-tags: true, known: none, ..args) => (tagged-idea(tag))(
     key,
     title: if title == auto { bib-title(entry(key)) } else { title },
     tags: kw-tags-for(key, known: known) + _norm-tags(tags),
     show-tags: show-tags,
     ..args,
   )
   ```

3. Lines 163-182, the `all:` closure — compute `known` once, right after the
   sweep guard and before the loop, then pass it to every `note(..)` call:

   ```typst
   all: () => context {
     if _swept.get() > 0 {
       panic(
         "@rookery/bibtex: all() mints the whole bibliography and must be "
           + "called once, from one vertebra",
       )
     }
     _swept.update(n => n + 1)
     let known = if keywords == "existing" {
       tag-data().values().map(t => t.keys()).flatten().dedup()
     } else {
       none
     }
     for key in bib.keys().sorted() {
       if key not in _claimed.final() {
         note(key, [], known: known)
       }
     }
   },
   ```

   `all()`'s body already runs inside `context { .. }` (its own `()  =>
   context { .. }` at line 163), so calling `tag-data()` here needs no new
   context nesting — it is the same requirement `kw-tags-for` already
   satisfied by being called from inside that block.

4. `citation:` (lines 145-153) needs NO change — it never passes `known:`,
   so `kw-tags-for` takes its `if known != none {..} else {..}` fallback
   branch and computes it fresh per call, exactly as before this bird.

## Do NOT

- Do NOT change `citation:`'s signature or body.
- Do NOT touch `_claimed`, `_swept`, or anything in `claim.typ` — a sibling
  bird in this review changes `_claimed`'s representation; this bird only
  touches `kw-tags-for`, `note`, and `all:`.
- Do NOT change `keyword-tags`, `_slugify`, or anything in `keywords.typ`.
- Do NOT change the `keywords: none` or `keywords: "all"` code paths — only
  the `"existing"` branch inside `kw-tags-for` reads `known`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` must be green,
   output matching the baseline recorded before this review (the same
   baseline quoted in the sibling `_claimed`-dictionary bird's VERIFY
   section — `bd show` that bird for the exact lines). In particular the
   `existing:` and `all:` lines from `test/sweep-existing.typ` /
   `test/sweep-all.typ` must be byte-for-byte identical to:

   ```
   existing: aaa=citation+liminal | bbb=citation | ccc=citation | seed=liminal
   all:      aaa=brandnew+citation+liminal | bbb=brandnew+citation | ccc=citation+digital-humanities | seed=liminal
   ```

   These two fixtures are exactly the ones exercising `keywords: "existing"`
   through both `citation()` and `all()` — any regression in the `known:`
   threading shows up here first.

2. Confirm the fix preserves behaviour, using a fixture already run and
   confirmed against today's (pre-fix) code:

   ```bash
   mkdir -p /tmp/knowncheck && cd /tmp/knowncheck && cat > knowncheck.typ <<'EOF'
   #import "@rookery/core:0.1.0": rookery, idea, ideas
   #import "/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ": bibtex

   #let BIB = "@book{a,\n  title = {A},\n  keywords = {existing-tag},\n}\n\n@book{b,\n  title = {B},\n  keywords = {existing-tag},\n}\n"
   #let refs = bibtex(BIB, keywords: "existing")

   #show: rookery

   #idea("seed", tags: "existing-tag")[A hand-written note carrying the tag already.]
   #(refs.all)()

   #context {
     for i in ideas() {
       html.elem("div", attrs: (class: "kw-row"), {
         html.elem("span", attrs: (class: "kw-id"), i.id)
         html.elem("span", attrs: (class: "kw-tags"), i.tags.sorted().join(","))
       })
     }
   }
   EOF
   typst compile --features html --format html --root / knowncheck.typ knowncheck.html
   grep -o '<div class="kw-row">.*</div>' knowncheck.html
   ```

   Must print exactly (already confirmed against the unmodified package):

   ```
   <div class="kw-row"><span class="kw-id">idea:a</span><span class="kw-tags">citation,existing-tag</span></div><div class="kw-row"><span class="kw-id">idea:b</span><span class="kw-tags">citation,existing-tag</span></div><div class="kw-row"><span class="kw-id">idea:seed</span><span class="kw-tags">existing-tag</span></div>
   ```

   Both `a` and `b` must still pick up `existing-tag` through `all()`'s
   sweep after this change — the fix changes how many times `tag-data()`
   runs, not which tags land where.