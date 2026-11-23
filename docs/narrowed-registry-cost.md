# The cost of reading the fed registry at call time

**Verdict: the slowdown came from comemo constraint replay, not from walking
the registry. `_lig-built()` read one `idea-body:<id>` key per titleless note
(327 on waterline) to rebuild their records. Each read is a tracked token-file
access. Comemo replays every one of them on every memo hit of every function
whose call reached `_lig-built()`, and a narrowed compile makes thousands of
those hits. Titleless bodies now also go under one aggregate key,
`titleless-bodies`, so `_lig-built()` reads two keys rather than 328. Narrowed
rebuilds are now as fast as with the module-level `_LIG-RECS`, or slightly
faster, and the output does not change.**

## Setup

- rheo: `/tmp/main-target/release/rheo` (rheo main: per-key ligament store,
  spine store, hash change detection).
- Project: rsync copy of `waterline/rookery` (2,395 pages) with `[packages.rookery]`
  set to `path =` the rookery checkout under test.
- Sequence (`measure-v4.sh`): initial full build, then `rheo watch --trigger
  stdin`. The steps are: touch `nest/tidbits.typ`, touch `nest/admin.typ`, add a
  never-seen sentence to `nest/dissertation/chapters/c5/1.what-is-a-unit.typ`,
  touch admin again, then append `#todo(priority: 2)[probe]` to admin. After
  that the script compiles the same source in full and diffs it against the
  watch output with `diff -rq`.
- Runs were sequential on an otherwise idle 12-core machine.

## Numbers (`build_finished` ms, narrowed)

| variant | touch tidbits | touch admin | c5 prose edit | admin again | todo in admin | differ |
|---|---|---|---|---|---|---|
| `dev` head (`_lig-built()`), run 1 | 3,052 | 2,867 | 5,937 | 796 | 13,449 | 0 |
| `dev` head, run 2 | 3,053 | 2,888 | 5,981 | 788 | 13,531 | 0 |
| A: `_lig-built() = _LIG-BUILT` (module-level, old semantics) | 3,126 | 1,243 | 4,406 | 581 | 10,433 | 1 |
| B: `dev` head, titleless `raw` set to `none` (no per-note reads) | 3,141 | 1,859 | 4,872 | 1,214 | 9,809 | 6 |
| **fix, run 1** | 1,930 | 1,250 | 4,322 | 580 | 9,242 | 0 |
| **fix, run 2** | 1,893 | 1,240 | 4,320 | 597 | 9,257 | 0 |
| **fix, run 3** | 1,911 | 1,245 | 4,331 | 575 | 9,326 | 0 |

Variants A and B were run only to price the cost. Both are wrong: A is the
original correctness bug, which shows up as 1 differing page, and B drops
titleless bodies. A's numbers show the regression still exists on current rheo.
With the module-level value, touching admin took 1.2 s and the call-time
version took 2.9 s. B shows that the per-note body reads cause most of the
gap. The fix matches or beats A on every step. Touching tidbits got faster as
well (3.0 → 1.9 s): that step also suffered, but A never measured it.

The Zoom-room deletion check (delete `#idea(title: [Zoom room])` from
`nest/tidbits.typ` under watch, one narrowed rebuild, then a full compile of
the same source, diffed with `diff -rq` and no style stripping) reports **no
differing files** both before and after the fix. `review.html` carries its 3
`todo-fields` blocks. That deletion's narrowed round dropped from 15.2 s to
10.0 s.

Two full compiles, one at `dev` head and one with the fix, are byte-identical
(`diff -r`, 2,513 files).

## How it was found

`rheo watch --timings` writes one Chrome trace per rebuild. Its `func call`
spans carry the callee closure's file and line. The line is offset by +5 in
package files, so subtract 5 to reach the `#let`. Instrumentation inflates wall
time 2–5x, so the traces were read for relative weight only. Comparing the
"touch admin" trace at `dev` head with variant A:

- The `ideas()` row closure (`data.typ`, `.map(id => {..})`) ran the same 9,552
  times in both, but its self time was 1,306 ms against 279 ms. Self time
  excludes child closure spans, so the extra cost lies in work the trace does
  not name. Memo hits produce no span: a cache hit's lookup and constraint
  validation are billed to the caller.
- `_lig-built()`'s body ran only twice per rebuild in both variants, at about
  30 ms each. Hypothesis 2 (re-evaluation per closure identity) is false: the
  memoisation works.
- On the same rebuild, 654 `_lig-get` calls ran inside `_lig-built()`'s loop
  over its two executions, which is 327 titleless notes.

rheo's keyed store records a key dependency by reading a token file through
`engine.world.file(..)`
(`crates/core/src/keyed_store.rs`). A memoised call keeps every tracked access
made beneath it, including accesses made by nested calls. So every
`_reg-final()`, `_ref-text-live`, `ideas()` row and anything else that reached
`_lig-built()` carried 328 token constraints. Comemo re-checks all of them on
every cache hit. With the module-level `_LIG-RECS`, the reads happened once at
module evaluation, and the value was captured into `_reg-final` and hashed once
through the closure's lazy hash. Callers carried none of those constraints.

Hypothesis 1 (old closures now walk the full fed registry) does not explain the
cost on its own. Variant A walks the same merged registry and is fast.
Hypothesis 3 (the merge is redone per call) was already handled: `_reg-ordered()`
memoises the spine-ordered merge. One more change was tried and dropped. When
`handle:` is `none`, `_reg-final` skipped the `_drop-stale-page-ids` call, so
the merged dict was not hashed as an argument. No uninstrumented gain was
measurable (1,240 vs 1,250 ms on touch admin).

## The fix

`core/0.1.1/src/state.typ`:

- `_idea-ligaments` also attaches `(id: id, raw: raw)` under a new aggregate key
  `titleless-bodies` (`_LIG-TITLELESS-BODIES`) for every note whose `title` is
  `none`. Each note still attaches its own `idea-body:<id>` as before.
- `_lig-built()` builds an `id -> raw` map from that one key, keeping the first
  entry per id the way `idea-body:<id>`'s `.first()` did, and no longer reads
  `idea-body:<id>` per note.

Invalidation does not change. `_lig-built()` already depended on every
titleless body token, so any titleless body edit re-ran it. It now depends on
one key that changes in exactly those cases. No page binds `titleless-bodies`,
so rheo's choice of pages to recompile does not change. The feed grows by one
copy of each titleless body.

The general lesson for ligament readers: avoid reading per-note keys inside a
function that many memoised callers reach. Each key becomes a constraint that
all of those callers replay on every cache hit. An aggregate key costs one.

## Verification

- `just test` in `core/0.1.1` fails only on the known `demo/pure/ligaments.typ`
  aggregate-bind assertion (now line 198), as on `dev`. The recipe's later
  steps were run by hand and pass. `ligaments.typ` gains a check that titled
  notes attach nothing under `titleless-bodies`.
- `measure-v4.sh`: 0 pages differ from a full compile, in all 3 fix runs.
- Deletion check: narrowed and full builds are identical.
- Full build: byte-identical to `dev` head.
