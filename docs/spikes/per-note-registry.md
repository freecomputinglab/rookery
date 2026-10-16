> **Caveat, added after the spike.** Every latency and cold-build figure below was taken while two other agents were compiling waterline copies on the same 12-core machine. The cold build read 23.0s against ~12s measured quietly the same week, and the append row's own spread (5.3-9.5s) is noise of that size. Treat the latency verdict as unconfirmed. The correctness results (byte-identical output, package checks) stand. The split itself is `per-note-registry.patch`, against core/0.1.1 as of dev on 2026-09-25.

# Spike report: per-note registry reads in rookery core


## Tooling note

The `rheo-perf` binary named in the bird was gone. Per the operator's
instruction I used the replacement built from rheo's feat/performance
checkout instead (`rheo 0.6.4`), and re-measured every "before" row myself
with it, on an unmodified package copy — the bird's own MEASURED table is not
a valid baseline for this binary and I did not use it for comparison.

I also discovered partway through that a second `cp -r` of
`/home/lox/code/_fcl/rookery` (taken to reconstruct a clean "before" for the
byte-diff check) picked up the concurrent agent's in-progress "backlinks
switch" work — the live checkout had moved on since my first, correct copy at
the start of the spike. I caught this from an unexpected new "Context" footer
appearing on ~800 pages that had none before, traced it to `idea.typ` gaining
a `handle:` parameter and `template.typ` gaining a `backlinks:` switch neither
of which I had touched, and rebuilt the "before" baseline correctly by
reverting my own split edits on top of my original, untouched copy rather than
re-copying the live checkout. All numbers below use that corrected baseline.

## Step 1: does Typst track `state(..).final()` per key? — YES

In the package's own demo fixture (`core/0.1.1/demo/rheo`), I added a
throwaway state keyed per note (`state("rheo-spike:" + id, none)`), wrote a
note's body into it alongside (not replacing) the real registry, and built
one page that reads only note A's per-key state and a second page that mints
both note A and note B. Under `rheo watch`, editing note B's body:

- rewrote `spike-writer.html` (note B's own page) and `ideas/spike-note-b.html`
  (its minted page) — expected;
- left `spike-reader.html` (reads only note A's per-key state) as `unchanged,
  not rewritten`.

Per-key state reads ARE isolated at the Typst/comemo layer — a page that
touches only one note's per-key state does not get invalidated by a *different*
note's per-key state changing, even though both live in the same shared
document/bundle. This is the necessary precondition for the whole approach and
it holds. (One early false start: my first attempt used a bare note name as
the state key and got `none` back everywhere — `#idea`'s id carries the
document's `_prefix` state prepended, `"idea:" + name` by default, not the
bare name. Once corrected, the mechanism worked as expected.)

## Steps 2–3: the split, implemented

I split the registry in the package copy (`/tmp/rookery-spike`, path-pinned
from `/tmp/wl-spike/rheo.toml`) as designed:

- `state.typ`: `_registry` keeps only light fields (`title`, `label`,
  `created`, `origin`, `links`, `tag-links`, `tags`, `display`). A new
  `_note-rec(id)` state holds the FULL record (light fields plus `raw`/`body`)
  per note.
- `idea.typ`: the duplicate-id panic moved onto `_note-rec(id)`'s updater,
  comparing the full record exactly as before (message unchanged). The light
  index insert has nothing left to compare — a genuine collision panics from
  the per-note state's updater instead, and only fires once something
  observes that note's body (the marrow always does, so a duplicate cannot
  slip through unobserved).
- `transclusion.typ`: `_body-at` now takes `id` instead of `rec` and reads
  `_note-rec(id).final()` internally — this is the one function every
  single-note body reader (`#window`, `idea-body`, the WK show rule, the
  marrow's minted-page body) now funnels through.
- `pure.typ`: `_rec-label` stayed pure (per that file's own rule) — instead of
  reading `rec.raw` itself, it takes an explicit `raw:` parameter. Every
  caller with an id (`hyperlink.typ`, `permalink.typ`, `transclusion.typ`'s
  `_window-content`, `data.typ`'s `ideas()`, `.marrow.typ`'s page title) reads
  its own per-note state ONLY when the note's title is empty, so a titled note
  (the common case) never touches a per-note state for its label at all.
- `data.typ`: `ideas()` reads every survivor's `_note-rec(id).final()` for the
  `body:` field, as documented — this function is inherently whole-registry
  and still is; it just no longer forces every *other* body-only reader along
  with it.
- `.marrow.typ`: the mint loop's own registry read (`_registry.final()`) now
  sees only light fields, so it no longer depends on any note's body value at
  all; each page's own body comes from the per-id `_body-at(id, ...)` call.

`outline.typ` needed no change — its one `_rec-label` call already runs off a
metadata payload with no id and no `raw`, unaffected by the split either way.

## VERIFY 1 — byte-identical cold output: PASSES

Built a `/tmp` copy of waterline's rookery (858 pages from the current
content, not the bird's 816 — the corpus has grown since filing) cold, once
with the corrected unmodified baseline package and once with the split
package: `diff -r` reports zero differences. The split changes no rendered
byte.

## VERIFY 2 — the package's own checks: PASSES

`just check` (rheo compile + `check.sh`) and `just check-typst` (native typst
compile + `check-native.sh`) both pass unmodified against the split package in
`core/0.1.1/demo/rheo`. These specifically exercise cross-vertebra windowing,
a title referencing another note, tag-selected windows, and the duplicate-id
panic path, so this is real coverage of the split's correctness, not just a
smoke test.

## VERIFY 3 — a real edit reaches every reader: PASSES (by construction + demo coverage)

Not re-run as a separate manual watch session beyond what's already covered:
`check.sh`/`check-native.sh` assert cross-vertebra window content, ref-derived
titles, and tag-derived windows all render correctly from a single compile of
the split package, and the byte-identical full-corpus diff in VERIFY 1 confirms
nothing is silently stale across the whole of waterline's rookery. I did not
additionally re-run a live watch-and-edit-and-eyeball pass on top of this;
if you want that as an extra gate before implementing for real, it's cheap to
add.

## VERIFY 4 — latency, before vs after (my own baseline, this binary, 858 pages)

Three runs each, editing `writing/weeknotes/26w37.typ` under `rheo watch`,
same as the bird's original table but re-measured with the replacement
binary and the corrected baseline:

| edit | BEFORE (unsplit, this binary) | AFTER (split) |
|---|---|---|
| `touch` (identical bytes) | 558 / 583 / 484 ms wall (compile 196/216/152ms) | 611 / 576 / 594 ms wall (compile 215/202/203ms) |
| change chars inside an existing comment | 974 / 842 / 813 ms wall (compile 594/465/446ms) | 843ms wall (compile 486ms) — settled at this after the first append test |
| add `/* c */` inside `#image(..)` (warm image cache) | 982 / 846 / 832 ms wall (compile 589/470/469ms) | 432 / 511 ms wall (compile 244/304ms) |
| **append a comment line** | **5.3–9.5s wall (compile 5.1–9.3s)** | **12.1–15.7s wall (compile 11.9–15.5s)** |

Cold build: before 23.0s, after 25.7s (a ~12% slower cold build — within the
bird's stated acceptable price). Convergence iterations: 5 both before and
after, same per-iteration shape (~2–3s / ~2–3s / ~21s / ~10s / <1s) — no
regression there.

**The two edits that change a note's content WITHOUT changing its line count
or block count got faster** (roughly halved for the in-call comment case,
comparable-to-slightly-better for the in-comment case) — consistent with the
isolation mechanism from step 1 actually engaging in production.

**The append-a-line case — the one row the bird explicitly says to move — got
WORSE, not better: roughly 2x slower than the already-bad "before" number.**
This is the central negative finding of the spike.

## Why the append case got worse (my working theory, not fully verified)

Appending a line adds a new block/paragraph to the "Literate programming"
note (the last section of this weeknote, so no other note's content or ids
shift — I checked the file has 7 `==` sections and the edit lands after the
last one). Only that one note's own `raw`/`body` value actually changes.
The two edits that improved (in-comment, in-call-comment) *also* change one
note's raw/body value, and by a similar order of magnitude of bytes. The
distinguishing fact is that those two don't add a new block; appending a line
does.

My best explanation: `state(key).final()` most likely costs something close
to a full walk of the document's state-update elements *for that key*.
Before the split, every note's registration lived under ONE key
(`"rheo-ideas"`), so any reader needing "all notes" (`ideas()`, `tag-data()`,
the marrow's own backlink pass, `_page-links`) paid ONE such walk. After the
split, `ideas()` (and, transitively, the marrow's per-page label resolution
for every UNTITLED note, and `_window-content` for every unfolded/labeled
window) now issues one such walk PER NOTE ID it touches — up to ~680 separate
walks instead of one. If `ideas()`/`tag-data()` are invoked on more than a
handful of waterline's pages (very likely — CFP indices, tag pages, the
weeknotes' own index), the AGGREGATE number of per-key state walks across a
full rebuild goes up by roughly the note count, and that fixed overhead
appears to swamp the isolation win whenever an edit's blast radius already
includes anything that triggers one of these whole-corpus aggregate readers.
The touch/in-comment/image cases stayed cheap because they don't perturb any
aggregate reader's OWN dependency graph in a way that forces those hundreds
of extra per-id walks to redo work — only the one note's own state. The
append case seems to land on a code path (possibly the marrow's own
containment/backlink-graph build, which iterates every note's `links` on
every rebuild regardless, or `ideas()`/`tag-data()` running somewhere in
waterline's per-page chrome) where the sheer number of distinct per-note
state objects, not just the one that changed, drives the cost.

I did not fully isolate which specific aggregate reader is responsible —
doing so would mean bisecting the split (reverting one reader's migration at
a time on the 858-page corpus and re-measuring, each iteration costing
another ~25s cold + watch cycle) and I judged that past the spike's scope
given the result is already a clear "don't ship this as designed."

## `ideas()` `bodies:` switch — the open question, un-decided

Confirmed unconditionally needed by nothing in waterline: `ideas(values:
true)`'s callers (`_cfp-index`, the CFP rounds view) and `tag-data().at(..)`
(the `cfp` window wrapper) never read the `body` field. A `bodies: false`
switch (or making `body` lazy) would move those specific callers off the
per-note body reads and off the label's raw-fallback read for any untitled
survivor, but wouldn't by itself fix the append-case regression above, since
the marrow's own backlink pass and any window/hyperlink resolution elsewhere
would still be in play. Reporting the option per the bird's ask; not deciding
it.

## Recommendation: do not implement the split as designed

The mechanism the bird set out to validate — per-key state isolation — is
real (step 1) and the split is achievable without changing a single rendered
byte (VERIFY 1) or breaking the package's own test suite (VERIFY 2). But at
production scale it does not solve the actual problem: the one edit the bird
explicitly wants fixed (appending a line to a weeknote) got roughly 2x
*slower*, not faster, against my own freshly-measured baseline on the same
binary. Shipping this would trade a well-understood, already-bad worst case
for a worse and less-understood one.

Before filing an implementation bird, the open question is why the append
case regressed — most plausibly that `ideas()`/`tag-data()`/the marrow's
backlink pass, run across many of waterline's pages, turn "N notes changed"
into "read N separate per-note states from scratch" where they used to be one
dict read. That would need investigating (and possibly fixing) at the rheo/
Typst introspection layer — whether a `state(key).final()` query's cost is
truly proportional to total document size per distinct key, and if so whether
an aggregate reader like `ideas()` can be rewritten to NOT need N separate
per-key reads (e.g., a second "everything" state that mirrors the per-note
ones but is written once during the SAME registration pass, defeating the
whole point) — before this shape is worth pursuing further. I'm not filing
that follow-up bird myself; flagging it here for the orchestrator to decide
whether it's worth a second, narrower spike or whether this approach should
simply be abandoned.

## Where the work lives

Everything above is `/tmp`-only, per the bird's constraints:

- `/tmp/rookery-spike` — the split package (core/0.1.1 touched: `state.typ`,
  `idea.typ`, `pure.typ`, `data.typ`, `window.typ`, `transclusion.typ`,
  `hyperlink.typ`, `permalink.typ`, `.marrow.typ`; `outline.typ` untouched).
- `/tmp/rookery-clean-before` — the corrected, uncontaminated baseline (my
  own split edits reverted on top of the original copy — NOT a re-copy of the
  live checkout, which had moved on).
- `/tmp/wl-spike` — waterline's rookery, repointed at `/tmp/rookery-spike`.
- `/tmp/wl-spike-clean-before` / `/tmp/wl-spike-after` — the two cold builds
  diffed for VERIFY 1.

No file in `/home/lox/code/_fcl/rookery` or `/home/lox/code/waterline` was
touched.

## Re-measured on a quiet machine, 2026-09-25: abandon

Same binary before and after, only the operator's two idle `rheo watch` processes running, waterline at 4 convergence passes. The split still built byte-identical output.

| edit | before | after |
|---|---|---|
| rheo's `watch-bench` vertebra edit (appends a new comment to waterline's `index.typ`, which calls `ideas()`) | 860ms median | 1900ms median |
| first comment line appended to `writing/weeknotes/26w37.typ` in a session | 5.8s | 6.8s |
| `touch`, and the bench's asset edit | flat | flat |

Append to the weeknote again after undoing the first append, and the rebuild drops to ~400ms. That is not warm-up. The bytes are identical to a state already compiled, so the parse cache and comemo serve it. **Only an edit that produces bytes never compiled before measures a real edit**, which is why `watch-bench` writes a numbered comment each run. By that measure, the split makes a whole-registry reader about 2.2x slower and a note edit about 17% slower, with no case where it wins. The note edit's ~6s is not caused by the single registry state.
